import FirebaseCore
import FirebaseFunctions
import Foundation

/// 中継サーバ（Firebase Functions）を呼ぶ口。Preview とテストでは偽物を差し込む。
protocol KajiriAPIProtocol: Sendable {
    func decompose(memo: String, today: Date, overrun: Double?) async throws -> DecomposeResult
    func resplit(logTitle: String, step: String, postponed: Int, today: Date) async throws -> ResplitResult
    func work(logTitle: String, step: String, work: String, memo: String, today: Date) async throws -> WorkResult
    func prep(events: [PrepEventDTO], today: Date) async throws -> PrepResult
    func weekly(_ request: WeeklyRequestDTO) async throws -> WeeklyResult
}

enum KajiriAPIError: LocalizedError, Sendable {
    case notConfigured
    case appCheckFailed
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            String(localized: "Firebase の設定がありません。ios/Kajiri/GoogleService-Info.plist を置いてください。")
        case .appCheckFailed:
            String(localized: "アプリの確認に失敗しました。App Store か TestFlight から入れたアプリでお試しください。")
        case let .server(message):
            message
        }
    }
}

/// 本物。Anthropic の API キーはアプリに持たせない。呼び出しには App Check のトークンが自動で付く。
struct KajiriAPI: KajiriAPIProtocol {
    func decompose(memo: String, today: Date, overrun: Double?) async throws -> DecomposeResult {
        struct Body: Encodable, Sendable {
            let memo: String
            let today: String
            let weekday: String
            let overrun: Double?
        }
        let body = Body(memo: memo, today: JapanDate.dayString(today), weekday: JapanDate.weekdaySymbol(today), overrun: overrun)
        return try await call("kajiriDecompose", body, timeout: 180)
    }

    func resplit(logTitle: String, step: String, postponed: Int, today: Date) async throws -> ResplitResult {
        struct Body: Encodable, Sendable {
            let logTitle: String
            let step: String
            let postponed: Int
            let today: String

            enum CodingKeys: String, CodingKey {
                case step, postponed, today
                case logTitle = "log_title"
            }
        }
        return try await call("kajiriResplit", Body(logTitle: logTitle, step: step, postponed: postponed, today: JapanDate.dayString(today)), timeout: 120)
    }

    func work(logTitle: String, step: String, work: String, memo: String, today: Date) async throws -> WorkResult {
        struct Body: Encodable, Sendable {
            let logTitle: String
            let step: String
            let work: String
            let memo: String
            let today: String

            enum CodingKeys: String, CodingKey {
                case step, work, memo, today
                case logTitle = "log_title"
            }
        }
        let body = Body(logTitle: logTitle, step: step, work: work, memo: memo, today: JapanDate.dayString(today))
        return try await call("kajiriWork", body, timeout: 300)
    }

    func prep(events: [PrepEventDTO], today: Date) async throws -> PrepResult {
        struct Body: Encodable, Sendable {
            let today: String
            let events: [PrepEventDTO]
        }
        return try await call("kajiriPrep", Body(today: JapanDate.dayString(today), events: events), timeout: 120)
    }

    func weekly(_ request: WeeklyRequestDTO) async throws -> WeeklyResult {
        try await call("kajiriWeekly", request, timeout: 120)
    }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String,
        _ request: Request,
        timeout: TimeInterval
    ) async throws -> Response {
        guard FirebaseApp.app() != nil else { throw KajiriAPIError.notConfigured }
        var callable: Callable<Request, Response> = Functions.functions(region: FirebaseSetup.region).httpsCallable(name)
        callable.timeoutInterval = timeout
        do {
            return try await callable.call(request)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: error.code) {
            case .unauthenticated?, .permissionDenied?:
                throw KajiriAPIError.appCheckFailed
            case .deadlineExceeded?:
                throw KajiriAPIError.server(message: String(localized: "時間がかかりすぎて止まりました。少し待ってから、もう一度お試しください。"))
            case .unavailable?:
                throw KajiriAPIError.server(message: String(localized: "カジリにつながりませんでした。電波のよい所で、もう一度お試しください。"))
            default:
                // サーバの HttpsError のメッセージ（日本語）がそのまま入っている
                throw KajiriAPIError.server(message: error.localizedDescription)
            }
        } catch let error as NSError where error.domain == NSURLErrorDomain {
            throw KajiriAPIError.server(message: String(localized: "インターネットにつながっていないようです。つながったら、もう一度お試しください。"))
        }
    }
}

#if DEBUG
/// Preview とテスト用。ネットにはつながない
struct MockKajiriAPI: KajiriAPIProtocol {
    let delay: Duration
    let fails: Bool

    func decompose(memo: String, today: Date, overrun: Double?) async throws -> DecomposeResult {
        try await Task.sleep(for: delay)
        if fails { throw KajiriAPIError.server(message: "混み合っています。少し待ってからもう一度お試しください。") }
        return .sampleTax
    }

    func resplit(logTitle: String, step: String, postponed: Int, today: Date) async throws -> ResplitResult {
        try await Task.sleep(for: delay)
        if fails { throw KajiriAPIError.server(message: "混み合っています。") }
        return ResplitResult(
            steps: [
                .sample("カバンから会社の封筒を出す", minutes: 1, owner: .me, quadrant: .today, work: nil),
                .sample("封筒を開けて、用紙の写真を撮る", minutes: 1, owner: .me, quadrant: .today, work: nil),
            ],
            comment: "これなら手が動くだろ。"
        )
    }

    func work(logTitle: String, step: String, work: String, memo: String, today: Date) async throws -> WorkResult {
        try await Task.sleep(for: delay)
        if fails { throw KajiriAPIError.server(message: "混み合っています。") }
        return WorkResult(title: "問い合わせへの返信の下書き", body: "お問い合わせありがとうございます。\n確認して、あらためてご連絡します。\n\n（ここに一言）")
    }

    func prep(events: [PrepEventDTO], today: Date) async throws -> PrepResult {
        try await Task.sleep(for: delay)
        if fails { throw KajiriAPIError.server(message: "混み合っています。") }
        let picks = events.filter { $0.title.contains("発表") || $0.title.contains("引っ越し") }.map {
            PrepPick(eventID: $0.id, reason: "当日までに手を動かすことがありそうだ。", memo: "\($0.when) \($0.title)。準備")
        }
        return PrepResult(picks: picks, comment: picks.isEmpty ? "いまのところ、準備が要りそうな予定はないな。" : "\(picks.count)つ、先にかじっておくと楽なのがある。")
    }
}

extension MockKajiriAPI {
    func weekly(_ request: WeeklyRequestDTO) async throws -> WeeklyResult {
        try await Task.sleep(for: delay)
        if fails { throw KajiriAPIError.server(message: "混み合っています。") }
        return WeeklyResult(
            good: "3回「あとで」にした年末調整を、小さく割り直したら水曜に動き出せた。",
            next: "見積もりより3割長くかかってる。来週は1日2本にしておく。",
            word: "戻ってきたのが、いちばんえらい。"
        )
    }
}
#endif
