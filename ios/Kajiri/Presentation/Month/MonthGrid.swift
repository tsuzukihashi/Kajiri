import SwiftUI

/// 月の表。日ごとに、予定のカレンダーの色の点（3つまで）と、締め切りの印を出す
struct MonthGrid: View {
    let month: Date
    let selected: Date
    let now: Date
    /// 日ごとの予定の色（"2026-11-04" の形）
    let dots: [String: [Color]]
    /// 丸太の締め切りがある日
    let deadlineDays: Set<String>
    let onSelect: (Date) -> Void

    var body: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity)
                }
            }
            Grid(horizontalSpacing: 0, verticalSpacing: 4) {
                ForEach(MonthGrid.weeks(of: month), id: \.self) { week in
                    GridRow {
                        ForEach(week, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = JapanDate.dayString(day)
        let isSelected = JapanDate.isSameDay(day, selected)
        let isToday = JapanDate.isSameDay(day, now)
        let inMonth = JapanDate.calendar.isDate(day, equalTo: month, toGranularity: .month)
        return Button { onSelect(day) } label: {
            VStack(spacing: 3) {
                Text("\(JapanDate.calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: isSelected || isToday ? .heavy : .regular))
                    .foregroundStyle(isSelected ? .white : (inMonth ? Theme.ink : Theme.sub.opacity(0.5)))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Theme.ink : (isToday ? Theme.amberSoft : .clear), in: .circle)
                HStack(spacing: 2) {
                    ForEach(Array((dots[key] ?? []).prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 5, height: 5)
                    }
                    if deadlineDays.contains(key) {
                        Image(systemName: "flag.fill").font(.system(size: 7)).foregroundStyle(Theme.amber)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.month().day().weekday()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// その月を含む週（日曜はじまり）を並べる
    static func weeks(of month: Date) -> [[Date]] {
        let calendar = JapanDate.calendar
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let last = JapanDate.addingDays(days - 1, to: first)
        var weeks: [[Date]] = []
        var start = JapanDate.week(containing: first)[0]
        while start <= last {
            weeks.append(JapanDate.week(containing: start))
            start = JapanDate.addingDays(7, to: start)
        }
        return weeks
    }
}

#Preview {
    MonthGrid(
        month: .now, selected: .now, now: .now,
        dots: [JapanDate.dayString(.now): [.blue, .green]],
        deadlineDays: [JapanDate.dayString(JapanDate.addingDays(3, to: .now))],
        onSelect: { _ in }
    )
    .padding()
    .background(Theme.ground)
}
