import GlassesKit
import XCTest

@testable import NunKil

@MainActor
final class AnnouncerTests: XCTestCase {
  private var clock = Date(timeIntervalSince1970: 0)

  private func makeAnnouncer() -> Announcer {
    Announcer(speaker: GlassesSpeaker(), now: { self.clock })
  }

  func testRepeatsAreSuppressedWithinTheWindow() {
    let announcer = makeAnnouncer()
    XCTAssertTrue(announcer.say("포카칩 오리지널"))
    XCTAssertFalse(announcer.say("포카칩 오리지널"), "same sentence twice in a row is noise")

    clock += Announcer.repeatWindow + 1
    XCTAssertTrue(announcer.say("포카칩 오리지널"))
  }

  func testHazardInterruptsAnAnswerAndIgnoresTheRepeatWindow() {
    let announcer = makeAnnouncer()
    XCTAssertTrue(announcer.say("카루비 우스시오. 온라인 최저 500엔.", priority: .answer))
    XCTAssertTrue(announcer.say("앞에 차", priority: .hazard))
    // Repeating a warning is correct: the danger is still there.
    XCTAssertTrue(announcer.say("앞에 차", priority: .hazard))
  }

  func testLowerPriorityIsDroppedWhileSomethingImportantIsSpeaking() {
    let announcer = makeAnnouncer()
    XCTAssertTrue(announcer.say("앞에 차", priority: .hazard))
    XCTAssertFalse(announcer.say("근처에 편의점이 있어요", priority: .info))

    announcer.finished()
    XCTAssertTrue(announcer.say("근처에 편의점이 있어요", priority: .info))
  }

  /// Regression: nothing cleared the active priority, so after the first sentence
  /// every lower-priority message was dropped and the app fell silent for good.
  func testSpeakerGoingIdleUnblocksLowerPriorityMessages() {
    let speaker = GlassesSpeaker()
    let announcer = Announcer(speaker: speaker, now: { self.clock })

    XCTAssertTrue(announcer.say("상품을 하나씩 들어 보여 주세요.", priority: .answer))
    XCTAssertFalse(announcer.say(ProductSpeech.holdCloser, priority: .info))

    speaker.onIdle?()  // speech finished

    clock += 1
    XCTAssertTrue(announcer.say(ProductSpeech.holdCloser, priority: .info))
  }

  func testEmptyTextSaysNothing() {
    let announcer = makeAnnouncer()
    XCTAssertFalse(announcer.say("   "))
    XCTAssertEqual(announcer.lastSpoken, "")
  }
}
