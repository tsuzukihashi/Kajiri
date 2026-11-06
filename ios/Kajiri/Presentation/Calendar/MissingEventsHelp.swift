import SwiftUI

/// 月の表示の下。Outlook や会社のカレンダーは、iPhone の設定にアカウントを入れないと Kajiri から見えない
/// （Kajiri が直接読めるのは Google だけ）。その足し方を、押したときだけ開いて見せる
struct MissingEventsHelp: View {
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isOpen.toggle() }
            } label: {
                HStack {
                    Label("Outlook や会社の予定が出ないとき", systemImage: "questionmark.circle")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(isOpen ? "閉じる" : "足し方を開く"))

            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kajiri は、iPhone のカレンダーに入っている予定と、つないだ Google カレンダーの予定を読みます。ほかのカレンダーは、iPhone にアカウントを足すと並びます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                    step(1, "iPhone の「設定」を開く")
                    step(2, "「アプリ」→「カレンダー」→「カレンダーアカウント」")
                    step(3, "「アカウントを追加」→ 使っているサービスでログインする")
                    step(4, "「カレンダー」をオンにする")
                }
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(number)")
                .font(.system(size: 12, weight: .heavy))
                .frame(width: 20, height: 20)
                .background(Theme.chip, in: .circle)
            Text(text).font(.system(size: 14))
        }
        .foregroundStyle(Theme.ink)
    }
}

#Preview("閉じている") {
    MissingEventsHelp()
        .padding()
        .background(Theme.ground)
}
