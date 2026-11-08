import SwiftData
import SwiftUI

/// 設定。アプリと自分のこと（版・紹介・規約）と、確かめる版だけの Debug
struct SettingsView: View {
    @Environment(LogUseCase.self) private var useCase
    @Environment(AppRouter.self) private var router
    @Query private var logs: [Log]
    @Query private var steps: [Step]

    @State private var isConfirmingDelete = false
    @State private var deletePhase = DebugDataSection.Phase.idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                SectionBox(title: "このアプリ", detail: nil) {
                    HStack {
                        Text("バージョン").font(.system(size: 15))
                        Spacer()
                        Text(Self.versionText).font(.system(size: 15)).foregroundStyle(Theme.sub).monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                AboutLinks()
                if InternalBuild.shared.isEnabled {
                    DebugDataSection(
                        logCount: logs.count,
                        stepCount: steps.count,
                        phase: deletePhase,
                        onDelete: { isConfirmingDelete = true }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .background(Theme.ground)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("これまでのデータをすべて消しますか？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("すべて消す", role: .destructive) {
                Task { await deleteAll() }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("丸太\(logs.count)本・薪\(steps.count)本と、カジリから届いたもの・チェック・メモ・週のふりかえりを消します。元に戻せません。iPhone のカレンダーに入れた予定と、Google カレンダーのつなぎは残ります。")
        }
        .sensoryFeedback(.success, trigger: deletePhase) { _, new in new == .done }
    }

    /// 消して、今日のいちばん初め（「最初の丸太を投げる」）に戻す。消えたことが画面で分かるように
    private func deleteAll() async {
        withAnimation { deletePhase = .deleting }
        do {
            try await useCase.deleteAllData()
            deletePhase = .done
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 0.3)) {
                router.tab = .today
                router.todayPath = []
            }
        } catch {
            withAnimation { deletePhase = .failed(error.localizedDescription) }
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#if DEBUG
#Preview("データあり") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    return NavigationStack { SettingsView() }
        .environment(useCase)
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("データなし") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    return NavigationStack { SettingsView() }
        .environment(useCase)
        .environment(AppRouter())
        .modelContainer(container)
}
#endif
