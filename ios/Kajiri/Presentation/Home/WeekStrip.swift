import SwiftUI

/// 今週の7日。今日は黒い丸
struct WeekStrip: View {
    let now: Date

    var body: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        HStack(spacing: 0) {
            ForEach(Array(JapanDate.week(containing: now).enumerated()), id: \.offset) { index, day in
                let isToday = JapanDate.isSameDay(day, now)
                VStack(spacing: 8) {
                    Text(symbols[index])
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                    Text("\(JapanDate.calendar.component(.day, from: day))")
                        .font(.system(size: 18, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .white : Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(isToday ? Theme.ink : .clear, in: .circle)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isToday ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    WeekStrip(now: .now)
        .padding(.vertical)
        .background(Theme.ground)
}
