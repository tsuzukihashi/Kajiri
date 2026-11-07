import SwiftUI

/// 「準備が要りそうな予定を探す」の中身。上にカジリと説明、下に見つかった予定を1つの箱にまとめる。
/// 押したときだけ、この先2週間の予定の名前・日時・場所をカジリに送る
struct PrepScanCard: View {
    let viewModel: PrepScanViewModel
    let linked: Set<String>
    let onScan: () -> Void
    let onThrow: (PrepPick) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                KajiriImage(pose: .think, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("準備が要りそうな予定を探す").font(.system(size: 20, weight: .black))
                    Text("押したときだけ、この先2週間の予定の名前・日時・場所をカジリに送ります。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
            }
            content
        }
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
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(.white, in: .rect(cornerRadius: 18))
        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberSoft, in: .rect(cornerRadius: 14))
                Button("もう一度見てもらう", action: onScan).buttonStyle(SecondaryButtonStyle())
            }
        case let .result(result):
            VStack(alignment: .leading, spacing: 14) {
                KajiriBubbleRow(text: result.comment)
                if result.picks.isEmpty {
                    Text("予定が増えたら、また見てもらえます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                        .padding(.horizontal, 4)
                } else {
                    SectionBox(title: "準備が要りそうな予定", detail: String(localized: "\(result.picks.count)件")) {
                        ForEach(Array(result.picks.enumerated()), id: \.element.id) { index, pick in
                            if index > 0 { BoxTextDivider() }
                            PrepPickRow(
                                pick: pick,
                                event: viewModel.event(for: pick),
                                isThrown: linked.contains(pick.eventID),
                                onThrow: { onThrow(pick) }
                            )
                        }
                    }
                    .padding(.top, 10)
                }
                Button("もう一度見てもらう", action: onScan)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
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
        .padding(.horizontal, 4)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("まだ見てもらっていない") {
    PrepScanCard(viewModel: PrepScanViewModel(), linked: [], onScan: {}, onThrow: { _ in })
        .padding()
        .background(Theme.ground)
}
#endif
