import SwiftUI

/// 入れた予定の1行。名前と日時、右に「戻す」か、どうなったか
struct PlacedEventRow: View {
    let placed: PlacedEvent
    let onUndo: (PlacedEvent) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(Theme.amberSoft, in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(placed.event.title)
                    .font(.system(size: 15, weight: .bold))
                    .strikethrough(placed.state == .undone)
                Text(CalendarUseCase.whenText(start: placed.event.start, end: placed.event.end, isAllDay: placed.event.isAllDay))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
            trailing
        }
        .padding(14)
    }

    @ViewBuilder
    private var trailing: some View {
        switch placed.state {
        case .added:
            Button("戻す") { onUndo(placed) }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.chip, in: .capsule)
        case .alreadyThere:
            status("もう入っていた")
        case .undone:
            status("戻した")
        case .notAdded:
            status("入れていない")
        }
    }

    private func status(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.sub)
    }
}

#if DEBUG
#Preview("入れた") {
    PlacedEventRow(placed: EventPlacement.sampleAdded.events[0], onUndo: { _ in }).padding()
}

#Preview("入れていない") {
    PlacedEventRow(placed: EventPlacement.sampleNeedsAccess.events[0], onUndo: { _ in }).padding()
}
#endif
