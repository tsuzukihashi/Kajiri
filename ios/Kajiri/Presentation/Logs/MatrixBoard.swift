import SwiftData
import SwiftUI

/// 4象限（急ぐか × 大事か）。カジリが薪を置き分けたもの。薪を押すと、その薪の画面へ
struct MatrixBoard: View {
    @Query(sort: \Step.order) private var steps: [Step]

    var body: some View {
        let open = steps.filter { !$0.isDone }
        VStack(alignment: .leading, spacing: 10) {
            Text("急ぐか・大事かで、カジリが置き分けました。締め切りが近づいた薪は「今日やる」へ動きます。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    QuadrantBox(quadrant: .today, steps: open.filter { $0.quadrant == .today }, isDark: true)
                    QuadrantBox(quadrant: .stock, steps: open.filter { $0.quadrant == .stock }, isDark: false)
                }
                GridRow {
                    QuadrantBox(quadrant: .handoff, steps: open.filter { $0.quadrant == .handoff }, isDark: false)
                    QuadrantBox(quadrant: .drop, steps: open.filter { $0.quadrant == .drop }, isDark: false)
                }
            }
        }
    }
}

private struct QuadrantBox: View {
    let quadrant: Quadrant
    let steps: [Step]
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(quadrant.label).font(.system(size: 15, weight: .heavy))
                Text("\(steps.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 7)
                    .background(Theme.amber, in: .capsule)
            }
            Text(quadrant.note).font(.system(size: 11)).foregroundStyle(isDark ? Color(white: 0.8) : Theme.sub)
            if steps.isEmpty {
                Text("いまは空っぽ").font(.system(size: 12)).foregroundStyle(isDark ? Color(white: 0.7) : Theme.sub)
            }
            ForEach(steps.prefix(6)) { step in
                NavigationLink(value: Route.step(step)) {
                    Text(step.title)
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isDark ? Color(white: 0.23) : Theme.chip, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            if steps.count > 6 {
                Text("ほか\(steps.count - 6)本").font(.system(size: 11)).foregroundStyle(isDark ? Color(white: 0.8) : Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isDark ? .white : Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(background, in: .rect(cornerRadius: 20))
    }

    private var background: Color {
        switch quadrant {
        case .today: Theme.ink
        case .handoff: Theme.amberSoft
        case .stock, .drop: Theme.card
        }
    }
}

#if DEBUG
#Preview("薪がある") {
    let (_, container) = LogUseCase.preview(filled: true)
    NavigationStack { ScrollView { MatrixBoard().padding() } }.modelContainer(container)
}

#Preview("空") {
    let (_, container) = LogUseCase.preview(filled: false)
    NavigationStack { ScrollView { MatrixBoard().padding() } }.modelContainer(container)
}
#endif
