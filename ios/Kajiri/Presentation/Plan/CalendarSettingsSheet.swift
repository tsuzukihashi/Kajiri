import SwiftUI

/// カレンダーの設定。カレンダーという物ごとに箱を分ける:
/// iPhone のカレンダー（許可）・Google カレンダー（つなぐ・切る）・ほかのカレンダー（足し方）
struct CalendarSettingsSheet: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                Text("カレンダーの設定")
                    .font(.system(size: 22, weight: .black))
                    .padding(.horizontal, 4)
                SectionBox(title: "iPhone のカレンダー", detail: nil) {
                    deviceCalendar
                }
                if calendar.googleConnection != .unavailable {
                    SectionBox(title: "Google カレンダー", detail: nil) {
                        GoogleCalendarCard()
                    }
                }
                if calendar.access == .granted {
                    SectionBox(title: "ほかのカレンダー", detail: nil) {
                        MissingEventsHelp()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .background(Theme.ground)
    }

    @ViewBuilder
    private var deviceCalendar: some View {
        if calendar.canReadEvents && calendar.access == .granted {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 26, height: 26)
                    .background(Theme.amberSoft, in: .rect(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("予定を読んでいます").font(.system(size: 15, weight: .bold))
                    Text("iPhone に入れてある Google・iCloud・Outlook の予定")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if calendar.access == .denied {
                        Text("設定でカレンダーを「フルアクセス」にすると、iPhone に入れてある Google・iCloud・Outlook の予定がここに並び、予定のすき間に薪を置けます。")
                    } else {
                        Text("iPhone に入れてある Google・iCloud・Outlook の予定をまとめて並べます。予定のすき間に、カジリが薪を置きます。")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                if calendar.access == .denied {
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("カレンダーをつなぐ") {
                        Task { await calendar.requestAccess() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(14)
        }
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
