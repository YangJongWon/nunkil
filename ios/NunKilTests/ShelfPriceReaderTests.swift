import XCTest

@testable import NunKil

/// Price parsing is tested on the text a shelf label produces, without rendering
/// images: OCR accuracy is a separate question from picking the right number.
final class ShelfPriceReaderTests: XCTestCase {
  func testPrefersCurrencyMarkedNumbers() {
    // A Japanese shelf tag: product code, weight, then the price.
    let lines = ["カルビー 堅あげポテト", "60g", "本体 158円", "税込 170円"]
    XCTAssertEqual(ShelfPriceReader.price(in: lines), 170)
  }

  func testReadsYenSignAndThousands() {
    XCTAssertEqual(ShelfPriceReader.price(in: ["¥1,980"]), 1980)
    XCTAssertEqual(ShelfPriceReader.price(in: ["￥ 158"]), 158)
  }

  func testReadsKoreanWon() {
    XCTAssertEqual(ShelfPriceReader.price(in: ["포카칩 오리지널", "1,180원"]), 1180)
  }

  func testFallsBackToABareNumberOnlyWhenNothingIsMarked() {
    XCTAssertEqual(ShelfPriceReader.price(in: ["198"]), 198)
    // With a marked price present, a bare number (weight, code) must not win.
    XCTAssertEqual(ShelfPriceReader.price(in: ["4901330560782", "158円"]), 158)
  }

  func testNoDigitsMeansNoPrice() {
    XCTAssertNil(ShelfPriceReader.price(in: ["本日のおすすめ"]))
    XCTAssertNil(ShelfPriceReader.price(in: []))
  }
}
