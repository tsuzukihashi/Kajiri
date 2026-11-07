import SwiftData
import SwiftUI

/// 「準備が要りそうな予定を探す」。押したときだけ、この先2週間の予定をカジリに送る。
/// 「この準備をかじってもらう」を押したら、閉じてから投げるシートを開く
struct PrepScanSheet: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @State private var scan = PrepScanViewModel()

    var body: some View {
        ScrollView {
            PrepScanCard(
                viewModel: scan,
                linked: linked,
                onScan: { Task { await scan.scan(calendar: calendar, linked: linked, now: AppClock.now) } },
                onThrow: { pick in
                    dismiss()
                    // シートが閉じきってから次のシートを出す（閉じる途中だと出ないことがある）
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        router.throwRequest = ThrowRequest(memo: pick.memo, sourceEventID: pick.eventID)
                    }
                }
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .background(Theme.ground)
    }

    private var linked: Set<String> {
        Set(logs.compactMap(\.sourceEventID))
    }
}

#if DEBUG
#Preview("まだ見てもらっていない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    PrepScanSheet()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .environment(AppRouter())
        .modelContainer(container)
}
#endif
