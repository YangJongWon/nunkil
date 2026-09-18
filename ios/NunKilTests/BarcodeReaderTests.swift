import CoreImage
import UIKit
import Vision
import XCTest

@testable import NunKil

final class BarcodeReaderTests: XCTestCase {
  /// Renders a real scannable barcode so the test exercises Vision, not a stub.
  private func barcodeImage(_ payload: String, generator: String = "CICode128BarcodeGenerator") throws -> CGImage {
    let filter = try XCTUnwrap(CIFilter(name: generator))
    filter.setValue(Data(payload.utf8), forKey: "inputMessage")
    let output = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 6, y: 6))
    // White margins: a barcode bleeding to the edge often fails to decode.
    let onWhite = output.composited(over: CIImage(color: .white).cropped(to: output.extent.insetBy(dx: -60, dy: -60)))
    return try XCTUnwrap(CIContext().createCGImage(onWhite, from: onWhite.extent))
  }

  func testChecksumRejectsMisreadsAndAcceptsRealCodes() {
    // Real Japanese products.
    XCTAssertTrue(BarcodeReader.isPlausible("4901330560782"))
    XCTAssertTrue(BarcodeReader.isPlausible("4901777300446"))
    // Same digits with one transposition: a wrong answer spoken confidently is
    // worse than "못 찾았어요".
    XCTAssertFalse(BarcodeReader.isPlausible("4901330560872"))
    XCTAssertFalse(BarcodeReader.isPlausible("1234567890123"))
    XCTAssertFalse(BarcodeReader.isPlausible("49013305607821"))
    XCTAssertFalse(BarcodeReader.isPlausible("49013X0560782"))
  }

  /// Vision's barcode decoding needs hardware the Simulator doesn't provide
  /// ("Could not create inference context"), so these two run on a device.
  private func skipOnSimulator() throws {
    #if targetEnvironment(simulator)
      throw XCTSkip("Vision 바코드 디코딩은 시뮬레이터에서 동작하지 않습니다. 실기기에서 실행하세요.")
    #endif
  }

  func testReadsAScannableBarcode() throws {
    try skipOnSimulator()
    // Code128 carries the same digits and is what CoreImage can generate; the
    // reader accepts any retail symbology Vision reports.
    let image = try barcodeImage("4901330560782")
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.code128]
    try VNImageRequestHandler(cgImage: image).perform([request])
    let payload = try XCTUnwrap(request.results?.first?.payloadStringValue)

    XCTAssertEqual(payload, "4901330560782")
    XCTAssertTrue(BarcodeReader.isPlausible(payload), "generated payload must pass the check digit")
  }

  func testNoBarcodeInAPlainPhoto() throws {
    // Without this the test passes for the wrong reason: on the Simulator the
    // request throws and the reader returns nil regardless of the image.
    try skipOnSimulator()
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let blank = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format).image { context in
      UIColor.systemGray.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
    }
    XCTAssertNil(BarcodeReader.read(try XCTUnwrap(blank.cgImage)))
  }
}
