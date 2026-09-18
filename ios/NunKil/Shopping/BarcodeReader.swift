import CoreGraphics
import Vision

/// Reads product barcodes on the phone. When this succeeds the photo never leaves
/// the device: only the digits are sent to the lookup backend.
enum BarcodeReader {
  /// Symbologies used on retail packaging. JAN (Japan) and KAN (Korea) are both
  /// EAN-13; UPC-A arrives as EAN-13 with a leading zero.
  static let retailSymbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce]

  struct Barcode: Equatable {
    let payload: String
    let symbology: VNBarcodeSymbology
  }

  /// Returns the most prominent retail barcode in the image, if any.
  static func read(_ image: CGImage) -> Barcode? {
    let request = VNDetectBarcodesRequest()
    request.symbologies = retailSymbologies
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
      return nil
    }

    let candidates: [Barcode] = (request.results ?? []).compactMap { observation in
      guard let payload = observation.payloadStringValue, isPlausible(payload) else { return nil }
      return Barcode(payload: payload, symbology: observation.symbology)
    }
    // Several barcodes can be in frame (the shelf label next to the product);
    // the biggest one is the thing being held up to the camera.
    return candidates.max { a, b in area(of: a, in: request) < area(of: b, in: request) }
  }

  /// Retail barcodes are 8, 12 or 13 digits and carry a check digit. Validating it
  /// here keeps a misread from becoming a confident wrong answer.
  static func isPlausible(_ payload: String) -> Bool {
    guard payload.allSatisfy(\.isNumber), [8, 12, 13].contains(payload.count) else { return false }
    let digits = payload.compactMap { $0.wholeNumberValue }
    guard digits.count == payload.count, let check = digits.last else { return false }
    let body = digits.dropLast().reversed()
    let sum = body.enumerated().reduce(0) { total, pair in
      total + pair.element * (pair.offset.isMultiple(of: 2) ? 3 : 1)
    }
    return (10 - sum % 10) % 10 == check
  }

  private static func area(of barcode: Barcode, in request: VNDetectBarcodesRequest) -> CGFloat {
    let match = (request.results ?? []).first { $0.payloadStringValue == barcode.payload }
    guard let box = match?.boundingBox else { return 0 }
    return box.width * box.height
  }
}
