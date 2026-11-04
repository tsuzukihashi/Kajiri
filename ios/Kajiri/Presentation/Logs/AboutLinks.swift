import SwiftUI

/// 丸太の一覧のいちばん下。アプリと自分のこと（紹介・規約・プライバシー・お問い合わせ）
struct AboutLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kajiri について")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.sub)
                .padding(.bottom, 6)
            row("アプリ紹介", url: "https://tsuzukit.com/kajiri/")
            row("プライバシーポリシー", url: "https://tsuzukit.com/kajiri/privacy.html")
            row("利用規約", url: "https://tsuzukit.com/kajiri/terms.html")
            row("お問い合わせ", url: "https://tsuzukit.com/contact/")
            Text("カジリの提案は AI（Claude）が作ります。送る前・決める前に、中身を確かめてください。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack {
                    Text(title).font(.system(size: 14))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
        }
    }
}

#Preview {
    AboutLinks()
        .padding()
        .background(Theme.card)
}
