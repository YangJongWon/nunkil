import GlassesKit
import XCTest

@testable import NunKil

/// The rules that decide when the app speaks while scanning. Getting these wrong
/// is what makes the app unusable: it either nags or stays silent.
@MainActor
final class ScanSessionTests: XCTestCase {
  private var clock = Date(timeIntervalSince1970: 0)

  private func announcer() -> Announcer {
    Announcer(speaker: GlassesSpeaker(), now: { self.clock })
  }

  func testTheSameItemIsNotAnnouncedTwiceWhileHeld() {
    let announcer = announcer()
    XCTAssertTrue(announcer.say("포카칩 오리지널. 온라인 최저 1180원.", priority: .answer))
    clock += 2
    XCTAssertFalse(announcer.say("포카칩 오리지널. 온라인 최저 1180원.", priority: .answer))
  }

  func testADifferentItemIsAnnouncedRightAway() {
    let announcer = announcer()
    XCTAssertTrue(announcer.say("포카칩 오리지널. 온라인 최저 1180원.", priority: .answer))
    clock += 1
    XCTAssertTrue(announcer.say("사이다 500ml. 온라인 최저 900원.", priority: .answer))
  }

  func testGuidanceDoesNotNagEverySecond() {
    let announcer = announcer()
    XCTAssertTrue(announcer.say(ProductSpeech.holdCloser, priority: .info))
    announcer.finished()
    clock += 1
    XCTAssertFalse(announcer.say(ProductSpeech.holdCloser, priority: .info))

    clock += Announcer.repeatWindow
    announcer.finished()
    XCTAssertTrue(announcer.say(ProductSpeech.holdCloser, priority: .info))
  }

  func testAnswerOutranksGuidance() {
    let announcer = announcer()
    XCTAssertTrue(announcer.say("포카칩 오리지널.", priority: .answer))
    // Guidance must not talk over the answer the wearer asked for.
    XCTAssertFalse(announcer.say(ProductSpeech.holdCloser, priority: .info))
  }

  func testSessionLimitsAreShortEnoughToProtectTheBattery() {
    // The glasses run hot and flat quickly with the camera on; these are the
    // numbers the wearer lives with, so changing them should be deliberate.
    XCTAssertEqual(ShoppingViewModel.sessionLimit, 180)
    XCTAssertEqual(ShoppingViewModel.guidanceAfter, 5)
    XCTAssertEqual(ShoppingViewModel.repeatWindow, 30)
  }
}
