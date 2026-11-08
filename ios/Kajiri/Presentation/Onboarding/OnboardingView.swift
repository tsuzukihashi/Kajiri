import SwiftUI

/// はじめて開いたときの3ページ。最後のページで「最初の丸太を投げる」か「あとで」を選ぶ。
/// どのページでも「スキップ」で抜けられる（説明を読みたくない人を待たせない）
struct OnboardingView: View {
    /// 閉じるとき。true なら、続けて投げるシートを開く
    let onFinish: (_ startsThrowing: Bool) -> Void

    @Environment(\.columnLayout) private var columns
    @State private var index = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("スキップ") { onFinish(false) }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.sub)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 18)
                        .transition(.opacity)
                }
            }
            .frame(height: 52)
            TabView(selection: $index) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            ProgressDots(count: pages.count, current: index)
                .padding(.vertical, 16)
            actions
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
        }
        .background(Theme.ground)
        .animation(.easeInOut(duration: 0.25), value: index)
        .sensoryFeedback(.selection, trigger: index)
    }

    private var isLast: Bool { index == pages.count - 1 }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if isLast {
                Button("最初の丸太を投げる") { onFinish(true) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("あとで") { onFinish(false) }
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("次へ") {
                    withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
                }
                .buttonStyle(PrimaryButtonStyle())
                // 最後のページとボタンの数をそろえて、押す位置が動かないようにする
                Color.clear.frame(height: 48)
            }
        }
        .frame(maxWidth: 520)
    }
}

/// 何ページ中の何ページ目か
private struct ProgressDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.ink : Theme.line)
                    .frame(width: i == current ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(count)ページ中 \(current + 1)ページ目"))
    }
}

#Preview("オンボーディング") {
    OnboardingView(onFinish: { _ in })
}

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    OnboardingView(onFinish: { _ in })
        .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}
