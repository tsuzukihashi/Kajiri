import SwiftUI

/// カジリがカレンダーに入れた予定。確認は挟まず、入れたあとで「戻す」を出す
struct PlacedEventsCard: View {
    @Environment(\.openURL) private var openURL
    let placement: EventPlacement
    let onUndo: (PlacedEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(heading, systemImage: "calendar.badge.plus")
                .font(.system(size: 14, weight: .heavy))
            ForEach(placement.events) { placed in
                PlacedEventRow(placed: placed, onUndo: onUndo)
            }
            if placement.needsAccess {
                Text("iPhone のカレンダーを許可すると、カジリが入れられる。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft, in: .rect(cornerRadius: 18))
    }

    private var heading: LocalizedStringKey {
        let added = placement.events.contains { if case .added = $0.state { true } else { false } }
        return added ? "カレンダーに入れた" : "カレンダーの予定"
    }
}

#if DEBUG
#Preview("入れた") {
    PlacedEventsCard(placement: .sampleAdded, onUndo: { _ in }).padding()
}

#Preview("許可が無い") {
    PlacedEventsCard(placement: .sampleNeedsAccess, onUndo: { _ in }).padding()
}

#Preview("もう入っていた") {
    PlacedEventsCard(
        placement: EventPlacement(
            events: EventPlacement.sampleAdded.events.map { PlacedEvent(id: $0.id, event: $0.event, state: .alreadyThere) },
            needsAccess: false
        ),
        onUndo: { _ in }
    )
    .padding()
}

#Preview("戻した") {
    PlacedEventsCard(
        placement: EventPlacement(
            events: EventPlacement.sampleAdded.events.map { PlacedEvent(id: $0.id, event: $0.event, state: .undone) },
            needsAccess: false
        ),
        onUndo: { _ in }
    )
    .padding()
}
#endif
