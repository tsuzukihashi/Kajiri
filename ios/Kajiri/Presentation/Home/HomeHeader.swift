import SwiftUI

/// 大きな日付（押すと月の表示）と、今日へ戻る・予定を足す・4象限のボタン
struct HomeHeader: View {
    let day: Date
    let isToday: Bool
    let canAddEvent: Bool
    let onToday: () -> Void
    let onAddEvent: () -> Void

    var body: some View {
        let calendar = JapanDate.calendar
        HStack(alignment: .bottom, spacing: 8) {
            NavigationLink(value: Route.month) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 52, weight: .black))
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 3) {
                            Text("\(calendar.component(.month, from: day))月")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        Text(verbatim: "\(calendar.component(.year, from: day))・\(JapanDate.weekdaySymbol(day))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.sub)
                    }
                    .padding(.bottom, 6)
                }
                .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("月の予定を開く"))
            Spacer()
            Button("今日", action: onToday)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isToday ? .white : Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(isToday ? Theme.ink : Theme.chip, in: .capsule)
            if canAddEvent {
                Button(action: onAddEvent) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.chip, in: .circle)
                }
                .accessibilityLabel(Text("予定を足す"))
            }
            NavigationLink(value: Route.matrix) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.chip, in: .circle)
            }
            .accessibilityLabel(Text("川辺の地図（4象限）"))
        }
        .padding(.horizontal, 18)
    }
}

#Preview("今日") {
    NavigationStack {
        HomeHeader(day: .now, isToday: true, canAddEvent: true, onToday: {}, onAddEvent: {})
    }
}

#Preview("ほかの日・カレンダーなし") {
    NavigationStack {
        HomeHeader(day: JapanDate.addingDays(3, to: .now), isToday: false, canAddEvent: false, onToday: {}, onAddEvent: {})
    }
}
