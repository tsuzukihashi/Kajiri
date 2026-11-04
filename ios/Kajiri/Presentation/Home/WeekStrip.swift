import SwiftUI

/// 選んでいる日を含む週の7日。選んだ日は黒い丸、予定や締め切りがある日は下に点
struct WeekStrip: View {
    let selected: Date
    let now: Date
    /// 予定・締め切りがある日（"2026-11-04" の形）
    let marks: Set<String>
    let onSelect: (Date) -> Void

    var body: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        HStack(spacing: 0) {
            ForEach(Array(JapanDate.week(containing: selected).enumerated()), id: \.offset) { index, day in
                let isSelected = JapanDate.isSameDay(day, selected)
                let isToday = JapanDate.isSameDay(day, now)
                Button { onSelect(day) } label: {
                    VStack(spacing: 6) {
                        Text(symbols[index])
                            .font(.system(size: 12, weight: isToday ? .heavy : .regular))
                            .foregroundStyle(isToday ? Theme.ink : Theme.sub)
                        Text("\(JapanDate.calendar.component(.day, from: day))")
                            .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? .white : Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(isSelected ? Theme.ink : .clear, in: .circle)
                        Circle()
                            .fill(marks.contains(JapanDate.dayString(day)) ? Theme.sub : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    WeekStrip(selected: .now, now: .now, marks: [JapanDate.dayString(.now)]) { _ in }
        .padding(.vertical)
        .background(Theme.ground)
}
