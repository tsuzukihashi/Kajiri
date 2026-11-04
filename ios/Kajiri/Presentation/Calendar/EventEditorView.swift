import EventKit
import EventKitUI
import SwiftUI

/// 予定を作る・直す・消す画面。Apple の標準の画面（EKEventEditViewController）をそのまま出す。
/// くり返し・通知・招待・カレンダーの選択は、この画面に任せる。
struct EventEditorView: UIViewControllerRepresentable {
    let request: EventEditorRequest
    /// 保存したらその予定の名前、やめた・消したら nil
    let onDone: @MainActor (String?) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = request.store
        controller.event = request.event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    /// 標準の画面は、閉じるのを呼んだ側に任せる。保存・やめる・消すのどれでも、ここで閉じる
    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        private let onDone: @MainActor (String?) -> Void

        init(onDone: @escaping @MainActor (String?) -> Void) {
            self.onDone = onDone
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            let saved = action == .saved ? controller.event?.eventIdentifier : nil
            onDone(saved)
        }
    }
}
