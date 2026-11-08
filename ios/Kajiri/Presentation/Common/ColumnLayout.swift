import SwiftUI

/// 画面を1列で見せるか、左右2列に分けて見せるか。
/// 横に広い画面（iPhone Duo を開いた内側など）では、折り目で左右に分けて、1つ下の階層までいっしょに見せる。
/// iPhone は縦向きだけなので、幅が高さを超えることがなく、いつも1列になる
nonisolated enum ColumnLayout: Equatable, Sendable {
    case single
    /// leading: 左の列の幅、gutter: 折り目の幅（何も置かない）
    case split(leading: CGFloat, gutter: CGFloat)

    var isSplit: Bool {
        if case .split = self { return true }
        return false
    }

    /// 割ったあと、右の列にも1列の画面がそのまま入る幅が要る
    static let minimumSplitWidth: CGFloat = 700

    static func resolve(size: CGSize, division: CGRect?) -> ColumnLayout {
        guard size.width > size.height, size.width >= minimumSplitWidth else { return .single }
        // 折り目があるなら、列の切れ目を折り目に合わせる（曲がるところに物を置かない）
        if let division, division.minX > 0, division.maxX < size.width, division.width > 0 {
            return .split(leading: division.minX.rounded(), gutter: division.width.rounded(.up))
        }
        return .split(leading: (size.width / 2 - 12).rounded(), gutter: 24)
    }
}

extension EnvironmentValues {
    @Entry var columnLayout: ColumnLayout = .single
}

/// タブの NavigationStack の「外」に1つだけ付ける。ここの大きさはウインドウが決めるので、中身の余白で値が揺れない
private struct MeasureColumns: ViewModifier {
    @State private var layout = ColumnLayout.single

    func body(content: Content) -> some View {
        content
            .environment(\.columnLayout, layout)
            .onGeometryChange(for: ColumnLayout.self) { proxy in
                // 折り曲げていないときも折り目の位置を使う（曲げるたびに列の幅が変わらないように）
                var division: CGRect?
                if #available(iOS 27.1, *) {
                    division = proxy.reservedRegions(kind: .division, options: .includeInactive)
                        .first(where: { $0.frame.height > $0.frame.width })?.frame
                }
                return ColumnLayout.resolve(size: proxy.size, division: division)
            } action: { newValue in
                guard newValue != layout else { return }
                withAnimation(.easeInOut(duration: 0.25)) { layout = newValue }
            }
    }
}

extension View {
    func measureColumns() -> some View { modifier(MeasureColumns()) }

    /// 2列のときは、スクロールでナビゲーションバーを畳ませない（畳むと、左右の列がまとめて上下に動く）。
    /// NavigationStack の中の、いちばん下の画面に付ける
    func keepsBarsInSplit() -> some View { modifier(KeepsBarsInSplit()) }
}

private struct KeepsBarsInSplit: ViewModifier {
    @Environment(\.columnLayout) private var layout

    func body(content: Content) -> some View {
        if layout.isSplit, #available(iOS 27.0, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
    }
}

/// 画面の中で、いまの列の組み方を読む（measureColumns を付けた NavigationStack の中で使う）
struct ColumnReader<Content: View>: View {
    @ViewBuilder let content: (ColumnLayout) -> Content
    @Environment(\.columnLayout) private var layout

    var body: some View { content(layout) }
}

/// 左の列と右の列。1列のときは、上から左・右の順に1つのスクロールに積む（iPhone の見え方そのまま）。
/// 2列のときは、それぞれ別にスクロールし、折り目には何も置かない
struct AdaptiveColumns<Leading: View, Trailing: View>: View {
    /// いちばん上の余白
    let topPadding: CGFloat
    /// いちばん下の余白（右下の＋に隠れないように）
    let bottomPadding: CGFloat
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    @Environment(\.columnLayout) private var layout

    var body: some View {
        switch layout {
        case .single:
            column {
                leading
                trailing
            }
        case let .split(leadingWidth, gutter):
            HStack(alignment: .top, spacing: 0) {
                column { leading }
                    .frame(width: leadingWidth)
                Color.clear
                    .frame(width: gutter)
                    .accessibilityHidden(true)
                column { trailing }
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
    }
}

#if DEBUG
private struct ColumnsPreviewBody: View {
    var body: some View {
        AdaptiveColumns(topPadding: 8, bottomPadding: 40) {
            SectionBox(title: "左の列", detail: nil) {
                Text("いまの1本").padding(16)
            }
        } trailing: {
            SectionBox(title: "右の列", detail: nil) {
                Text("残りの薪").padding(16)
            }
        }
        .background(Theme.ground)
    }
}

#Preview("1列（iPhone）") {
    ColumnsPreviewBody()
}

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    ColumnsPreviewBody()
        .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}
#endif
