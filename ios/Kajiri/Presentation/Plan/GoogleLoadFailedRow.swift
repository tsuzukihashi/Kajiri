import SwiftUI

/// Google カレンダーが読めなかったとき。予定が無いのではなく読めなかったことと、「もう一度」を出す
struct GoogleLoadFailedRow: View {
    let message: String
    let isWorking: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.amber)
            Text(message)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRetry) {
                Group {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text("もう一度")
                    }
                }
                .font(.system(size: 13, weight: .heavy))
                .frame(minWidth: 72, minHeight: 36)
                .background(Theme.chip, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .background(Theme.amberSoft, in: .rect(cornerRadius: 16))
    }
}

#Preview("読めなかった") {
    GoogleLoadFailedRow(message: "Google カレンダーを読めなかった。通信を確かめて、もう一度。", isWorking: false, onRetry: {})
        .padding()
        .background(Theme.ground)
}

#Preview("読み直している") {
    GoogleLoadFailedRow(message: "Google カレンダーを読めなかった。通信を確かめて、もう一度。", isWorking: true, onRetry: {})
        .padding()
        .background(Theme.ground)
}
