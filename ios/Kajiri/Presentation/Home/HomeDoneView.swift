import SwiftUI

/// 今日の分が終わったとき。積み上がったダムを見せて、続けるか休むかを選んでもらう
struct HomeDoneView: View {
    let doneToday: Int
    let damCount: Int
    let onMore: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            KajiriBubble(text: String(localized: "今日の\(doneToday)本、おわり。ダムが伸びたぞ。"))
            KajiriImage(pose: .dam, size: 260)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("ダム").font(.system(size: 13)).foregroundStyle(Theme.sub)
                Text("\(damCount)").font(.system(size: 30, weight: .black))
                Text("本").font(.system(size: 13, weight: .bold))
                Spacer()
                Text("今日 +\(doneToday)")
                    .font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Theme.amber, in: .capsule)
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            .padding(.horizontal, 18)
            .padding(.top, 10)
            Spacer()
            VStack(spacing: 8) {
                Button("今日はおしまい", action: onFinish).buttonStyle(PrimaryButtonStyle())
                Button("もう1本だけ", action: onMore)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 48)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    HomeDoneView(doneToday: 3, damCount: 15, onMore: {}, onFinish: {})
        .background(Theme.ground)
}
