import SwiftUI

/// カジリがかじった結果。薪が「誰がやるか」の印つきで並ぶ
struct SplitResultView: View {
    let result: DecomposeResult
    let onBack: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(result.steps.enumerated()), id: \.offset) { _, step in
                        StepRow(step: step)
                    }
                    if !result.why.isEmpty {
                        Label(result.why, systemImage: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
            }
            HStack(spacing: 10) {
                Button("書き直す", action: onBack).buttonStyle(SecondaryButtonStyle())
                Button("これでいこう", action: onAccept).buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(Theme.ground.shadow(.drop(color: .black.opacity(0.06), radius: 6, y: -3)))
        }
        .background(Theme.ground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                if let deadline = JapanDate.date(day: result.deadline) {
                    Text("\(deadline, format: .dateTime.month().day())まで")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.amber, in: .capsule)
                }
            }
            HStack(spacing: 14) {
                KajiriImage(pose: .gnaw, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("· 丸太").font(.system(size: 12)).foregroundStyle(Color(white: 0.68))
                    Text(result.logTitle).font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                    Text(result.comment).font(.system(size: 13)).foregroundStyle(Color(white: 0.9))
                }
            }
        }
        .padding(16)
        .padding(.top, 8)
        .background(Theme.ink)
    }
}

#if DEBUG
#Preview {
    SplitResultView(result: .sampleTax, onBack: {}, onAccept: {})
}
#endif
