import Foundation
import GlassesKit
import Observation

/// Everything the app says goes through here, so that a warning always wins over
/// an answer, and the app never repeats itself into the wearer's ear.
@Observable
@MainActor
final class Announcer {
  enum Priority: Int, Comparable {
    /// Something is approaching. Cuts off whatever is being said.
    case hazard = 2
    /// The answer to something the wearer asked for.
    case answer = 1
    /// Context nobody asked for; dropped while anything else is speaking.
    case info = 0

    static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }
  }

  /// The last thing said, for the screen and for tests.
  private(set) var lastSpoken: String = ""

  /// Repeating the same sentence within this window is noise, not information.
  static let repeatWindow: TimeInterval = 8

  private let speaker: GlassesSpeaker
  private let now: () -> Date
  private var speakingUntilPriority: Priority?
  private var recent: [String: Date] = [:]

  init(speaker: GlassesSpeaker, now: @escaping () -> Date = Date.init) {
    self.speaker = speaker
    self.now = now
    // Without this the first sentence blocks every lower-priority message for the
    // rest of the session — the app goes silent and looks broken.
    speaker.onIdle = { [weak self] in
      MainActor.assumeIsolated { self?.speakingUntilPriority = nil }
    }
  }

  /// Returns whether the message was actually spoken.
  @discardableResult
  func say(_ text: String, priority: Priority = .answer) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    if let last = recent[trimmed], now().timeIntervalSince(last) < Self.repeatWindow,
      priority != .hazard
    {
      return false  // already said it a moment ago
    }
    if let active = speakingUntilPriority, priority < active {
      return false  // something more important is talking
    }

    recent = recent.filter { now().timeIntervalSince($0.value) < Self.repeatWindow }
    recent[trimmed] = now()
    speakingUntilPriority = priority
    lastSpoken = trimmed
    // Mixed Korean/Japanese sentences need one voice per script.
    speaker.say(SpeechSegmenter.segments(trimmed))
    return true
  }

  /// Call when a spoken message has finished or been abandoned, so a lower
  /// priority message can be heard again.
  func finished() {
    speakingUntilPriority = nil
  }

  func stop() {
    speaker.stop()
    speakingUntilPriority = nil
  }
}
