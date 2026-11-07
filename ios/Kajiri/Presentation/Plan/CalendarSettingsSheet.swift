import SwiftUI

/// カレンダーの設定。iPhone のカレンダーの許可・Google カレンダーをつなぐ・予定が出ないときの足し方
struct CalendarSettingsSheet: View {
    @Environment(CalendarUseCase.self) private var calendar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("カレンダーの設定")
                    .font(.system(size: 22, weight: .black))
                if calendar.canReadEvents && calendar.access == .granted {
                    Label("iPhone のカレンダーを読んでいます", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                } else {
                    CalendarConnectCard(access: calendar.access) {
                        Task { await calendar.requestAccess() }
                    }
                }
                if calendar.googleConnection != .unavailable {
                    GoogleCalendarCard()
                }
                if calendar.access == .granted {
                    MissingEventsHelp()
                }
            }
            .padding(18)
        }
        .background(Theme.ground)
    }
}

#if DEBUG
#Preview("許可してある") {
    CalendarSettingsSheet()
        .environment(CalendarUseCase.preview(access: .granted))
}

#Preview("まだ聞いていない") {
    CalendarSettingsSheet()
        .environment(CalendarUseCase.preview(access: .notDetermined))
}
#endif
