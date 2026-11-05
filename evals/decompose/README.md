# 分解（kajiriDecompose）のモデル評価

本番と同じプロンプト・JSON の形で、モデルだけを差し替えて流す。数字は [out/summary.md](out/summary.md)。

```bash
cd functions && npm run build && cd ..
export ANTHROPIC_API_KEY=...   # Secret Manager の ANTHROPIC_API_KEY。コミットしない
REPS=2 node evals/decompose/run.mjs claude-opus-5-5:medium claude-sonnet-5-5:medium
node evals/decompose/grade.mjs
```

## 2026-11-05 の結論: 分解は Sonnet 5.5（medium）

- Opus との中身の差は -0.09 点（16 ケースで対応をとった 95%CI -0.24〜+0.06）。この評価では差が見えない
- 代金は約 1/3（$0.045 → $0.016）、応答は 15.9 秒 → 6.8 秒
- Sonnet low は -0.21 点（95%CI -0.32〜-0.09）。代金はほとんど下がらないので使わない
- Haiku は -0.43 点（95%CI -0.56〜-0.31）。安い（$0.0012）が、`moving` のように「申し込む」「出す」の段が抜ける。応答も Sonnet より遅い（9.5 秒）

## この評価の限界

- お題の16件は本物の利用ログではなく、作ったもの
- 採点役は Opus 5.5。モデル名は伏せているが、自分の書き方に点が甘い可能性はある
- 測ったのは分解だけ。下書き（Web 検索あり）・割り直し・準備探し・ふりかえりは未評価
- 代金はプロンプトキャッシュなしの実測（入力 3,723 トークン）
