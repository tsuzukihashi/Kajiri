import SwiftUI

/// オンボーディングの1ページ。絵（水彩の薪）と、見出し1行・説明1〜2行。
/// 横に広い画面では、左に絵、右に言葉
struct OnboardingPageView: View {
    let page: OnboardingPage

    @Environment(\.columnLayout) private var columns

    var body: some View {
        switch columns {
        case .single:
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                picture
                    .frame(maxWidth: 300, maxHeight: 300)
                words(alignment: .center)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        case let .split(leading, gutter):
            HStack(spacing: 0) {
                picture
                    .frame(maxWidth: 360, maxHeight: 360)
                    .frame(width: leading)
                Color.clear.frame(width: gutter)
                words(alignment: .leading)
                    .padding(.horizontal, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var picture: some View {
        // 絵の地は画面の地とわずかに色が違うので、角を丸めたカードとして見せる
        Image(page.image)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 36))
            .accessibilityHidden(true)
    }

    private func words(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Text(page.title)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(page.body)
                .font(.system(size: 16))
                .foregroundStyle(Theme.sub)
                .lineSpacing(5)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("1ページ目") {
    OnboardingPageView(page: OnboardingPage.all[0])
        .background(Theme.ground)
}
