import SwiftUI

/// カレンダーの設定の「Google カレンダー」の箱の中身。Google カレンダーという物を、ここでつなぐ・切る。
/// iPhone の設定にアカウントを入れなくても、Kajiri の中でログインするだけで予定が並ぶ
struct GoogleCalendarCard: View {
    @Environment(CalendarUseCase.self) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                Spacer(minLength: 8)
                if calendar.isGoogleWorking { ProgressView() }
            }
            if let message = calendar.googleMessage {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var description: String {
        if case .connected(let account) = calendar.googleConnection {
            return account.isEmpty
                ? String(localized: "つないである。予定は読むだけで、書きかえない。")
                : String(localized: "\(account) とつないである。予定は読むだけで、書きかえない。")
        }
        return String(localized: "iPhone の設定に入れなくても、Google にログインするだけで予定が並ぶ。予定は読むだけで、書きかえない。")
    }

    @ViewBuilder
    private var actions: some View {
        switch calendar.googleConnection {
        case .connected:
            HStack(spacing: 8) {
                if calendar.googleMessage != nil {
                    Button("もう一度読む") {
                        Task { await calendar.retryGoogle(now: AppClock.now) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("つなぐのをやめる") {
                    Task { await calendar.disconnectGoogle() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(calendar.isGoogleWorking)
        case .expired:
            connectButton(title: "つなぎ直す")
        case .disconnected, .unavailable:
            connectButton(title: "Google カレンダーをつなぐ")
        }
    }

    private func connectButton(title: LocalizedStringKey) -> some View {
        Button(title) {
            Task { await calendar.connectGoogle(now: AppClock.now) }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(calendar.isGoogleWorking)
    }
}

#if DEBUG
private struct GoogleCalendarCardPreview: View {
    let failure: GoogleCalendarError?
    @State private var calendar: CalendarUseCase?

    var body: some View {
        Group {
            if let calendar {
                SectionBox(title: "Google カレンダー", detail: nil) { GoogleCalendarCard() }.environment(calendar)
            }
        }
        .padding()
        .background(Theme.ground)
        .task { calendar = await CalendarUseCase.previewGoogle(failure: failure) }
    }
}

#Preview("まだつないでいない") {
    SectionBox(title: "Google カレンダー", detail: nil) { GoogleCalendarCard() }
        .padding()
        .background(Theme.ground)
        .environment(CalendarUseCase.preview(access: .granted))
}

#Preview("つないである") {
    GoogleCalendarCardPreview(failure: nil)
}

#Preview("読めなかった") {
    GoogleCalendarCardPreview(failure: .requestFailed)
}

#Preview("切れている") {
    GoogleCalendarCardPreview(failure: .notAuthorized)
}
#endif
