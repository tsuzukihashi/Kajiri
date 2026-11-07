import SwiftUI

/// ひとまとまりの情報。見出しを箱の外に置き、中身は白い箱に入れて、行と行は線で分ける。
/// 行どうしは詰め、まとまりどうしは大きく空ける（`Theme.sectionSpacing`）ことで、どこからどこまでが1つかを見せる
struct SectionBox<Content: View>: View {
    let title: LocalizedStringKey
    /// 見出しの右に添える数や状態（「1/3」など）
    let detail: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
            }
            .background(.white, in: .rect(cornerRadius: 18))
        }
    }
}

/// 箱の中の行と行のあいだの線（左の印の分だけ下げる）
struct BoxDivider: View {
    var body: some View {
        Divider().padding(.leading, 50)
    }
}

/// 箱の中に並べる行。2行目から上に線を引く
struct BoxRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 { BoxDivider() }
            row(item)
        }
    }
}

#Preview("見出しと箱") {
    ScrollView {
        VStack(spacing: Theme.sectionSpacing) {
            SectionBox(title: "今日の薪", detail: "1/3 片づけた") {
                Text("1行目").frame(maxWidth: .infinity, alignment: .leading).padding(14)
                BoxDivider()
                Text("2行目").frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            SectionBox(title: "頼む・待ち", detail: nil) {
                Text("1行だけ").frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
        }
        .padding()
    }
    .background(Theme.ground)
}
