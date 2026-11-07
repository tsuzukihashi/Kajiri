import SwiftUI

/// 空き時間の箱に置く、今日の薪1本
struct StepChip: View {
    let title: String
    let minutes: Int
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDone ? Theme.ink : Theme.sub)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .strikethrough(isDone)
                .foregroundStyle(isDone ? Theme.sub : Theme.ink)
                .multilineTextAlignment(.leading)
            Text("\(minutes)分")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

/// カジリの番の薪。進み具合で見た目を変える
struct KajiriChip: View {
    let step: Step

    var body: some View {
        HStack(spacing: 6) {
            KajiriImage(pose: .face, size: 20)
            Text(label)
                .font(.system(size: 13, weight: step.workState == .ready ? .bold : .regular))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            if step.workState == .working {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(step.workState == .ready ? Theme.amberSoft : Theme.card, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.66, green: 0.66, blue: 0.68), style: StrokeStyle(lineWidth: 1, dash: step.workState == .ready ? [] : [4, 3]))
        )
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        switch step.workState {
        case .idle, .working: String(localized: "カジリが進行中: \(step.title)")
        case .ready: String(localized: "カジリから届いた: \(step.title)")
        case .failed: String(localized: "カジリがつまずいた: \(step.title)")
        }
    }
}

#Preview("チップ") {
    VStack(alignment: .leading) {
        StepChip(title: "年末調整の用紙を机に出す", minutes: 2, isDone: false)
        StepChip(title: "粗大ゴミの受付に電話", minutes: 10, isDone: true)
    }
    .padding()
    .background(Theme.freeTime)
}
