import SwiftUI

/// 大きな日付と、4象限への丸いボタン
struct HomeHeader: View {
    let now: Date

    var body: some View {
        let calendar = JapanDate.calendar
        HStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                Text("\(calendar.component(.day, from: now))")
                    .font(.system(size: 52, weight: .black))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(calendar.component(.month, from: now))月")
                        .font(.system(size: 17, weight: .bold))
                    Text(verbatim: "\(calendar.component(.year, from: now))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.sub)
                }
                .padding(.bottom, 6)
            }
            Spacer()
            Text("今日")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Theme.ink, in: .capsule)
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

#Preview {
    NavigationStack {
        HomeHeader(now: .now)
    }
}
