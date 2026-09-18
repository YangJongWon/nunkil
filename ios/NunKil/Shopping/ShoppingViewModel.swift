import GlassesKit
import Observation
import UIKit

@Observable
@MainActor
final class ShoppingViewModel {
  enum Phase: Equatable {
    case idle
    case connecting
    case looking
    case spoke(String)
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  /// Where the wearer is shopping; decides which price data is used.
  var region: Region = .jp {
    didSet { UserDefaults.standard.set(region.rawValue, forKey: Self.regionKey) }
  }

  let camera: GlassesCamera
  @ObservationIgnored private let lookup: LookupClient
  @ObservationIgnored private let announcer: Announcer
  private static let regionKey = "shopping.region"

  init(camera: GlassesCamera, lookup: LookupClient, announcer: Announcer) {
    self.camera = camera
    self.lookup = lookup
    self.announcer = announcer
    if let saved = UserDefaults.standard.string(forKey: Self.regionKey),
      let restored = Region(rawValue: saved)
    {
      region = restored
    }
  }

  /// "이게 뭐야": read the barcode on the phone, ask the backend for the name and
  /// the online price, and say one sentence.
  func identifyProduct() async {
    guard case .idle = phase else { return }
    phase = .connecting
    do {
      try await camera.start(.snapshot)
      let photo = try await camera.capturePhoto()
      camera.stop()
      guard let image = UIImage(data: photo)?.cgImage else {
        return finish(.failed("사진을 읽지 못했어요."), speak: "사진을 읽지 못했어요.")
      }

      phase = .looking
      guard let barcode = BarcodeReader.read(image) else {
        // No barcode: OCR and the vision model come next (Phase 2 of the plan).
        return finish(.failed(ProductSpeech.noBarcode), speak: ProductSpeech.noBarcode)
      }

      let result = try await lookup.lookup(jan: barcode.payload, region: region)
      let sentence = ProductSpeech.describe(result)
      finish(.spoke(sentence), speak: sentence)
    } catch {
      camera.stop()
      let message = error.localizedDescription
      finish(.failed(message), speak: message)
    }
  }

  /// "가격 비교": same photo answers both questions — what it is, and what the
  /// shelf is charging for it.
  func comparePrice() async {
    guard case .idle = phase else { return }
    phase = .connecting
    do {
      try await camera.start(.snapshot)
      let photo = try await camera.capturePhoto()
      camera.stop()
      guard let image = UIImage(data: photo)?.cgImage else {
        return finish(.failed("사진을 읽지 못했어요."), speak: "사진을 읽지 못했어요.")
      }

      phase = .looking
      guard let barcode = BarcodeReader.read(image) else {
        return finish(.failed(ProductSpeech.noBarcode), speak: ProductSpeech.noBarcode)
      }
      let result = try await lookup.lookup(jan: barcode.payload, region: region)
      let sentence =
        ShelfPriceReader.read(image).map { ProductSpeech.compare(result, shelfPrice: $0) }
        ?? ProductSpeech.describe(result)
      finish(.spoke(sentence), speak: sentence)
    } catch {
      camera.stop()
      let message = error.localizedDescription
      finish(.failed(message), speak: message)
    }
  }

  func reset() {
    camera.stop()
    announcer.finished()
    phase = .idle
  }

  private func finish(_ phase: Phase, speak sentence: String) {
    self.phase = phase
    announcer.say(sentence, priority: .answer)
  }
}
