import SwiftUI

/// 画面の下からのぞく「丸太」のシート。押すと一覧を引き上げる
struct LogsPeekBar: View {
    let logs: [Log]
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 12) {
                Capsule().fill(Color(red: 0.78, green: 0.78, blue: 0.8)).frame(width: 40, height: 5)
                HStack(spacing: 8) {
                    Text("丸太").font(.system(size: 18, weight: .heavy))
                    Text("\(logs.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.sub)
                        .padding(.horizontal, 8)
                        .background(Theme.chip, in: .capsule)
                    Spacer()
                    Text(logs.map(\.title).joined(separator: "・"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
            .shadow(color: .black.opacity(0.05), radius: 6, y: -2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("丸太の一覧を開く"))
    }
}

#Preview {
    VStack {
        Spacer()
        LogsPeekBar(logs: []) {}
    }
    .background(Theme.ground)
}
