import SwiftUI

/// 日〜土の、片づけた薪の本数の棒。いちばん多い日を琥珀色にする
struct WeekBars: View {
    let days: [Int]

    var body: some View {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let top = max(1, days.max() ?? 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, count in
                VStack(spacing: 6) {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(count == 0 ? .clear : Theme.sub)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(count == top && count > 0 ? Theme.amber : (count == 0 ? Theme.line : Theme.ink))
                        .frame(height: max(6, CGFloat(count) / CGFloat(top) * 80))
                    Text(symbols[index]).font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel(Text(zip(symbols, days).map { "\($0)曜 \($1)本" }.joined(separator: "、")))
    }
}

#Preview("ある週") {
    WeekBars(days: [0, 2, 1, 4, 3, 0, 2]).padding().background(Theme.card)
}

#Preview("0本の週") {
    WeekBars(days: [0, 0, 0, 0, 0, 0, 0]).padding().background(Theme.card)
}
