import SwiftUI

/// まだ丸太が1本も無いとき。カジリが「投げて」と待っている
struct TodayStartPanel: View {
    let access: CalendarAccess
    let onThrow: () -> Void
    let onConnect: () -> Void

    @Environment(\.columnLayout) private var layout

    var body: some View {
        switch layout {
        case .single:
            VStack(spacing: 6) {
                Spacer()
                greeting
                Spacer()
                actions
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        case let .split(leading, gutter):
            // 横に広い画面: 左にカジリ、右に押すところ（折り目には何も置かない）
            HStack(spacing: 0) {
                VStack {
                    Spacer()
                    greeting
                    Spacer()
                }
                .frame(width: leading)
                Color.clear.frame(width: gutter)
                VStack(alignment: .leading, spacing: 18) {
                    Spacer()
                    Text("まずは1つ、投げてみる")
                        .font(.system(size: 22, weight: .black))
                    actions
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var greeting: some View {
        VStack(spacing: 6) {
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
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button("最初の丸太を投げる", action: onThrow)
                .buttonStyle(PrimaryButtonStyle())
            if access == .notDetermined {
                Button("先にカレンダーの予定を並べる", action: onConnect)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

#Preview("カレンダーをまだ聞いていない") {
    TodayStartPanel(access: .notDetermined, onThrow: {}, onConnect: {})
        .background(Theme.ground)
}

#Preview("カレンダーは断られた") {
    TodayStartPanel(access: .denied, onThrow: {}, onConnect: {})
        .background(Theme.ground)
}

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    TodayStartPanel(access: .notDetermined, onThrow: {}, onConnect: {})
        .background(Theme.ground)
        .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}
