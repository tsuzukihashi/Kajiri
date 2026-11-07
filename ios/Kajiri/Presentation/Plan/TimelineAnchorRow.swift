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
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
                .frame(width: 34, height: 34)
                .background(Theme.ground, in: .circle)
            // 起床・就寝は1日の端の目印なので、予定や空き時間より控えめに（箱に入れない）
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.sub)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TimelineAnchorRow(time: "6:00", title: "起床", symbol: "sun.max")
        .padding()
        .background(Theme.ground)
}
