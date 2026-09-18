import GlassesKit
import SwiftUI

/// Large targets, plain labels, everything reachable with VoiceOver. The screen is
/// a fallback: the app is meant to be used without looking at it.
struct RootView: View {
  let connection: GlassesConnection
  @Bindable var shopping: ShoppingViewModel

  #if DEBUG
  @State private var showMockPanel = false
  #endif

  var body: some View {
    NavigationStack {
      Group {
        if connection.isRegistered {
          ShoppingView(viewModel: shopping)
        } else {
          ConnectView(connection: connection)
        }
      }
      #if DEBUG
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showMockPanel = true } label: { Image(systemName: "ladybug") }
            .accessibilityLabel("디버그 메뉴")
        }
      }
      .sheet(isPresented: $showMockPanel) { MockGlassesPanel() }
      #endif
    }
  }
}

private struct ConnectView: View {
  let connection: GlassesConnection

  var body: some View {
    VStack(spacing: 24) {
      Text("안경을 연결해야 시작할 수 있어요.")
        .font(.title3)
        .multilineTextAlignment(.center)
      Button(connection.isRegistering ? "연결 중" : "안경 연결") {
        connection.connect()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(connection.isRegistering)
      .accessibilityHint("Meta AI 앱으로 이동해 승인한 뒤 돌아옵니다.")
    }
    .padding()
    .navigationTitle("NunKil")
  }
}

private struct ShoppingView: View {
  @Bindable var viewModel: ShoppingViewModel

  private var status: String {
    switch viewModel.phase {
    case .idle: return viewModel.camera.hasActiveDevice ? "준비됨" : "안경을 켜고 착용해 주세요"
    case .connecting: return "안경 카메라를 켜는 중"
    case .looking: return "찾는 중"
    case .spoke(let sentence): return sentence
    case .failed(let message): return message
    }
  }

  private var isBusy: Bool {
    switch viewModel.phase {
    case .idle, .spoke, .failed: return false
    case .connecting, .looking: return true
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      Text(status)
        .font(.title3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 88)
        .accessibilityAddTraits(.updatesFrequently)

      Button { Task { await viewModel.identifyProduct() } } label: {
        Label("이게 뭐야", systemImage: "barcode.viewfinder")
          .font(.title2)
          .frame(maxWidth: .infinity, minHeight: 72)
      }
      .buttonStyle(.borderedProminent)
      .disabled(isBusy || !viewModel.camera.hasActiveDevice)

      Button { Task { await viewModel.comparePrice() } } label: {
        Label("가격 비교", systemImage: "tag")
          .font(.title2)
          .frame(maxWidth: .infinity, minHeight: 72)
      }
      .buttonStyle(.bordered)
      .disabled(isBusy || !viewModel.camera.hasActiveDevice)

      if !isBusy, case .idle = viewModel.phase {} else {
        Button("처음으로") { viewModel.reset() }
      }

      Picker("지역", selection: $viewModel.region) {
        Text("일본").tag(Region.jp)
        Text("한국").tag(Region.kr)
      }
      .pickerStyle(.segmented)
      .accessibilityHint("어느 나라 가격으로 비교할지 고릅니다.")

      Spacer()
      Text("동작 버튼이나 Siri로도 부를 수 있어요: \"NunKil 이게 뭐야\"")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .navigationTitle("NunKil")
  }
}
