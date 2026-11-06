import Foundation
@preconcurrency import GoogleSignIn
import UIKit

enum GoogleCalendarError: Error, Equatable {
    /// つなぎ直しが要る（許可を取り消された・ログインが切れた）
    case notAuthorized
    /// ログインの画面でカレンダーのチェックを外された
    case scopeMissing
    /// 通信できない・Google が答えない
    case requestFailed
}

/// Google カレンダーを読む口。Preview とテストでは偽物を差し込む。
/// 読むだけで、Google の予定は書きかえない
@MainActor
protocol GoogleCalendarRepositoryProtocol: AnyObject {
    /// このビルドに Google の設定が入っているか
    var isAvailable: Bool { get }
    /// 前につないだアカウントに戻る。つないでいなければ nil
    func restore() async throws -> String?
    /// ログインの画面を出す。やめたときは nil
    func connect() async throws -> String?
    func disconnect() async
    func events(from: Date, to: Date) async throws -> [CalendarEvent]
}

/// 本物。Google のログインで受け取ったトークンで、端末から Google カレンダーの API を読む。
/// 予定は中継サーバを通らず、Kajiri に保存もしない
@MainActor
final class GoogleCalendarRepository: GoogleCalendarRepositoryProtocol {
    /// 予定を読むのに要る最小の権限
    static let scopes = [
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
        "https://www.googleapis.com/auth/calendar.events.readonly",
    ]

    var isAvailable: Bool {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        return !(clientID ?? "").isEmpty
    }

    func restore() async throws -> String? {
        guard isAvailable, GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            guard Self.hasScopes(user) else { throw GoogleCalendarError.scopeMissing }
            return user.profile?.email ?? ""
        } catch let error as GoogleCalendarError {
            throw error
        } catch {
            throw GoogleCalendarError.notAuthorized
        }
    }

    func connect() async throws -> String? {
        guard isAvailable, let presenter = Self.topViewController() else { throw GoogleCalendarError.requestFailed }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: Self.scopes
            )
            guard Self.hasScopes(result.user) else { throw GoogleCalendarError.scopeMissing }
            return result.user.profile?.email ?? ""
        } catch let error as GIDSignInError where error.code == .canceled {
            return nil
        } catch let error as GoogleCalendarError {
            throw error
        } catch {
            throw GoogleCalendarError.requestFailed
        }
    }

    func disconnect() async {
        // 許可の取り消しに失敗しても（オフラインなど）、この端末からは切る
        try? await GIDSignIn.sharedInstance.disconnect()
        GIDSignIn.sharedInstance.signOut()
    }

    func events(from: Date, to: Date) async throws -> [CalendarEvent] {
        let token = try await accessToken()
        let client = GoogleCalendarClient(token: token)
        let calendars = try await client.calendars().filter(\.isShown)
        var found: [CalendarEvent] = []
        var failures = 0
        for calendar in calendars {
            do {
                found += try await client.events(calendar: calendar, from: from, to: to)
            } catch GoogleCalendarError.notAuthorized {
                throw GoogleCalendarError.notAuthorized
            } catch {
                // 1つ読めなくても、ほかのカレンダーは並べる
                failures += 1
            }
        }
        if !calendars.isEmpty && failures == calendars.count { throw GoogleCalendarError.requestFailed }
        return found
    }

    private func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else { throw GoogleCalendarError.notAuthorized }
        do {
            return try await user.refreshTokensIfNeeded().accessToken.tokenString
        } catch {
            throw GoogleCalendarError.notAuthorized
        }
    }

    private static func hasScopes(_ user: GIDGoogleUser) -> Bool {
        let granted = Set(user.grantedScopes ?? [])
        return scopes.allSatisfy(granted.contains)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    /// ログインの画面から戻ってきたときの URL を渡す
    static func handle(_ url: URL) {
        _ = GIDSignIn.sharedInstance.handle(url)
    }
}

/// Google カレンダーの API を呼ぶところ
private struct GoogleCalendarClient: Sendable {
    let token: String

    func calendars() async throws -> [GoogleCalendarEntry] {
        var calendars: [GoogleCalendarEntry] = []
        var page: String?
        repeat {
            var query = [
                URLQueryItem(name: "maxResults", value: "250"),
                URLQueryItem(name: "fields", value: "items(id,summary,summaryOverride,backgroundColor,selected,hidden),nextPageToken"),
            ]
            if let page { query.append(URLQueryItem(name: "pageToken", value: page)) }
            let list: GoogleCalendarList = try await get(path: "/calendar/v3/users/me/calendarList", query: query)
            calendars += list.items ?? []
            page = list.nextPageToken
        } while page != nil
        return calendars
    }

    func events(calendar: GoogleCalendarEntry, from: Date, to: Date) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        var events: [CalendarEvent] = []
        var page: String?
        repeat {
            var query = [
                URLQueryItem(name: "timeMin", value: formatter.string(from: from)),
                URLQueryItem(name: "timeMax", value: formatter.string(from: to)),
                // くり返しの予定を回ごとに開く
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "2500"),
                URLQueryItem(name: "fields", value: "items(id,status,summary,location,start,end,htmlLink,recurringEventId),nextPageToken"),
            ]
            if let page { query.append(URLQueryItem(name: "pageToken", value: page)) }
            let id = calendar.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? calendar.id
            let list: GoogleEventList = try await get(path: "/calendar/v3/calendars/\(id)/events", query: query)
            events += GoogleEventMapper.events(from: list, calendar: calendar)
            page = list.nextPageToken
        } while page != nil
        return events
    }

    private func get<Answer: Decodable>(path: String, query: [URLQueryItem]) async throws -> Answer {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.percentEncodedPath = path
        components.queryItems = query
        guard let url = components.url else { throw GoogleCalendarError.requestFailed }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GoogleCalendarError.requestFailed
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw GoogleCalendarError.notAuthorized }
        guard (200..<300).contains(status) else { throw GoogleCalendarError.requestFailed }
        do {
            return try JSONDecoder().decode(Answer.self, from: data)
        } catch {
            throw GoogleCalendarError.requestFailed
        }
    }
}

#if DEBUG
/// Preview とテスト用。決まった予定を返す
@MainActor
final class MockGoogleCalendarRepository: GoogleCalendarRepositoryProtocol {
    let isAvailable: Bool
    private let account: String?
    private let stored: [CalendarEvent]
    private let failure: GoogleCalendarError?
    /// やめたときの connect の答えを試すなら nil
    private let connectsAs: String?

    init(isAvailable: Bool, account: String?, connectsAs: String?, events: [CalendarEvent], failure: GoogleCalendarError?) {
        self.isAvailable = isAvailable
        self.account = account
        self.connectsAs = connectsAs
        self.stored = events
        self.failure = failure
    }

    func restore() async throws -> String? { account }
    func connect() async throws -> String? { connectsAs }
    func disconnect() async {}
    func events(from: Date, to: Date) async throws -> [CalendarEvent] {
        if let failure { throw failure }
        return stored
    }
}
#endif
