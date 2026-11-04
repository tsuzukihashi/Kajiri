import SwiftUI

/// 起床から就寝までの線。いまの時刻から就寝までが空き時間で、そこにカジリが今日の薪を置く
struct HomeTimeline: View {
    let now: Date
    let picks: TodayPicker.Picks
    let kajiriSteps: [Step]

    static let wakeHour = 6
    static let sleepHour = 23

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            anchorRow(time: "\(Self.wakeHour):00", title: "起床", symbol: "sun.max")
            freeTimeRow
            anchorRow(time: "\(Self.sleepHour):00", title: "就寝", symbol: "bed.double")
        }
        .padding(.trailing, 18)
        .background(alignment: .leading) {
            Rectangle()
                .fill(Theme.line)
                .frame(width: 2)
                .padding(.leading, 66)
                .padding(.vertical, 10)
        }
    }

    private func anchorRow(time: String, title: LocalizedStringKey, symbol: String) -> some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .frame(width: 50, alignment: .trailing)
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.sub)
                .frame(width: 34, height: 34)
                .background(Theme.card, in: .circle)
            VStack(alignment: .leading, spacing: 0) {
                Text(time).font(.system(size: 11)).foregroundStyle(Theme.sub)
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    private var freeTimeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(now, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.amber, in: .rect(cornerRadius: 6))
                .frame(width: 58, alignment: .trailing)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                Label("空き時間", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                freeTimeText
                Text("カジリが置いた今日の薪")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.sub)
                ForEach(picks.open) { step in
                    NavigationLink(value: Route.focus(step.uuid)) {
                        StepChip(title: step.title, minutes: step.minutes, isDone: false)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(picks.done) { step in
                    StepChip(title: step.title, minutes: step.minutes, isDone: true)
                }
                ForEach(kajiriSteps) { step in
                    NavigationLink(value: Route.handoff(step.uuid)) {
                        KajiriChip(step: step)
                    }
                    .buttonStyle(.plain)
                }
                if picks.open.isEmpty && kajiriSteps.isEmpty {
                    Text("いま、じぶんの番の薪はありません。カジリと仲間の番です。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.freeTime, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.81, green: 0.81, blue: 0.84)))
        }
    }

    private var freeTimeText: some View {
        let calendar = JapanDate.calendar
        let sleep = calendar.date(bySettingHour: Self.sleepHour, minute: 0, second: 0, of: now) ?? now
        let minutes = max(0, Int(sleep.timeIntervalSince(now) / 60))
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(minutes / 60)").font(.system(size: 26, weight: .black))
            Text("時間").font(.system(size: 13, weight: .bold))
            Text("\(minutes % 60)").font(.system(size: 26, weight: .black)).padding(.leading, 6)
            Text("分").font(.system(size: 13, weight: .bold))
        }
    }
}

#if DEBUG
#Preview("薪がある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps()
    NavigationStack {
        HomeTimeline(
            now: .now,
            picks: TodayPicker.pick(from: steps, now: .now, limit: 3),
            kajiriSteps: steps.filter { $0.owner == .kajiri }
        )
    }
    .modelContainer(container)
}
#endif
