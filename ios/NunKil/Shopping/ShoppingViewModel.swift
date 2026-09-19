import GlassesKit
import Observation
import UIKit
import os

private let log = Logger(subsystem: "com.yangjongwon.nunkil", category: "Shopping")

@Observable
@MainActor
final class ShoppingViewModel {
  enum Phase: Equatable {
    case idle
    case starting
    /// Camera on, looking for a barcode. The wearer holds items up; nothing on
    /// the phone needs touching.
    case scanning
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  /// The last thing said, for the screen only.
  private(set) var lastAnswer: String = ""
  var region: Region = .jp {
    didSet { UserDefaults.standard.set(region.rawValue, forKey: Self.regionKey) }
  }

  var isScanning: Bool { phase == .scanning || phase == .starting }

  let camera: GlassesCamera
  let diagnostics = ScanDiagnostics()
  @ObservationIgnored private let lookup: LookupClient
  @ObservationIgnored private let announcer: Announcer
  @ObservationIgnored private let now: () -> Date

  @ObservationIgnored private var stillCaptureLoop: Task<Void, Never>?
  @ObservationIgnored private var guidanceLoop: Task<Void, Never>?
  @ObservationIgnored private var answering = false
  /// Barcodes already announced this session, and when.
  @ObservationIgnored private var announced: [String: Date] = [:]
  @ObservationIgnored private var lastFoundAt: Date?
  @ObservationIgnored private var startedAt: Date?

  private static let regionKey = "shopping.region"
  /// Holding the same item a moment longer must not repeat the answer.
  static let repeatWindow: TimeInterval = 30
  /// Nothing found for this long: tell the wearer how to help the camera.
  static let guidanceAfter: TimeInterval = 5
  /// The camera does not stay on forever; the glasses' battery is small.
  static let sessionLimit: TimeInterval = 3 * 60

  init(
    camera: GlassesCamera,
    lookup: LookupClient,
    announcer: Announcer,
    now: @escaping () -> Date = Date.init
  ) {
    self.camera = camera
    self.lookup = lookup
    self.announcer = announcer
    self.now = now
    if let saved = UserDefaults.standard.string(forKey: Self.regionKey),
      let restored = Region(rawValue: saved)
    {
      region = restored
    }
  }

  // MARK: - One button, no screen

  /// The Action Button and the on-screen button both land here: start looking, or
  /// stop. There is no "reset" step — after an answer the app keeps scanning.
  func toggleScanning() async {
    if isScanning {
      stopScanning(reason: ProductSpeech.scanStopped)
    } else {
      await startScanning()
    }
  }

  func startScanning() async {
    guard !isScanning else { return }
    phase = .starting
    announced.removeAll()
    lastFoundAt = nil
    startedAt = now()
    diagnostics.startSession("preset=inspect region=\(region.rawValue)")
    do {
      try await camera.start(.inspect)
      diagnostics.record("stream started: \(String(describing: camera.streamState))")
    } catch {
      diagnostics.record("start failed: \(error.localizedDescription)")
      diagnostics.endSession("start failed")
      phase = .failed(error.localizedDescription)
      announcer.say(error.localizedDescription, priority: .answer)
      camera.stop()
      return
    }
    phase = .scanning
    announcer.say(ProductSpeech.scanStarted, priority: .answer)

    log.notice("scan started: preset=inspect region=\(self.region.rawValue, privacy: .public)")
    let scanning = OSAllocatedUnfairLock(initialState: false)
    camera.setFrameHandler { [weak self] image in
      Task { @MainActor in self?.diagnostics.countFrame() }
      guard let cgImage = image.cgImage,
        scanning.withLock({ busy in
          defer { busy = true }
          return !busy
        })
      else { return }
      Task.detached(priority: .userInitiated) {
        let found = BarcodeReader.read(cgImage)
        scanning.withLock { $0 = false }
        await self?.diagnostics.countScan(found: found?.payload)
        if let found { await self?.handle(found) }
      }
    }
    startStillCaptureLoop()
    startGuidanceLoop()
  }

  func stopScanning(reason: String?) {
    stillCaptureLoop?.cancel()
    stillCaptureLoop = nil
    guidanceLoop?.cancel()
    guidanceLoop = nil
    camera.setFrameHandler(nil)
    camera.stop()
    diagnostics.endSession(reason ?? "stopped")
    phase = .idle
    if let reason { announcer.say(reason, priority: .answer) }
  }

  // MARK: - Steps

  /// Stream frames are the fast path; a full-resolution still catches the small,
  /// far-away barcodes that the stream misses.
  private func startStillCaptureLoop() {
    stillCaptureLoop = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        guard let self, self.phase == .scanning, !self.answering else { continue }
        guard let data = try? await self.camera.capturePhoto(timeout: .seconds(6)),
          let image = UIImage(data: data)?.cgImage
        else {
          self.diagnostics.record("still capture failed")
          continue
        }
        self.diagnostics.countStill()
        let found = await Task.detached(priority: .userInitiated) { BarcodeReader.read(image) }.value
        self.diagnostics.record("still \(image.width)x\(image.height) found=\(found?.payload ?? "-")")
        if let found { await self.handle(found) }
      }
    }
  }

  private func startGuidanceLoop() {
    guidanceLoop = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard let self, self.phase == .scanning else { continue }
        if let started = self.startedAt, self.now().timeIntervalSince(started) > Self.sessionLimit {
          self.stopScanning(reason: ProductSpeech.scanTimedOut)
          return
        }
        // The camera can stop underneath us (folded glasses, battery, heat).
        if self.camera.streamState == .stopped {
          let reason = self.camera.lastIssue ?? ProductSpeech.cameraStopped
          self.stopScanning(reason: nil)
          self.phase = .failed(reason)
          self.announcer.say(reason, priority: .answer)
          return
        }
        let quietFor = self.now().timeIntervalSince(self.lastFoundAt ?? self.startedAt ?? self.now())
        if quietFor > Self.guidanceAfter, !self.answering {
          // Announcer's repeat window keeps this from nagging every second.
          self.announcer.say(ProductSpeech.holdCloser, priority: .info)
        }
      }
    }
  }

  private func handle(_ barcode: BarcodeReader.Barcode) async {
    guard phase == .scanning, !answering else { return }
    if let seen = announced[barcode.payload], now().timeIntervalSince(seen) < Self.repeatWindow {
      lastFoundAt = now()
      return  // still holding the same thing
    }
    answering = true
    announced[barcode.payload] = now()
    lastFoundAt = now()
    defer { answering = false }

    do {
      let started = now()
      let result = try await lookup.lookup(jan: barcode.payload, region: region)
      let sentence = ProductSpeech.describe(result)
      log.notice("lookup \(barcode.payload, privacy: .public) took \(self.now().timeIntervalSince(started), format: .fixed(precision: 2))s")
      lastAnswer = sentence
      announcer.say(sentence, priority: .answer)
    } catch {
      let message = error.localizedDescription
      lastAnswer = message
      announcer.say(message, priority: .answer)
      // A failed lookup shouldn't blacklist the item: let the next look retry it.
      announced[barcode.payload] = nil
    }
  }
}
