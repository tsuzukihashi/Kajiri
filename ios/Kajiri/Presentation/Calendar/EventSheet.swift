import SwiftData
import SwiftUI

/// 予定を1件開いたところ。予定という物に、できることを集める:
/// 準備をカジリにかじってもらう（丸太にする）・予定を直す
struct EventSheet: View {
    let event: CalendarEvent
    let onThrow: () -> Void

    @Environment(CalendarUseCase.self) private var calendar
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @State private var editor: EventEditorRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                EventSummary(event: event)
                if let log = logs.first(where: { $0.sourceEventID == event.id }) {
                    LinkedLogCard(log: log)
                } else {
                    prepCard
                }
                editControl
            }
            .padding(18)
        }
        .background(Theme.ground)
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
    }

    /// つないだ Google カレンダーの予定は読むだけなので、直すのは Google 側で
    @ViewBuilder
    private var editControl: some View {
        switch event.source {
        case .device:
            if calendar.access == .granted {
                Button("予定を直す") { editor = calendar.editorRequest(for: event) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        case .google(let link):
            if let link {
                Link("Google カレンダーで開く", destination: link)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var prepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                KajiriImage(pose: .face, size: 40)
                Text("当日までに手を動かすことがあるなら、カジリが薪にしておく。")
                    .font(.system(size: 14, weight: .bold))
            }
            Button("この予定の準備をかじってもらう", action: onThrow)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }
}

/// 予定の名前・日時・場所・カレンダー
private struct EventSummary: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title).font(.system(size: 22, weight: .black))
                Label(CalendarUseCase.when(event), systemImage: "clock")
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                }
                if !event.calendarTitle.isEmpty {
                    Label(event.calendarTitle, systemImage: "calendar")
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.ink)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// この予定から投げた丸太の進み具合
private struct LinkedLogCard: View {
    let log: Log

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この予定の丸太").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.sub)
            HStack {
                Text(log.title).font(.system(size: 16, weight: .heavy))
                Spacer()
                Text("\(log.doneCount)/\(log.steps.count)本").font(.system(size: 13, weight: .bold))
            }
            if let next = log.nextStep {
                Text("次: \(next.title)").font(.system(size: 13))
            } else {
                Text("準備は全部片づいた。").font(.system(size: 13, weight: .bold))
            }
        }
        .padding(14)
        .background(Theme.amberSoft, in: .rect(cornerRadius: 18))
    }
}

#if DEBUG
#Preview("まだ丸太にしていない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    EventSheet(event: CalendarEvent.previewWeek(now: .now)[2]) {}
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("Google の予定") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    let event = CalendarEvent.sample("打ち合わせ", day: .now, hour: 15, minute: 0, minutes: 60, location: "")
    EventSheet(
        event: CalendarEvent(
            id: "google|main|1", eventIdentifier: "1", title: event.title, start: event.start, end: event.end,
            isAllDay: false, location: "", calendarTitle: "仕事", red: 0.25, green: 0.47, blue: 0.85,
            source: .google(link: URL(string: "https://calendar.google.com"))
        )
    ) {}
    .environment(useCase)
    .environment(CalendarUseCase.preview(access: .denied))
    .modelContainer(container)
}

#Preview("丸太にした") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let event = CalendarEvent.sampleAllDay("引っ越し", day: .now)
    EventSheet(
        event: CalendarEvent(
            id: "preview-moving", eventIdentifier: "moving", title: event.title, start: event.start, end: event.end,
            isAllDay: true, location: "", calendarTitle: "家", red: 0.3, green: 0.68, blue: 0.4, source: .device
        )
    ) {}
    .environment(useCase)
    .environment(CalendarUseCase.preview(access: .granted))
    .modelContainer(container)
}
#endif
