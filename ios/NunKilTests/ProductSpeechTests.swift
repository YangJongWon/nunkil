import GlassesKit
import XCTest

@testable import NunKil

/// The backend fixture below is a real response (JAN 4901330560782), so the app
/// and src/nunkil/schemas.py stay in step.
final class ProductSpeechTests: XCTestCase {
  private let realResponse = """
    {"query":"4901330560782","region":"jp",
     "identity":{"name":"500円 送料無料　カルビー 堅あげポテト　うすしお 小袋 4袋","price":500,"currency":"JPY","source":"yahoo","jan":"4901330560782","brand":null,"seller":"kamejiro","url":"https://example.jp/1"},
     "cheapest":{"name":"500円 送料無料　カルビー 堅あげポテト　うすしお 小袋 4袋","price":500,"currency":"JPY","source":"yahoo","jan":"4901330560782","brand":null,"seller":"kamejiro","url":"https://example.jp/1"},
     "spoken_name":"カルビー 堅あげポテト うすしお 小袋 4袋",
     "matches":[{"name":"お菓子 詰め合わせ 17種","price":1650,"currency":"JPY","source":"yahoo","jan":null,"brand":null,"seller":"kaimo","url":null}]}
    """

  private func lookup() throws -> ProductLookup {
    try LookupClient.decoder.decode(ProductLookup.self, from: Data(realResponse.utf8))
  }

  func testDecodesTheBackendContract() throws {
    let result = try lookup()
    XCTAssertEqual(result.region, .jp)
    XCTAssertEqual(result.spokenName, "カルビー 堅あげポテト うすしお 小袋 4袋")
    XCTAssertEqual(result.cheapest?.price, 500)
    XCTAssertEqual(result.identity?.seller, "kamejiro")
  }

  func testDescribeIsOneShortSentence() throws {
    let sentence = ProductSpeech.describe(try lookup())
    XCTAssertEqual(sentence, "カルビー 堅あげポテト うすしお 小袋 4袋. 온라인 최저 500엔.")
  }

  func testCompareAlwaysMentionsShippingWhenOnlineIsCheaper() throws {
    let sentence = ProductSpeech.compare(try lookup(), shelfPrice: 700)
    XCTAssertTrue(sentence.contains("여기 700엔"))
    XCTAssertTrue(sentence.contains("온라인 500엔"))
    XCTAssertTrue(sentence.contains("200엔 싸요"))
    // Without shipping, a worse deal can sound like a better one.
    XCTAssertTrue(sentence.contains("배송비"))
  }

  func testCompareSaysWhenTheShopIsCheaper() throws {
    let sentence = ProductSpeech.compare(try lookup(), shelfPrice: 400)
    XCTAssertTrue(sentence.contains("여기가 더 싸요"))
    XCTAssertFalse(sentence.contains("배송비"))
  }

  func testUnknownProductDoesNotInventAName() {
    let empty = ProductLookup(query: "0000", region: .jp, identity: nil, cheapest: nil, spokenName: nil, matches: [])
    XCTAssertEqual(ProductSpeech.describe(empty), ProductSpeech.notFound)
  }

  /// A Korean voice cannot pronounce 堅あげポテト, so the sentence must be split.
  func testMixedScriptSentenceIsSplitPerLanguage() throws {
    let segments = SpeechSegmenter.segments(ProductSpeech.describe(try lookup()))
    XCTAssertEqual(segments.first?.language, SpeechSegmenter.japanese)
    XCTAssertTrue(segments.contains { $0.language == SpeechSegmenter.korean && $0.text.contains("온라인") })
    XCTAssertTrue(segments.first?.text.contains("カルビー") == true)
  }
}
