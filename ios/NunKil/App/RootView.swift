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
    case .idle:
      if !viewModel.lastAnswer.isEmpty { return viewModel.lastAnswer }
      return viewModel.camera.hasActiveDevice ? "준비됨" : "안경을 켜고 착용해 주세요"
    case .starting: return "안경 카메라를 켜는 중"
    case .scanning: return viewModel.lastAnswer.isEmpty ? "상품을 들어 보여 주세요" : viewModel.lastAnswer
    case .failed(let message): return message
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      Text(status)
        .font(.title3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 88)
        .accessibilityAddTraits(.updatesFrequently)

      // One control. Starting and stopping is the whole interaction: while it runs,
      // products are announced as they come into view without touching the phone.
      Button { Task { await viewModel.toggleScanning() } } label: {
        Label(
          viewModel.isScanning ? "상품 확인 중지" : "상품 확인 시작",
          systemImage: viewModel.isScanning ? "stop.circle" : "barcode.viewfinder"
        )
        .font(.title2)
        .frame(maxWidth: .infinity, minHeight: 96)
      }
      .buttonStyle(.borderedProminent)
      .tint(viewModel.isScanning ? .red : .accentColor)
      .disabled(!viewModel.isScanning && !viewModel.camera.hasActiveDevice)
      .accessibilityHint("시작하면 상품을 하나씩 들어 보여 주세요. 바코드가 보이면 이름과 최저가를 말합니다.")

      if viewModel.isScanning {
        // Tells apart "no frames arriving" from "frames arrive, no barcode in them".
        VStack(spacing: 2) {
          Text(viewModel.diagnostics.summary).monospacedDigit()
          if !viewModel.diagnostics.lastEvent.isEmpty {
            Text(viewModel.diagnostics.lastEvent).lineLimit(1)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Picker("지역", selection: $viewModel.region) {
        Text("일본").tag(Region.jp)
        Text("한국").tag(Region.kr)
      }
      .pickerStyle(.segmented)
      .accessibilityHint("어느 나라 가격으로 비교할지 고릅니다.")

      Spacer()
      Text("동작 버튼이나 Siri로 시작·중지할 수 있어요: \"NunKil 이게 뭐야\"")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .navigationTitle("NunKil")
  }
}
