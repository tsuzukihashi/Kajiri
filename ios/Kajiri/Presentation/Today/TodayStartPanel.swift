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

    /// 主役は「何をしてくれるか」の一文。カジリは小さく添える
    private var greeting: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("大きくて手がつかないことを、今すぐできる大きさにかじります。")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("頼まれごと、締め切り、思い出したこと。1行でも大丈夫です。")
                .font(.system(size: 15))
                .foregroundStyle(Theme.sub)
            KajiriSays(pose: .sit, text: String(localized: "気になってること、そのまま投げて。"))
                .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button("最初の丸太を投げる", action: onThrow)
                .buttonStyle(PrimaryButtonStyle())
            // つないだ・断った結果を必ず見せる（ボタンが消えるだけにしない）
            switch access {
            case .notDetermined:
                Button("先にカレンダーをつなぐ", action: onConnect)
                    .buttonStyle(SecondaryButtonStyle())
            case .granted:
                Label("カレンダーとつながりました。予定は「予定」のタブに並びます。", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .denied:
                Label("カレンダーは使わない設定です。あとから設定アプリで変えられます。", systemImage: "calendar.badge.minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: access)
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
