import AppIntents

/// Bridge from the Action Button / Siri into the running app. Set at launch.
@MainActor
enum ShoppingAutomation {
  static var toggleScanning: (@MainActor () async -> Void)?
}

/// One physical button starts and stops looking. Pressing it is the only thing the
/// wearer has to do — no screen, and no "start over" step between products.
struct IdentifyProductIntent: AppIntent {
  static let title: LocalizedStringResource = "상품 확인"
  static let description = IntentDescription("안경 카메라로 상품을 계속 확인해 무엇인지 말해줍니다. 다시 누르면 멈춥니다.")
  // Starting a glasses session needs the app in the foreground.
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let toggle = ShoppingAutomation.toggleScanning else { throw IntentError.appNotReady }
    // Return immediately: the answer is spoken, not shown, and Siri should not wait.
    Task { await toggle() }
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
      phrases: [
        "\(.applicationName) 이게 뭐야",
        "\(.applicationName) 상품 확인",
        "\(.applicationName)로 상품 확인해 줘",
      ],
      shortTitle: "상품 확인",
      systemImageName: "barcode.viewfinder")
  }
}
