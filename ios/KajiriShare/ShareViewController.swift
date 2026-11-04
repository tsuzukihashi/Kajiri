import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 共有シートの「Kajiri」。共有された文章や URL をメモにして置いておき、次に Kajiri を開いたときに投げるシートへ入れる。
/// ここではカジリを呼ばない（分けた結果を見て「これでいこう」を押すのはアプリの中）
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            let memo = await collectMemo()
            SharedInbox.push(memo)
            let host = UIHostingController(rootView: ShareDoneView(memo: memo) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
            addChild(host)
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }

    /// 共有された本文・文章・URL を1つのメモにまとめる
    private func collectMemo() async -> String {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var parts: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty { parts.append(text) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    parts.append(url.absoluteString)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    parts.append(text)
                }
            }
        }
        // 同じ文が本文と添付の両方に来ることがあるので、重ねない
        var seen: Set<String> = []
        return parts.filter { seen.insert($0).inserted }.joined(separator: "\n")
    }
}

/// 置いたことを伝えて閉じる
private struct ShareDoneView: View {
    let memo: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image("kajiri_face").resizable().scaledToFit().frame(width: 88, height: 88)
            Text(memo.isEmpty ? "投げられるものが見つかりませんでした" : "カジリに投げました")
                .font(.system(size: 20, weight: .black))
            Text(memo.isEmpty
                 ? "文章か URL を選んでから、もう一度お試しください。"
                 : "Kajiri を開くと、このメモを入れた投げるシートが出ます。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 13))
                    .lineLimit(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.95), in: .rect(cornerRadius: 14))
            }
            Button(action: onClose) {
                Text("閉じる")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: .rect(cornerRadius: 16))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.94, green: 0.94, blue: 0.96))
    }
}

#Preview("投げた") {
    ShareDoneView(memo: "来週の打ち合わせの資料、金曜までにお願いできますか？", onClose: {})
}

#Preview("何も無い") {
    ShareDoneView(memo: "", onClose: {})
}
