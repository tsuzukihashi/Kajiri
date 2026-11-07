import SwiftUI

/// その日の終日の予定と、丸太の締め切り。1日の線の上に札で並べる
struct DayBannerRow: View {
    let allDay: [CalendarEvent]
    /// この日が締め切りの丸太（iPhone のカレンダーにまだ入れていないもの）
    let deadlines: [Log]
    let onEventTap: (CalendarEvent) -> Void

    var body: some View {
        if !allDay.isEmpty || !deadlines.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(allDay) { event in
                        Button { onEventTap(event) } label: {
                            HStack(spacing: 6) {
                                Circle().fill(event.color).frame(width: 8, height: 8)
                                Text(event.title).font(.system(size: 13, weight: .bold))
                                Text("終日").font(.system(size: 11)).foregroundStyle(Theme.sub)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.white, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(deadlines) { log in
                        HStack(spacing: 6) {
                            Image(systemName: "flag.fill").font(.system(size: 11))
                            Text("締め切り: \(log.title)").font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.amberSoft, in: .capsule)
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .foregroundStyle(Theme.ink)
        }
    }
}

#if DEBUG
#Preview("終日と締め切り") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    DayBannerRow(
        allDay: [.sampleAllDay("引っ越し", day: .now)],
        deadlines: useCase.allSteps().compactMap(\.log).prefix(1).map { $0 },
        onEventTap: { _ in }
    )
    .padding(.vertical)
    .background(Theme.ground)
    .modelContainer(container)
}

#Preview("何もない日") {
    DayBannerRow(allDay: [], deadlines: [], onEventTap: { _ in })
}
#endif
