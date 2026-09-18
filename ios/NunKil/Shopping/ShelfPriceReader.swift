import CoreGraphics
import Vision

/// Reads the price off a shelf label. Only the number matters, so this runs on the
/// phone and never sends the photo anywhere.
enum ShelfPriceReader {
  /// Japanese and Korean shelf labels: "¥158", "158円", "1,980원", "158 円(税込)".
  /// A bare number is accepted too, but ranked last — it is often a weight or a
  /// product code rather than the price.
  static func read(_ image: CGImage) -> Int? {
    let request = VNRecognizeTextRequest()
    request.recognitionLanguages = ["ja-JP", "ko-KR", "en-US"]
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false  // digits, not words
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
      return nil
    }

    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return price(in: lines)
  }

  static func price(in lines: [String]) -> Int? {
    var marked: [Int] = []
    var bare: [Int] = []
    for line in lines {
      for match in line.matches(of: /[¥￥]\s*([\d,]{2,7})|([\d,]{2,7})\s*(円|원|엔)/) {
        if let value = number(match.output.1 ?? match.output.2) { marked.append(value) }
      }
      if marked.isEmpty {
        for match in line.matches(of: /\b([\d,]{2,7})\b/) {
          if let value = number(match.output.1) { bare.append(value) }
        }
      }
    }
    // Shelf labels show the main price largest and often repeat it with tax;
    // the highest currency-marked number is the one being asked for.
    return marked.max() ?? bare.max()
  }

  private static func number(_ text: Substring?) -> Int? {
    guard let text else { return nil }
    let digits = text.replacingOccurrences(of: ",", with: "")
    guard let value = Int(digits), value > 0, value < 10_000_000 else { return nil }
    return value
  }
}
