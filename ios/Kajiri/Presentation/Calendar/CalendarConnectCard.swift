import SwiftUI

/// カレンダーをまだ読めないときに、1日の線の上に出す。
/// 予定を並べると、空き時間が本当の予定のすき間になる
struct CalendarConnectCard: View {
    let access: CalendarAccess
    let onConnect: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(CalendarUseCase.self) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("カレンダーの予定を並べる", systemImage: "calendar")
                .font(.system(size: 15, weight: .heavy))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
            Button(buttonTitle) {
                if access == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    onConnect()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            if calendar.googleConnection != .unavailable {
                Button("Google カレンダーをつなぐ") {
                    Task { await calendar.connectGoogle(now: AppClock.now) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(calendar.isGoogleWorking)
            }
            if let message = calendar.googleMessage {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 18)
    }

    private var message: String {
        switch access {
        case .denied:
            String(localized: "設定でカレンダーを「フルアクセス」にすると、iPhone に入れてある Google・iCloud・Outlook の予定がここに並び、予定のすき間に薪を置けます。")
        case .notDetermined, .granted:
            String(localized: "iPhone に入れてある Google・iCloud・Outlook の予定をまとめて並べます。予定のすき間に、カジリが薪を置きます。")
        }
    }

    private var buttonTitle: String {
        access == .denied ? String(localized: "設定を開く") : String(localized: "カレンダーをつなぐ")
    }
}

#Preview("まだ聞いていない") {
    CalendarConnectCard(access: .notDetermined) {}
        .padding(.vertical)
        .background(Theme.ground)
        .environment(CalendarUseCase.preview(access: .notDetermined))
}

#Preview("断られた") {
    CalendarConnectCard(access: .denied) {}
        .padding(.vertical)
        .background(Theme.ground)
        .environment(CalendarUseCase.preview(access: .denied))
}
