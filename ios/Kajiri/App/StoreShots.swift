#if DEBUG
import Foundation
import SwiftData

/// App Store のスクリーンショットを撮るとき用（DEBUG ビルドで、起動引数 -storeShots を付けたときだけ）。
/// メモリの中だけのデータベースに見本の丸太と薪を入れ、中継サーバの代わりに決まった答えを返す。
/// ネットにつながないので、何度撮っても同じ絵になる。App Store 版には入らない。
/// 撮る手順は fastlane/Snapfile と KajiriUITests/ScreenshotTests.swift
enum StoreShots {
    /// カジリが作るチェックリストの見本（-storeShot checklist）
    static let checklistSample = """
    【使い方】
    ・見たら □ を ■ に変える
    【1 物干し竿】
    見る場所
    □ 物干し金物をつける位置（室内・ベランダ）
    □ 壁や天井の裏に下地（補強の板）が入っているか
    □ 竿の長さが入る幅があるか
    聞くこと
    □ 金物はいつ、誰がつけるか
    □ 高さは今から変えられるか
    メモ：
    【2 住所変更】
    見る場所
    □ 表札・ポストをつける位置
    聞くこと
    □ 引き渡し日（引っ越し日を決めるため）
    □ 正しい住所の書き方
    メモ：
    """

    /// 前の版のカジリが作っていた、長い手続きの並び（-storeShot procedures）。
    /// 2026-11-08 に実機の iPhone Duo で「ADHD には読めない」と言われた形。画面で読める形にできているかを見る
    static let longProcedureSample = """
    引っ越し日：（ここに日付）
    今の住所と新しい住所は同じ市区町村か：（はい／いいえ）

    【引っ越し前にやる】
    ・転出届（市区町村が変わるときだけ）
    今の役所へ出す。引っ越しの前後14日以内
    ・郵便の転居届
    郵便局の窓口かネットで出す。旧住所あての郵便が1年間新住所に届く（要確認）
    1週間前までに出すと安心（要確認）
    ・電気・ガス・水道
    止める手続きと開ける手続きをする。目安は1週間前まで（要確認）
    ガスを開けるときは本人の立会いが要る（要確認）
    ・インターネット回線
    工事が要ると1か月以上待つこともある。早めに申し込む（要確認）

    【引っ越し後14日以内（役所）】
    ・転入届（市区町村が変わるとき）／転居届（同じ市区町村のとき）
    引っ越しの前後14日以内
    ・マイナンバーカードの住所変更
    転入届と同時にやる。遅れるとカードが使えなくなることがある（要確認）

    【そのあとでよいもの】
    ・運転免許証
    新しい住所の警察署で変える（要確認）
    ・銀行・クレジットカード・携帯電話
    それぞれのアプリかサイトで変える
    """

    /// 2026-11-08 に直した指示で、カジリが実際に作った住所変更の一覧（-storeShot newProcedures。evals/work で作らせた1つ）
    static let shortProcedureSample = """
    引っ越し日：（ここに日付）

    【引っ越しの1か月〜1週間前】
    □ ネット回線の移転を申し込む
    1か月前まで
    □ 電気・ガス・水道の移転を申し込む
    1週間前まで。電話かネット
    □ 郵便局に転居届を出す
    1週間前まで。窓口かe転居

    【市区町村が変わるとき】
    □ 今の役所に転出届を出す
    引っ越しの14日前〜14日後。マイナポータルでも可
    □ 新しい役所に転入届を出す
    住み始めて14日以内

    【同じ市区町村のとき】
    □ 役所に転居届を出す
    住み始めて14日以内

    【引っ越し後】
    □ マイナンバーカードの住所を変える
    転入届・転居届と同時。カードと4桁の暗証番号
    □ 警察署で免許証の住所を変える
    □ 銀行・クレカの住所を変える
    □ スマホ・保険の住所を変える

    ※ 日数は目安。出す前に各窓口の案内で確かめる
    """

    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-storeShots") }

    /// -storeShot focus / handoff / month / weekly / matrix: ホームから直接その画面を開く
    static var shot: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-storeShot"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// -storeShotsState empty: 丸太が1本も無い（今日の「はじめ」）
    /// -storeShotsState kajiri: じぶんの薪を全部明日にまわした（今日の「カジリの番」）
    /// -storeShotsState done: 今日の3本を片づけた（今日の「おわり」）
    static var state: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-storeShotsState"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// 見本データを入れる。state に合わせて、空のままにするか、じぶんの薪を明日にまわす
    @MainActor
    static func prepare(_ context: ModelContext, now: Date) {
        guard state != "empty" else { return }
        seed(context, now: now)
        let steps = (try? context.fetch(FetchDescriptor<Step>())) ?? []
        switch state {
        case "kajiri":
            for step in steps where step.owner == .me && !step.isDone {
                step.notBefore = JapanDate.addingDays(1, to: now)
            }
        case "done":
            for step in TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount).open {
                step.isDone = true
                step.doneAt = now
            }
        default:
            return
        }
        try? context.save()
    }

    static let splitMemo = "確定申告、去年ギリギリで地獄だった。今年は早めにやりたい。医療費の領収書は箱に入ってる"

    @MainActor
    static func seed(_ context: ModelContext, now: Date) {
        let today = JapanDate.startOfDay(now)
        let weekStart = JapanDate.week(containing: now).first ?? today
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
            JapanDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: JapanDate.addingDays(dayOffset, to: weekStart)) ?? now
        }
        func day(_ offset: Int) -> String { JapanDate.dayString(JapanDate.addingDays(offset, to: today)) }
        // 前に撮ったときの「週のふりかえり」と「今日の分が終わった」を残さない（毎回同じ流れで撮る）
        UserDefaults.standard.removeObject(forKey: "weeklyReview-\(JapanDate.dayString(weekStart))")
        UserDefaults.standard.removeObject(forKey: "finishedDay")

        func log(_ title: String, memo: String, deadline: String?, note: String, why: String, comment: String, created: Date, steps: [(StepDTO, (Step) -> Void)]) {
            let log = Log(title: title, memo: memo, deadline: JapanDate.date(day: deadline), deadlineNote: note, why: why, kajiriComment: comment, createdAt: created, sourceEventID: nil)
            context.insert(log)
            for (index, item) in steps.enumerated() {
                let step = Step(order: index * 10, dto: item.0)
                context.insert(step)
                step.log = log
                item.1(step)
            }
        }
        func done(_ date: Date, minutes: Int?) -> (Step) -> Void {
            { step in
                step.isDone = true
                step.doneAt = date
                step.startedAt = date.addingTimeInterval(TimeInterval(-60 * (minutes ?? step.minutes)))
                step.actualMinutes = minutes ?? step.minutes
            }
        }
        func ready(_ title: String, _ body: String) -> (Step) -> Void {
            { step in
                step.workState = .ready
                step.workTitle = title
                step.workBody = body
            }
        }
        let open: (Step) -> Void = { _ in }

        log(
            "年末調整の書類", memo: "年末調整の書類、放置してる。締め切りは会社の掲示だと再来週",
            deadline: day(15), note: "メモの「再来週」から", why: "12月の給料で、払いすぎた分が戻ってくる",
            comment: "封筒を探すところからだな。書き方はこっちでまとめておく。", created: at(0, 21, 10),
            steps: [
                (dto("会社のメールで「年末調整」を検索する", 3, .me, .today, motion: "メールのアプリを開く", work: nil, ask: nil), done(at(2, 8, 40), minutes: 4)),
                (dto("保険料控除証明書の封筒を探す", 10, .me, .today, motion: "郵便物のかごを机に出す", work: nil, ask: nil), open),
                (dto("書き方の要点をまとめる", 3, .kajiri, .handoff, motion: "", work: "年末調整の書き方の要点", ask: nil),
                 ready("年末調整、書くところは3つだけ", """
                 【書く用紙】
                 ・扶養控除等申告書: 去年と変わりがなければ、名前と住所の確認だけ
                 ・保険料控除申告書: 届いた証明書の「申告額」を写す
                 ・基礎控除申告書: 給与だけなら、年収の欄に〇を付ける

                 【手元に出しておくもの】
                 ・生命保険・地震保険の控除証明書（10月ごろにはがきか封筒で届く）
                 ・マイナンバー（会社に出していれば書かなくてよいことが多い）

                 【迷ったら】
                 （ここに、総務の人の名前）さんに「扶養の欄は去年のままでいいですか」と聞けば足ります。
                 """)),
                (dto("扶養の欄が去年のままでいいか、総務に聞く", 3, .other, .handoff, motion: "", work: nil, ask: "会社の総務"), open),
                (dto("記入して、会社に出す", 15, .me, .stock, motion: "用紙とボールペンを並べる", work: nil, ask: nil), open),
            ]
        )
        log(
            "新製品の発表の準備", memo: "今日の17時の新製品の発表。スライドまだ半分",
            deadline: day(0), note: "カレンダーの予定から", why: "本番で、落ち着いて話せる",
            comment: "話す順番はもう決まってる。あとは見出しだけだ。", created: at(3, 7, 50),
            steps: [
                (dto("話す順番を3行で書く", 10, .me, .today, motion: "付箋を1枚とる", work: nil, ask: nil), done(at(4, 8, 55), minutes: 8)),
                (dto("スライドの見出しを3つ書く", 15, .me, .today, motion: "PCを開いて、昨日の資料を開く", work: nil, ask: nil), open),
                (dto("想定される質問を一覧にする", 3, .kajiri, .handoff, motion: "", work: "新製品の発表で聞かれそうな質問と答えの方向", ask: nil),
                 ready("聞かれそうな質問、5つ", """
                 1. いつから使えるのか
                 → 発売日と、先行して触れる場があるか

                 2. 値段はいくらか
                 → 決まっていなければ「来週お知らせします」でよい

                 3. 前のものと何が違うのか
                 → 一番の違いを1つだけ言う（ここに、その1つ）

                 4. 今使っているものはどうなるのか
                 → いつまで支えるか

                 5. 誰に向けたものか
                 → 使う人の顔が浮かぶ一言
                 """)),
                (dto("デモの端末を充電しておく", 2, .me, .today, motion: "充電器を挿す", work: nil, ask: nil), open),
            ]
        )
        log(
            "引っ越し", memo: "引っ越しが来週の火曜。粗大ゴミどうしよう",
            deadline: day(5), note: "メモの「来週の火曜」から", why: "新しい部屋で、最初の週末をゆっくり過ごせる",
            comment: "大物から片づけよう。役所の手続きは調べておいた。", created: at(1, 20, 30),
            steps: [
                (dto("段ボールを10箱注文する", 5, .me, .stock, motion: "通販のアプリを開く", work: nil, ask: nil), done(at(1, 20, 45), minutes: 6)),
                (dto("粗大ゴミの受付に電話する", 10, .me, .today, motion: "区のサイトで番号を出す", work: nil, ask: nil), open),
                (dto("転出届の出し方を調べる", 3, .kajiri, .handoff, motion: "", work: "転出届の出し方と、持っていくもの", ask: nil),
                 ready("転出届は、もう出せる", """
                 【いつ】
                 引っ越す日の14日前から出せるので、今日からでも出せる

                 【どこで】
                 ・いまの区役所の窓口
                 ・マイナンバーカードがあれば、マイナポータルからでも出せる

                 【持っていくもの】
                 ・マイナンバーカードか、免許証
                 ・印鑑（いらない区もある）

                 新しい住所での転入届は、引っ越してから14日以内です。
                 """)),
                (dto("冷蔵庫の中を少しずつ減らす", 5, .me, .stock, motion: "冷凍庫を開ける", work: nil, ask: nil), open),
            ]
        )
        log(
            "部屋の片づけ", memo: "机の上が山になってて何も始められない",
            deadline: nil, note: "", why: "座ったらすぐ始められる机になる",
            comment: "上から1つずつでいい。", created: at(0, 22, 0),
            steps: [
                (dto("机の上の紙を1か所にまとめる", 5, .me, .today, motion: "いちばん上の紙を持つ", work: nil, ask: nil), done(at(1, 21, 10), minutes: 5)),
                (dto("いらない紙を捨てる", 10, .me, .today, motion: "ゴミ袋を広げる", work: nil, ask: nil), done(at(2, 21, 30), minutes: 12)),
                (dto("ケーブルを1本ずつ束ねる", 10, .me, .stock, motion: "輪ゴムを出す", work: nil, ask: nil), done(at(3, 21, 0), minutes: 9)),
                (dto("本を棚に戻す", 5, .me, .stock, motion: "本を3冊持つ", work: nil, ask: nil), done(at(3, 21, 15), minutes: 5)),
            ]
        )
        log(
            "歯医者の予約", memo: "歯が少し痛い。歯医者予約しないと",
            deadline: nil, note: "", why: "痛みを気にせず食べられる",
            comment: "電話より、ネットの予約が早い。", created: at(0, 19, 0),
            steps: [
                (dto("近くの歯医者を地図で探す", 5, .me, .today, motion: "地図のアプリを開く", work: nil, ask: nil), done(at(0, 19, 10), minutes: 6)),
                (dto("ネットで予約をとる", 5, .me, .today, motion: "予約のページを開く", work: nil, ask: nil), done(at(1, 12, 20), minutes: 7)),
            ]
        )
        try? context.save()
    }

    private static func dto(_ title: String, _ minutes: Int, _ owner: StepOwner, _ quadrant: Quadrant, motion: String, work: String?, ask: String?) -> StepDTO {
        StepDTO(title: title, minutes: minutes, owner: owner.rawValue, quadrant: quadrant.rawValue, firstMotion: motion, due: nil, kajiriWork: work, askWho: ask, needsComputer: false)
    }
}

/// スクリーンショット用の中継サーバの代わり。本物と同じ形で、決まった答えを返す
struct StoreShotAPI: KajiriAPIProtocol {
    func decompose(memo: String, today: Date, overrun: Double?) async throws -> DecomposeResult {
        try await Task.sleep(for: .milliseconds(1200))
        return DecomposeResult(
            logTitle: "確定申告",
            deadline: "2027-03-15",
            deadlineNote: "確定申告の一般的な期限",
            why: "3月を、締め切りに追われずに過ごせる",
            steps: [
                StoreShots.dtoForAPI("領収書の箱を机に出す", 2, .me, .today, motion: "クローゼットを開ける", work: nil, ask: nil),
                StoreShots.dtoForAPI("医療費控除になるものを調べる", 3, .kajiri, .handoff, motion: "", work: "医療費控除の対象と、集計のしかた", ask: nil),
                StoreShots.dtoForAPI("源泉徴収票を総務にもらう", 3, .other, .handoff, motion: "", work: nil, ask: "会社の総務"),
                StoreShots.dtoForAPI("領収書を月ごとに輪ゴムでまとめる", 15, .me, .stock, motion: "輪ゴムを12本出す", work: nil, ask: nil),
                StoreShots.dtoForAPI("マイナンバーカードの暗証番号を確かめる", 5, .me, .stock, motion: "カードを財布から出す", work: nil, ask: nil),
                StoreShots.dtoForAPI("e-Tax で申告する", 15, .me, .stock, motion: "PCでe-Taxのページを開く", work: nil, ask: nil),
            ],
            events: [],
            comment: "最初は箱を机に出すだけでいい。中身はそのあとだ。"
        )
    }

    func resplit(logTitle: String, step: String, postponed: Int, today: Date) async throws -> ResplitResult {
        try await Task.sleep(for: .milliseconds(800))
        return ResplitResult(
            steps: [
                StoreShots.dtoForAPI("郵便物のかごを机に出す", 1, .me, .today, motion: "かごを持つ", work: nil, ask: nil),
                StoreShots.dtoForAPI("保険会社の封筒だけ横によける", 2, .me, .today, motion: "封筒を1通とる", work: nil, ask: nil),
            ],
            comment: "これなら手が動くだろ。"
        )
    }

    func work(logTitle: String, step: String, work: String, memo: String, today: Date) async throws -> WorkResult {
        try await Task.sleep(for: .milliseconds(1500))
        return WorkResult(
            title: "医療費控除になるもの・ならないもの",
            body: "【なる】\n・病院・歯医者の支払い\n・薬局で買った治療のための薬\n・通院の電車・バス代\n\n【ならない】\n・健康診断（病気が見つかって治療した場合は、なる）\n・ビタミン剤など、予防や健康のためのもの\n\n1年で10万円を超えた分が控除になります。"
        )
    }

    func prep(events: [PrepEventDTO], today: Date) async throws -> PrepResult {
        try await Task.sleep(for: .milliseconds(1500))
        var picks: [PrepPick] = []
        for event in events {
            if event.title.contains("引っ越し") {
                picks.append(PrepPick(eventID: event.id, reason: "当日までに、粗大ゴミと役所の手続きがある。", memo: "\(event.when) \(event.title)。粗大ゴミと転出届の準備"))
            } else if event.title.contains("結婚記念日") {
                picks.append(PrepPick(eventID: event.id, reason: "お店の予約は、1週間前には埋まりやすい。", memo: "\(event.when) \(event.title)。お店の予約と贈りもの"))
            } else if event.title.contains("1on1") {
                picks.append(PrepPick(eventID: event.id, reason: "話したいことを3つ書いておくと、短く済む。", memo: "\(event.when) \(event.title)。話したいことを書き出す"))
            }
        }
        return PrepResult(picks: picks, comment: picks.isEmpty ? "いまのところ、準備が要りそうな予定はないな。" : "\(picks.count)つ、先にかじっておくと楽なのがある。")
    }

    func weekly(_ request: WeeklyRequestDTO) async throws -> WeeklyResult {
        try await Task.sleep(for: .milliseconds(1500))
        return WeeklyResult(
            good: "机の片づけを、4日に分けて最後までやった。年末調整も、メールを探すところまで動いた。",
            next: "見積もりより少し長くかかる日が多い。来週は、朝の1本目を5分のものにしておく。",
            word: "毎日ひとかじり。それで山は小さくなる。"
        )
    }
}

extension StoreShots {
    static func dtoForAPI(_ title: String, _ minutes: Int, _ owner: StepOwner, _ quadrant: Quadrant, motion: String, work: String?, ask: String?) -> StepDTO {
        dto(title, minutes, owner, quadrant, motion: motion, work: work, ask: ask)
    }
}
#endif
