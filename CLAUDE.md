# Kajiri 開発規約

ADHD 気質の人のためのタスクアプリ。テーマは「後回しにするのはタスクが大きいから。要素に分解して小さくすれば達成できる」。
ビーバーのカジリ（= Claude）が、雑に投げた大きなタスク（丸太）を、すぐ手が動く一歩（薪）にかじり、誰がやるか（じぶん／カジリ／仲間／待ち）と4象限を決める。
Built with Claude: Japan 2026（締切 11/10 14:00）の提出作品で、**リポジトリは公開する**。

作業を始める前に `docs/HANDOFF.md`（今の状態・この先の予定）を読む。

## 🚨 公開リポジトリであることを忘れない

- **API キーやトークンをコードに書かない。**
  - Anthropic の API キー: Firebase の Secret Manager（`ANTHROPIC_API_KEY`）。キーを入れるコマンドは Claude がターミナルのタブで打ち込み、本人には「`? Enter a value for ANTHROPIC_API_KEY` と出たら貼る」とだけ頼む
  - Firebase の設定: `ios/Kajiri/GoogleService-Info.plist`（.gitignore 済み）。Firebase の API（`iosApps/{id}/config`）で取れる
  - 開発チーム ID: `ios/Config/Local.xcconfig`（.gitignore 済み）
  - App Check のデバッグトークン: Firebase にだけ登録する。リポジトリに書かない
- 秘密が入りそうになったら `scripts/check_secrets.py` が止める（Claude Code のフックと git の pre-commit）
- 有料の素材・他人の画像を入れない。カジリの絵は ChatGPT の Image で作った自作

## 🚨 カジリの絵

- 参照画像は `TsuzuKit/.playwright-mcp/kajiri/kajiri_ref.png`（絵本の水彩・色鉛筆の線の案 E）
- 新しいポーズは、**必ずこの1枚を添付して「編集して」と頼む**（skill `chatgpt-image-assets`）。「さっきと同じで」は使わない
- 背景は `TsuzuKit/.playwright-mcp/kajiri/cutout.py` で抜く（白を差し引くので、黒い地でも白いふちが残らない）

## 🚨 見た目

- 骨組みは AnyPlanner（大きな日付・週の帯・時間の線・空き時間の箱・下からのぞくシート・上が黒い追加シート）を下敷きにしている
- 地は冷たい薄いグレー、文字はほぼ黒、差し色は琥珀色（#F5B83D）1色だけ。`Presentation/Common/Theme.swift`
- カジリの口調は、落ち着いた職人の相棒。褒めちぎらない・責めない・急かさない・命令しない。期限は情報として伝える

## 構成

```
ios/        SwiftUI + SwiftData（XcodeGen の project.yml から生成）
functions/  Firebase Functions の中継サーバ（App Check 必須、公式 SDK で Claude API を呼ぶ）
scripts/    秘密チェック
```

- Firebase プロジェクトは `otayori-tsuzukit` を共用している（Blaze・App Check・キー・組織ポリシーの対応が済んでいるため）。関数は codebase `kajiri` で分けてあり、`npm run deploy` は Kajiri の関数だけを出す
- Claude の呼び出しはすべて `functions/` を通す。アプリから Anthropic API を直接呼ばない
- Functions は `onCall` で `enforceAppCheck: true` を外さない
- モデルは、分解が `claude-sonnet-5-5`、それ以外が `claude-opus-5-5`（`functions/src/claude.ts`）。モデルを変えるときは `evals/` で精度・代金・速さを測ってから決める。`fallbacks: "default"`（安全の判定で断られたら別のモデルでやり直す）を付けている
- iOS 26、Swift 6（strict concurrency）。MVVM + UseCase。SwiftData の都合で UseCase は MainActor
- 画面の文字は日本語をキーにして String Catalog で訳す
- 予定は確認なしでカレンダーに入る。分解の指示（`DECOMPOSE_SCHEMA`・`decomposeSystemPrompt`）を変えたら `evals/events/` を流し、余計な予定や日時違いが増えていないかを見てから出す

## 🚨 課金と費用の上限が決まるまで、App Store の審査に出さない【2026-11-05】

「問題なかったら公開して」を App Store 提出だと決めつけ、課金プランも Claude の呼び出しの上限も無いまま 1.0.0 を審査に出した（承認後に自動公開の設定）。
- 審査に出す前に、課金プラン（または無料で出す判断）と、Claude API の費用の上限（回数制限など）を本人と決める
- 「公開」の意味が取れないときは、どれのことか1問だけ聞く
- 審査に出すときは、承認後の公開を MANUAL にする
