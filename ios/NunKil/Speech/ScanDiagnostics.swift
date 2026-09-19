import Foundation
import Observation

/// Why this exists: when nothing is announced, "no frames are arriving" and
/// "frames arrive but hold no readable barcode" look identical from the outside.
/// These counters separate the two, on screen and in a file that can be pulled
/// off the device.
@Observable
@MainActor
final class ScanDiagnostics {
  private(set) var frames = 0
  private(set) var scans = 0
  private(set) var stills = 0
  private(set) var found = 0
  private(set) var lastEvent = ""

  @ObservationIgnored private var handle: FileHandle?
  @ObservationIgnored private let fileURL: URL

  init(fileName: String = "scan.log") {
    fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(fileName)
  }

  var summary: String {
    "프레임 \(frames) · 검사 \(scans) · 사진 \(stills) · 발견 \(found)"
  }

  func startSession(_ note: String) {
    frames = 0
    scans = 0
    stills = 0
    found = 0
    try? FileManager.default.removeItem(at: fileURL)
    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    handle = try? FileHandle(forWritingTo: fileURL)
    write("session start: \(note)")
  }

  func endSession(_ note: String) {
    write("session end: \(note) — \(summary)")
    try? handle?.close()
    handle = nil
  }

  func countFrame() { frames += 1 }
  func countStill() { stills += 1 }

  func countScan(found payload: String?) {
    scans += 1
    if let payload {
      self.found += 1
      record("barcode \(payload)")
    } else if scans % 10 == 0 {
      write("\(summary)")
    }
  }

  func record(_ event: String) {
    lastEvent = event
    write(event)
  }

  private func write(_ line: String) {
    let stamp = Date().formatted(date: .omitted, time: .standard)
    guard let data = "\(stamp)  \(line)\n".data(using: .utf8) else { return }
    try? handle?.write(contentsOf: data)
  }
}
