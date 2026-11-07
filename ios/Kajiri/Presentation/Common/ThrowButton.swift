import SwiftUI

/// 右下の＋。丸太を投げる（どのタブでも同じ場所・同じ見た目）
struct ThrowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Theme.ink, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
        }
        .accessibilityLabel(Text("丸太を投げる"))
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Theme.ground.ignoresSafeArea()
        ThrowButton {}
    }
}
