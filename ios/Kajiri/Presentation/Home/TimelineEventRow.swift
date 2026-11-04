import SwiftUI

/// 1日の線の予定1件。カレンダーの色の丸を線の上に置く
struct TimelineEventRow: View {
    let event: CalendarEvent
    let isPast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(CalendarUseCase.clock(event.start))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 50, alignment: .trailing)
                .padding(.top, 12)
            Circle()
                .fill(event.color)
                .frame(width: 14, height: 14)
                .frame(width: 34)
                .padding(.top, 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .heavy))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    Text("\(CalendarUseCase.clock(event.start))〜\(CalendarUseCase.clock(event.end))")
                    if !event.location.isEmpty {
                        Text(event.location).lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16).fill(.white)
                    .overlay(alignment: .leading) {
                        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16)
                            .fill(event.color)
                            .frame(width: 5)
                    }
            }
        }
        .foregroundStyle(Theme.ink)
        .opacity(isPast ? 0.45 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("予定を開く"))
    }
}

#if DEBUG
#Preview {
    VStack {
        TimelineEventRow(event: CalendarEvent.previewWeek(now: .now)[1], isPast: false)
        TimelineEventRow(event: CalendarEvent.previewWeek(now: .now)[0], isPast: true)
    }
    .padding()
    .background(Theme.ground)
}
#endif
