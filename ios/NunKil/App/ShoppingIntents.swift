import AppIntents

/// Bridge from the Action Button / Siri into the running app. Set at launch.
@MainActor
enum ShoppingAutomation {
  static var identify: (@MainActor () async -> Void)?
  static var comparePrice: (@MainActor () async -> Void)?
}

struct IdentifyProductIntent: AppIntent {
  static let title: LocalizedStringResource = "이게 뭐야"
  static let description = IntentDescription("안경 카메라로 상품을 보고 무엇인지 말해줍니다.")
  // Starting a glasses session needs the app in the foreground.
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let identify = ShoppingAutomation.identify else { throw IntentError.appNotReady }
    // Return immediately: the answer is spoken, not shown, and Siri should not wait.
    Task { await identify() }
    return .result()
  }
}

struct ComparePriceIntent: AppIntent {
  static let title: LocalizedStringResource = "가격 비교"
  static let description = IntentDescription("가격표와 온라인 최저가를 비교해 말해줍니다.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let compare = ShoppingAutomation.comparePrice else { throw IntentError.appNotReady }
    Task { await compare() }
    return .result()
  }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
  case appNotReady

  var localizedStringResource: LocalizedStringResource {
    "NunKil을 한 번 연 뒤 다시 시도해 주세요."
  }
}

struct NunKilShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: IdentifyProductIntent(),
      phrases: ["\(.applicationName) 이게 뭐야", "\(.applicationName)로 상품 확인"],
      shortTitle: "이게 뭐야",
      systemImageName: "barcode.viewfinder")
    AppShortcut(
      intent: ComparePriceIntent(),
      phrases: ["\(.applicationName) 가격 비교", "\(.applicationName)로 가격 확인"],
      shortTitle: "가격 비교",
      systemImageName: "tag")
  }
}
