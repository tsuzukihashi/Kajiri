import SwiftUI

/// まだ丸太が1本も無いとき。カジリが「投げて」と待っている
struct HomeEmptyView: View {
    let access: CalendarAccess
    let onThrow: () -> Void
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            KajiriBubble(text: String(localized: "気になってること、そのまま投げて。"))
            KajiriImage(pose: .sit, size: 230)
            VStack(spacing: 8) {
                Text("大きくて手がつかないことを、カジリが今すぐできる大きさにかじります。")
                Text("頼まれごと、締め切り、思い出したこと。1行でも大丈夫です。")
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.sub)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            Spacer()
            VStack(spacing: 8) {
                Button("最初の丸太を投げる", action: onThrow)
                    .buttonStyle(PrimaryButtonStyle())
                if access == .notDetermined {
                    Button("先にカレンダーの予定を並べる", action: onConnect)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("カレンダーをまだ聞いていない") {
    HomeEmptyView(access: .notDetermined, onThrow: {}, onConnect: {})
        .background(Theme.ground)
}

#Preview("カレンダーは断られた") {
    HomeEmptyView(access: .denied, onThrow: {}, onConnect: {})
        .background(Theme.ground)
}
