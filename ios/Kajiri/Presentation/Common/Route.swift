import SwiftUI

/// タブの NavigationStack で行ける画面。行き先はすべてここに集める
enum Route: Hashable {
    /// この1本だけ（じぶんの薪）
    case focus(UUID)
    /// カジリから届いたものを受け取る（カジリの薪）
    case handoff(UUID)
    /// 丸太の中身（薪の並び・締め切り）
    case log(UUID)
    /// 月の予定
    case month
    /// 設定（アプリと自分のこと。確かめる版では Debug も）
    case settings
}

extension Route {
    /// 薪を押したときの行き先。カジリの薪は受け取る画面、それ以外は「この1本だけ」
    static func step(_ step: Step) -> Route {
        step.owner == .kajiri ? .handoff(step.uuid) : .focus(step.uuid)
    }
}

/// 各タブの NavigationStack のいちばん下にだけ付ける。子の画面には付けない
struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case let .focus(id): FocusView(stepID: id)
            case let .handoff(id): HandoffView(stepID: id)
            case let .log(id): LogDetailView(logID: id, isEmbedded: false)
            case .month: MonthView()
            case .settings: SettingsView()
            }
        }
    }
}

extension View {
    func routeDestinations() -> some View { modifier(RouteDestinations()) }
}
