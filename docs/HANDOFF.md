# 引き継ぎメモ（2026-11-04 時点）

まずこれと `CLAUDE.md` を読む。締切は **11/10（火）14:00**。

## 決まっていること

- 名前: Kajiri（カジリ）。App Store の名前の案は「カジリ - 先延ばしを止めるタスク管理・ToDoリスト」
- テーマ: 後回しにするのはタスクが大きいから。要素に分解して小さくすれば達成できる
- 攻めるところ: 要素分解（カジリが勝手に割る）と移譲（カジリがやる・人に頼む・待ち）。4象限も使う
- 比べた相手: AnyPlanner（分解も移譲もできない）、Splitti（AI で分けるアプリ。中身はまだ見ていない）
- デザイン: Claude Design のキャンバス https://claude.ai/artifact/TqJw5ZQctzequ9EpJfaFZJ （10画面）
- 参考にした考え方: laprasdrum さんの note（後回しの理由をフォッグの3つで分けて割り直す、見積もりと実績で今日の量、週1で褒める 等）

## できていること

- `functions/`: `kajiriDecompose`（メモ → 丸太と薪）、`kajiriResplit`（あとで → もっと小さく）、`kajiriWork`（カジリの番の下書き・調べもの。Web 検索あり）、`kajiriPrep`（予定から、準備が要りそうなものを選ぶ）。テスト 10 件。本番にデプロイ済み（App Check なしは 401）
- Firebase: `otayori-tsuzukit` に iOS アプリ com.tsuzukit.Kajiri を足した。App Attest とシミュレータ用のデバッグトークン（Claude Code のシミュレータ）を登録済み
- `ios/`: ホーム（まだ何もない／今日の薪がある／今日の分が終わった の3モード）、丸太を投げる → 分解の結果、この1本だけ、あとで（まだ大きい・いまじゃない・頼みたい・やらなくていい）、カジリから受け取る、丸太の一覧、4象限。ビルドは通る。**画面はまだ動かして見ていない**
- カレンダー（2026-11-04）: iPhone のカレンダーを EventKit でまとめて読む（Google・iCloud・Outlook など設定に入れたもの全部。Kajiri には写さない）
  - ホームの1日の線: 予定と、予定のすき間（空き時間）を時刻順に並べ、今日の薪を入る大きさのすき間に置く（`Domain/DayPlanner.swift`）。週の帯で日を選べる。終日の予定と丸太の締め切りは札で上に出す
  - 大きな日付を押すと月の表示（`Presentation/Month/`）。予定を足す・直すは Apple 標準の画面（EKEventEditViewController）
  - 予定を押すと、その予定の画面（準備をかじってもらう → 丸太を投げるシートにメモの下書きが入る・予定を直す）。丸太は `Log.sourceEventID` で予定と結ぶ
  - 月の表示の「カジリに見てもらう」: 押したときだけ、この先2週間の予定の名前・日時・場所を送り、準備が要りそうな予定を選んでもらう
  - 丸太の一覧から、締め切りを iPhone のカレンダーに終日の予定として入れられる（`Log.deadlineEventID`）

## 2026-11-04 夜に足したもの・確かめたこと

- シミュレータで通しを確かめた（本番の中継サーバに App Check のデバッグトークンでつないで）: 投げる → 分解 → この1本だけ → あとで（まだ大きい → 割り直し）→ できた → 今日の分が終わった。カジリの下書き、月の表示、予定の画面、標準の編集画面、予定から準備を投げる、準備が要りそうな予定を探す、週のふりかえり、4象限
- 通しで見つけて直したもの: 下書きに Markdown が出る、分解の結果のボタンが薪に重なる、「あとで」が全画面、最後の1本を片づけると開いていた画面が真っ白で残る（モードを閉じきってから入れかえる）ほか。コミットに書いた
- 共有シート（KajiriShare）: 共有された文章・URL を App Group（group.com.tsuzukit.Kajiri）に置き、アプリを開いたときに投げるシートへ入れる。Safari から投げてシミュレータで確かめた
- 週のふりかえり（kajiriWeekly）、通知（朝の1本目・締め切りの前の日・月曜）、Siri・アクションボタン（App Intents）、アプリアイコン、README、単体テスト 20 件
- tsuzukit.com/kajiri/ に LP・プライバシーポリシー・利用規約を置いた（tsuzukit.com のリポジトリ）。アプリの丸太の一覧と月の表示のいちばん下からリンク
- ストアのスクショ: `ios/KajiriUITests/ScreenshotTests.swift` が `-storeShots`（メモリの中の見本データと決まった答えの中継サーバ。`App/StoreShots.swift`）で6枚撮る。fastlane snapshot は 2.240.0 でシミュレータ一覧を読むところで落ちるので、`xcodebuild test -only-testing:KajiriUITests/ScreenshotTests` を直接当て、`~/Library/Caches/tools.fastlane/screenshots` から `fastlane/screenshots/ja` へ写して `fastlane frameit silver`（LANG=en_US.UTF-8）。撮る前に `simctl status_bar override --time 10:15`（アプリの時計と合わせる）
- DEBUG だけの起動引数: `-seedDemo`（見本の予定）・`-demoHour 10`（時計をずらす）・`-demoThrow "メモ"`（デモ動画を撮るときに使う）

## 2026-11-07 に足したもの

- Google カレンダーを Kajiri の中でつなぐ（`GoogleCalendarRepository`）: コードは main にある。Google 側は共用プロジェクト `otayori-tsuzukit` の Google Auth Platform（アプリ名 Kajiri・外部、iOS クライアント「Kajiri iOS」だけ、Calendar API 有効）。クライアント ID は gitignore の `ios/Config/Local.xcconfig` に入れた
  - 2026-11-07: シミュレータで `ryo.tsuzukihashi@tsuzukit.com` でログインし、許可の画面に権限2つが出て、許可すると Google の予定（祝日など）が月の表示に並ぶところまで確かめた。実機ではまだ
  - 2026-11-07: **公開ステータスを本番環境にし、Google の確認を申請した（審査中）**。確認が済むまでは誰でもつなげるが「未確認のアプリ」の画面が出て、許可は累計100人まで。Google の案内では最大10日ほど（別のページでは数か月とも）
  - 申請に使ったもの: ブランディング（ホーム https://tsuzukit.com/kajiri/・プライバシー・規約、承認済みドメイン tsuzukit.com、ロゴ）、Search Console の持ち主確認（tsuzukit.com/googled2839926c051d96a.html。消さない）、デモ動画 https://www.youtube.com/watch?v=wj5qhT3i3tQ（TsuzuKit チャンネル・限定公開。英語の字幕つき）、スコープの理由（英文）
  - 動画の作り直しが要るときは、シミュレータの言語を英語にして録画し、字幕を重ねる（スクリプトは残していない。手順はこの行のとおり）
  - `Local.xcconfig` が無いビルド（CI や他の人の環境）では、つなぐカードの押すところが動かない
- 予定もカジリが入れる: `kajiriDecompose` が `events` を返す → `CalendarUseCase.place` が確認なしで iPhone のカレンダーに入れる → `PlacedEventsCard` に「戻す」。同じ予定があれば入れない。「書き直す」は入れた予定も消す。予定から投げたメモでは入れない。`steps` が空なら丸太を作らず「閉じる」だけ出す
  - 書き込み先は iPhone の既定のカレンダーだけ。Google へ直接は書かない（読み取りの権限のまま）
  - `functions` はデプロイ済み（2026-11-07）。ただし TestFlight の 1.0.0 (2) は予定を入れるコードを持たないので、試すには新しいビルドが要る
  - 精度（2026-11-07、`evals/events/run.mjs`、`claude-sonnet-5-5:medium`、2 回ずつ）: 予定のメモ 48 回で、余計な予定・日時違いは 0 回、入れ忘れは 1 回（「今週の日曜 友達の結婚式」で予定に入らず薪になった）。前からの分解のメモ 32 回で薪の決まり違反は 0 回。「来週の火曜にプレゼン」はその日の終日の予定に入る
  - 画面はまだ動かして見ていない

## まだのこと

- [x] Google カレンダーのアプリだけを使い、iPhone の設定に Google アカウントを入れていない人には予定が見えない → 月の表示のいちばん下（Kajiri について の上）に「Google カレンダーの予定が出ないとき」を置いた（押すと足し方が開く。`Presentation/Calendar/MissingEventsHelp.swift`）。シミュレータで開いた形まで見た
- [x] TestFlight: ASC のアプリ（App ID 6830898965）を作り、1.0.0 (1) を上げた。内部テスト develop（全ビルド）に本人を招待済み（2026-11-05）。1.0.0 (2) で「Google カレンダーの予定が出ないとき」を足して上げ直した。次のビルドは CURRENT_PROJECT_VERSION を上げてから
- [ ] 実機（App Attest）で中継サーバにつながるかを、TestFlight 版で確かめる
- [x] 分解を Sonnet 5.5 に切りかえて本番にデプロイした（2026-11-05）。本番で実際に分解を呼ぶ確認は、TestFlight の実機でまだ
- [ ] 下書き・割り直し・準備探し・ふりかえりのモデル評価（`evals/decompose/` と同じやり方）
- [ ] 課金プランと、1台あたりの回数制限・全体の予算の上限を決めて入れる（中継サーバに今は無い）
- [ ] デモ動画: 素材は docs/demo/（.gitignore 済み）。kajiri_demo_cut.mp4 は 2分20秒（投げる → 分ける → 通知の許可 → カジリが並行で進める → 1本片づける → 下書き → 月の表示で準備を探す。待ち時間は速めてある）。字幕を入れて最後に名前の札（4秒）を足したものが kajiri_demo.mp4（2分25秒）。ナレーション入りが kajiri_demo_voice.mp4（VOICEVOX 雀松朱司。声の高さと息の少なさで選んだ。アクセントは OJAD に合わせ、ダウンステップを入れた。終わりの札にクレジットあり）。こちらは音を聴けていないので、使うかどうかは本人が聴いて決める。音楽はまだ
- [x] 公開リポジトリ: https://github.com/tsuzukihashi/Kajiri（2026-11-05。公開の前に履歴まで鍵・トークン・Firebase の設定・チーム ID・個人のメールが無いことを確かめた）
- [ ] App Store の審査: 2026-11-05 に出したが、課金と回数制限が決まっていなかったので取り下げた（1.0.0 は DEVELOPER_REJECTED）。メタデータ・無料・175地域・年齢制限・カテゴリ（仕事効率化）・App プライバシー（その他のユーザーコンテンツ／アプリの機能／ユーザーに関連付けない）・審査メモ（store/ios/review_notes.txt）・画面録画を入れた
- [ ] プロダクトページのヘッダと検索結果の絵（任意の枠。1.0 が承認されたあと、アセットライブラリから単独で出す）
- [ ] ハッカソンの提出（11/10 14:00）
