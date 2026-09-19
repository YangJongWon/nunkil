import GlassesKit
import MWDATCore
import SwiftUI

@main
struct NunKilApp: App {
  @State private var connection: GlassesConnection
  @State private var shopping: ShoppingViewModel

  init() {
    do {
      try Wearables.configure()
    } catch {
      NSLog("[NunKil] Wearables.configure failed: \(error)")
    }
    let wearables = Wearables.shared
    let shopping = ShoppingViewModel(
      camera: GlassesCamera(wearables: wearables),
      lookup: .fromBundle(),
      announcer: Announcer(speaker: GlassesSpeaker()))
    _connection = State(wrappedValue: GlassesConnection(wearables: wearables))
    _shopping = State(wrappedValue: shopping)
    ShoppingAutomation.toggleScanning = { await shopping.toggleScanning() }
  }

  var body: some Scene {
    WindowGroup {
      RootView(connection: connection, shopping: shopping)
        // Meta AI returns here after registration and permission prompts.
        .onOpenURL { url in
          Task { _ = try? await Wearables.shared.handleUrl(url) }
        }
    }
  }
}
