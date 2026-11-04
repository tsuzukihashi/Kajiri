import SwiftUI

/// 今日の分が終わったとき。積み上がったダムを見せて、続けるか休むかを選んでもらう。
/// 予定はまだ残っていることがあるので、このあとの予定も並べる
struct HomeDoneView: View {
    let doneToday: Int
    let damCount: Int
    /// 今日のこのあとの予定（終日は除く）
    let upcoming: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void
    let onWeekly: () -> Void
    let onMore: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                KajiriBubble(text: String(localized: "今日の\(doneToday)本、おわり。ダムが伸びたぞ。"))
                    .padding(.top, 24)
                KajiriImage(pose: .dam, size: 240)
                Button(action: onWeekly) {
                    DamCountCard(damCount: damCount, doneToday: doneToday)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("週のふりかえりを開く"))
                if !upcoming.isEmpty {
                    upcomingList
                }
                NavigationLink(value: Route.month) {
                    Label("カレンダーを見る", systemImage: "calendar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: 44)
                }
                .padding(.top, 6)
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button("今日はおしまい", action: onFinish).buttonStyle(PrimaryButtonStyle())
                Button("もう1本だけ", action: onMore)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 48)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Theme.ground)
        }
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("このあとの予定")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.sub)
            ForEach(upcoming) { event in
                Button { onEventTap(event) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(event.color).frame(width: 10, height: 10)
                        Text(CalendarUseCase.clock(event.start)).font(.system(size: 13, weight: .bold))
                        Text(event.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                        Spacer()
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

/// 積み上がったダムの本数
private struct DamCountCard: View {
    let damCount: Int
    let doneToday: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("ダム").font(.system(size: 13)).foregroundStyle(Theme.sub)
            Text("\(damCount)").font(.system(size: 30, weight: .black))
            Text("本").font(.system(size: 13, weight: .bold))
            Spacer()
            Text("今日 +\(doneToday)")
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Theme.amber, in: .capsule)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }
}

#if DEBUG
#Preview("このあとの予定がある") {
    NavigationStack {
        HomeDoneView(
            doneToday: 3, damCount: 15,
            upcoming: Array(CalendarEvent.previewWeek(now: .now).prefix(2)),
            onEventTap: { _ in }, onWeekly: {}, onMore: {}, onFinish: {}
        )
        .background(Theme.ground)
    }
}

#Preview("予定なし") {
    NavigationStack {
        HomeDoneView(doneToday: 3, damCount: 15, upcoming: [], onEventTap: { _ in }, onWeekly: {}, onMore: {}, onFinish: {})
            .background(Theme.ground)
    }
}
#endif
