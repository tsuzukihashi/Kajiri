import SwiftUI

/// 丸太の一覧のいちばん下。アプリと自分のこと（紹介・規約・プライバシー・お問い合わせ）
struct AboutLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionBox(title: "Kajiri について", detail: nil) {
                row("アプリ紹介", url: "https://tsuzukit.com/kajiri/")
                BoxTextDivider()
                row("プライバシーポリシー", url: "https://tsuzukit.com/kajiri/privacy.html")
                BoxTextDivider()
                row("利用規約", url: "https://tsuzukit.com/kajiri/terms.html")
                BoxTextDivider()
                row("お問い合わせ", url: "https://tsuzukit.com/contact/")
            }
            Text("カジリの提案は AI（Claude）が作ります。送る前・決める前に、中身を確かめてください。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack {
                    Text(title).font(.system(size: 15))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
        }
    }
}

#Preview {
    AboutLinks()
        .padding()
        .background(Theme.ground)
}
