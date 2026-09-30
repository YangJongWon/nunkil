#if DEBUG

import GlassesKit
import MWDATMockDevice
import PhotosUI
import SwiftUI
import UIKit

/// Simulated Ray-Ban Meta for developing without the real glasses. Pick a photo of
/// a barcode and it becomes what `capturePhoto()` returns.
struct MockGlassesPanel: View {
  @Environment(\.dismiss) private var dismiss
  @State private var glasses: MockGlasses?
  @State private var isEnabled = MockDeviceKit.shared.isEnabled
  @State private var photoItem: PhotosPickerItem?
  @State private var status = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("목 안경 사용", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, enabled in
              if enabled {
                MockDeviceKit.shared.enable()
              } else {
                MockDeviceKit.shared.disable()
                glasses = nil
              }
            }
        }

        if isEnabled {
          Section("기기") {
            Button(glasses == nil ? "레이밴 메타 페어링 + 착용" : "페어링됨") { pairAndWear() }
              .disabled(glasses != nil)
          }
          Section {
            PhotosPicker("촬영될 사진 고르기 (바코드)", selection: $photoItem, matching: .images)
              .disabled(glasses == nil)
          } footer: {
            Text("'이게 뭐야'를 누르면 이 사진이 안경 사진과 미리보기 영상으로 전달됩니다.")
          }
          if !status.isEmpty {
            Section { Text(status).font(.footnote) }
          }
        }
      }
      .navigationTitle("디버그: 목 안경")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
      .onChange(of: photoItem) { _, item in
        guard let item else { return }
        Task { await useAsCapturedImage(item) }
      }
    }
  }

  private func pairAndWear() {
    do {
      let device = try MockDeviceKit.shared.pairGlasses(model: .rayBanMeta)
      device.powerOn()
      device.unfold()
      // A session only starts on glasses that are being worn.
      device.don()
      glasses = device
      status = "가상 안경이 켜지고 착용된 상태입니다. 미리보기 영상을 준비 중…"
      Task {
        do {
          let feed = try await Task.detached(priority: .userInitiated) { try MockFeedVideo.make() }.value
          device.services.camera.setCameraFeed(fileURL: feed)
          status = "가상 안경이 켜지고 착용된 상태입니다."
        } catch {
          status = "미리보기 영상 생성 실패 (촬영은 가능): \(error.localizedDescription)"
        }
      }
    } catch {
      status = "페어링 실패: \(error.localizedDescription)"
    }
  }

  private func useAsCapturedImage(_ item: PhotosPickerItem) async {
    guard let glasses else { return }
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        status = "사진을 불러오지 못했어요."
        return
      }
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("mock-capture.jpg")
      try data.write(to: url, options: .atomic)
      glasses.services.camera.setCapturedImage(fileURL: url)
      // The stream feed is what the scanning loop reads: rebuild it from the
      // same photo so the barcode is found in the simulator without hardware.
      if let photo = UIImage(data: data) {
        do {
          let feed = try await Task.detached(priority: .userInitiated) { try MockFeedVideo.make(from: photo) }.value
          glasses.services.camera.setCameraFeed(fileURL: feed)
          status = "촬영 사진으로 설정했어요. 미리보기 영상도 같은 사진으로 바꿨어요."
        } catch {
          status = "촬영 사진은 설정했지만 미리보기 영상 교체 실패: \(error.localizedDescription)"
        }
      } else {
        status = "촬영 사진으로 설정했어요."
      }
    } catch {
      status = "사진 설정 실패: \(error.localizedDescription)"
    }
  }
}

#endif
