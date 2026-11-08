import SwiftUI

/// 追加のシートの黒い帯。閉じる・カジリに渡す
struct ThrowHeader: View {
    let isSplitting: Bool
    let canSplit: Bool
    let onClose: () -> Void
    let onSplit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(white: 0.39), in: .circle)
                }
                // 分けている最中に閉じると、結果（予定・戻す）が見えないまま進むので押せなくする
                .disabled(isSplitting)
                .opacity(isSplitting ? 0.35 : 1)
                .accessibilityLabel(Text("閉じる"))
                Spacer()
                Button(action: onSplit) {
                    Group {
                        if isSplitting {
                            ProgressView().tint(Theme.ink)
                        } else {
                            Text("カジリに渡す")
                        }
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Color(white: 0.95), in: .capsule)
                }
                .disabled(!canSplit)
                .opacity(canSplit || isSplitting ? 1 : 0.5)
            }
            HStack(spacing: 14) {
                KajiriImage(pose: .gnaw, size: 64)
                    .background(Color(white: 0.95), in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("· 丸太を投げる")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.68))
                    Text("大きいままでいい。かじるのは任せて")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .padding(.top, 8)
        .background(Theme.ink)
    }
}

#Preview {
    ThrowHeader(isSplitting: false, canSplit: true, onClose: {}, onSplit: {})
}
