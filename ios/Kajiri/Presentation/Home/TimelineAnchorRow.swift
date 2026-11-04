import SwiftUI

/// 1日の線の端（起床・就寝）
struct TimelineAnchorRow: View {
    let time: String
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .frame(width: 50, alignment: .trailing)
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.sub)
                .frame(width: 34, height: 34)
                .background(Theme.card, in: .circle)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }
}

#Preview {
    TimelineAnchorRow(time: "6:00", title: "起床", symbol: "sun.max")
        .padding()
        .background(Theme.ground)
}
