import SwiftUI

/// 「カジリに準備を見てもらう」。押したときだけ、この先2週間の予定の名前・日時・場所をカジリに送る
struct PrepScanCard: View {
    let viewModel: PrepScanViewModel
    let linked: Set<String>
    let onScan: () -> Void
    let onThrow: (PrepPick) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                KajiriImage(pose: .think, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("準備が要りそうな予定を探す").font(.system(size: 15, weight: .heavy))
                    Text("押したときだけ、この先2週間の予定の名前・日時・場所をカジリに送ります。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
            }
            content
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            Button("カジリに見てもらう", action: onScan).buttonStyle(PrimaryButtonStyle())
        case .scanning:
            HStack(spacing: 8) {
                ProgressView()
                Text("カジリが予定を見ています…").font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.system(size: 13))
            Button("もう一度見てもらう", action: onScan).buttonStyle(SecondaryButtonStyle())
        case let .result(result):
            KajiriBubbleRow(text: result.comment)
            ForEach(result.picks) { pick in
                PrepPickRow(
                    pick: pick,
                    event: viewModel.event(for: pick),
                    isThrown: linked.contains(pick.eventID),
                    onThrow: { onThrow(pick) }
                )
            }
            if result.picks.isEmpty {
                Text("予定が増えたら、また見てもらえます。").font(.system(size: 12)).foregroundStyle(Theme.sub)
            }
            Button("もう一度見てもらう", action: onScan)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

/// カジリのひとこと（小さな顔つき）
private struct KajiriBubbleRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            KajiriImage(pose: .face, size: 26)
            Text(text).font(.system(size: 14, weight: .bold))
        }
    }
}

/// 準備が要りそうな予定1件と、「かじってもらう」
private struct PrepPickRow: View {
    let pick: PrepPick
    let event: CalendarEvent?
    let isThrown: Bool
    let onThrow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let event {
                HStack(spacing: 6) {
                    Circle().fill(event.color).frame(width: 8, height: 8)
                    Text(event.title).font(.system(size: 14, weight: .heavy))
                }
                Text(CalendarUseCase.when(event)).font(.system(size: 12)).foregroundStyle(Theme.sub)
            }
            Text(pick.reason).font(.system(size: 13))
            if isThrown {
                Label("丸太にしました", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
            } else {
                Button("この準備をかじってもらう", action: onThrow).buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 14))
    }
}

#if DEBUG
#Preview("まだ見てもらっていない") {
    PrepScanCard(viewModel: PrepScanViewModel(), linked: [], onScan: {}, onThrow: { _ in })
        .padding()
        .background(Theme.ground)
}
#endif
