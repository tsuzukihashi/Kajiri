// run.mjs の結果を採点する。
// 1. 決まりのチェック（プログラム）: 形・本数・分数・最初の1本・owner と付随の欄・締め切りを作っていないか・複数の丸太の扱い
// 2. 中身の採点（Claude が採点役）: どのモデルの答えかは伏せて、5つの観点を 1〜5 で付ける
// 使い方: ANTHROPIC_API_KEY=... node evals/decompose/grade.mjs
// 結果: out/graded.jsonl と out/summary.md
import { createRequire } from "node:module";
import { readFileSync, writeFileSync, existsSync, appendFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, "../../functions/package.json"));
const Anthropic = require("@anthropic-ai/sdk").default;

const JUDGE = process.env.JUDGE_MODEL ?? "claude-opus-5-5";
const JUDGE_PRICE = { "claude-opus-5-5": [4, 20], "claude-fable-5-1": [10, 50] }[JUDGE];
const { today, cases } = JSON.parse(readFileSync(join(here, "cases.json"), "utf8"));
const byId = Object.fromEntries(cases.map((c) => [c.id, c]));
const rows = readFileSync(join(here, "out/results.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l));
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY, maxRetries: 2 });

function rules(row) {
  const c = byId[row.case_id];
  const o = row.output;
  const fails = [];
  if (!o) return { ok: false, fails: [row.error ? "エラー" : "JSON が読めない"] };
  const steps = o.steps ?? [];
  if (steps.length < 3 || steps.length > 10) fails.push(`本数 ${steps.length}`);
  if (steps.some((s) => s.minutes < 1 || s.minutes > 15)) fails.push("15分を超える薪");
  if (steps[0] && steps[0].minutes > 5) fails.push(`最初の1本が ${steps[0].minutes} 分`);
  for (const s of steps) {
    if (s.owner === "kajiri" && !s.kajiri_work) fails.push("カジリの番なのに作るものが無い");
    if (s.owner === "other" && !s.ask_who) fails.push("頼む相手が無い");
  }
  if (c.deadline === null && o.deadline !== null) fails.push(`原文に無い締め切りを作った（${o.deadline}）`);
  if (typeof c.deadline === "string" && c.deadline !== "any" && o.deadline !== c.deadline) fails.push(`締め切り ${o.deadline}（正しくは ${c.deadline}）`);
  if (c.multi && !/別|ほか|他/.test(o.comment ?? "")) fails.push("ほかの丸太を別に投げてと言っていない");
  return { ok: fails.length === 0, fails: [...new Set(fails)] };
}

const RUBRIC = `あなたは、ADHD 気質の人のためのタスクアプリ「カジリ」の出力を採点する。
アプリは、雑なメモを「すぐ手が動く一歩（薪）」に分ける。各観点を 1〜5 の整数で付ける（5 が最良）。どのモデルの出力かは知らされない。長さや丁寧さではなく、下の基準だけで付ける。

- actionable: 各一歩が、考えなくてもすぐ始められる具体的な動きか。最初の1本がとても小さいか。first_motion が体の動きになっているか
- complete: 一歩を順にやれば、メモの用事が終わりまで進むか。抜けている大事な段取りが無いか
- owner: 誰がやるか（self / kajiri=AI が下書き・Web で調べもの / other=人に頼む / wait=届くのを待つ）の割り振りが妥当か。Web で済む調べものは kajiri か。kajiri の番が本人の答えを待たずに作れるものか
- faithful: メモに無い事実・日付・固有名詞を作っていないか。分からないことを、調べる一歩や空欄にしているか
- voice: comment と why が「落ち着いた職人の相棒」の口調か。褒めちぎらない・責めない・急かさない・命令しない

最後に、この出力をそのまま相棒（ADHD 気質のユーザー）に見せてよいか、一言の理由を書く。`;

const JUDGE_SCHEMA = {
  type: "object",
  properties: {
    actionable: { type: "integer" }, complete: { type: "integer" }, owner: { type: "integer" },
    faithful: { type: "integer" }, voice: { type: "integer" }, reason: { type: "string" },
  },
  required: ["actionable", "complete", "owner", "faithful", "voice", "reason"],
  additionalProperties: false,
};

async function judge(row) {
  const c = byId[row.case_id];
  const res = await client.messages.create({
    model: JUDGE,
    max_tokens: 6000,
    system: RUBRIC,
    messages: [{ role: "user", content: `今日: ${today}\n\nメモ:\n<memo>\n${c.memo}\n</memo>\n\n出力:\n<output>\n${JSON.stringify(row.output, null, 2)}\n</output>` }],
    output_config: { effort: "medium", format: { type: "json_schema", schema: JUDGE_SCHEMA } },
  });
  const text = res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
  const u = res.usage ?? {};
  return { ...JSON.parse(text), judge_cost: ((u.input_tokens ?? 0) * JUDGE_PRICE[0] + (u.output_tokens ?? 0) * JUDGE_PRICE[1]) / 1e6 };
}

const gradedFile = join(here, "out/graded.jsonl");
const graded = existsSync(gradedFile)
  ? readFileSync(gradedFile, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l))
  : [];
const seen = new Set(graded.map((g) => `${g.variant}|${g.case_id}|${g.rep}`));
const todo = rows.filter((r) => !seen.has(`${r.variant}|${r.case_id}|${r.rep}`));
const workers = Array.from({ length: 4 }, async () => {
  while (todo.length) {
    const row = todo.shift();
    const g = { variant: row.variant, case_id: row.case_id, rep: row.rep, rules: rules(row) };
    if (row.output) {
      try { g.judge = await judge(row); } catch (e) { g.judge_error = String(e.message ?? e).slice(0, 200); }
    }
    appendFileSync(gradedFile, JSON.stringify(g) + "\n");
    graded.push(g);
    console.log(g.variant, g.case_id, g.rep, g.rules.ok ? "決まりOK" : g.rules.fails.join("・"), g.judge ? `中身 ${["actionable","complete","owner","faithful","voice"].map((k) => g.judge[k]).join("/")}` : "");
  }
});
await Promise.all(workers);

// まとめ
const variants = [...new Set(rows.map((r) => r.variant))];
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : NaN);
const pct = (xs, p) => { const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };
const lines = ["| モデル | 決まりを守れた | 中身（5点満点の平均） | 速さ（中央値 / 遅い1割） | 1回の代金 | 1,000回の代金 |", "|---|---|---|---|---|---|"];
for (const v of variants) {
  const rs = rows.filter((r) => r.variant === v);
  const gs = graded.filter((g) => g.variant === v);
  const ok = gs.filter((g) => g.rules.ok).length;
  const js = gs.filter((g) => g.judge).map((g) => g.judge);
  const score = mean(js.map((j) => mean([j.actionable, j.complete, j.owner, j.faithful, j.voice])));
  const lat = rs.filter((r) => r.latency_ms && !r.error).map((r) => r.latency_ms / 1000);
  const cost = mean(rs.filter((r) => r.cost_usd != null).map((r) => r.cost_usd));
  lines.push(`| ${v} | ${ok}/${gs.length} | ${score.toFixed(2)} | ${pct(lat, 0.5)?.toFixed(1)}秒 / ${pct(lat, 0.9)?.toFixed(1)}秒 | $${cost.toFixed(4)} | $${(cost * 1000).toFixed(1)} |`);
}
const perAxis = ["| モデル | すぐ動ける | 終わりまで | 誰がやる | 作らない | 口調 |", "|---|---|---|---|---|---|"];
for (const v of variants) {
  const js = graded.filter((g) => g.variant === v && g.judge).map((g) => g.judge);
  perAxis.push(`| ${v} | ${["actionable", "complete", "owner", "faithful", "voice"].map((k) => mean(js.map((j) => j[k])).toFixed(2)).join(" | ")} |`);
}
const fails = ["| モデル | 決まりを外したところ |", "|---|---|"];
for (const v of variants) {
  const f = graded.filter((g) => g.variant === v && !g.rules.ok).map((g) => `${g.case_id}#${g.rep}: ${g.rules.fails.join("・")}`);
  fails.push(`| ${v} | ${f.join("<br>") || "なし"} |`);
}
const judgeCost = graded.reduce((a, g) => a + (g.judge?.judge_cost ?? 0), 0);
const runCost = rows.reduce((a, r) => a + (r.cost_usd ?? 0), 0);
writeFileSync(join(here, "out/summary.md"), [
  `# 分解の評価（${today}・${cases.length}ケース × ${Math.max(...rows.map((r) => r.rep))}回）`, "",
  lines.join("\n"), "", "## 観点ごとの点（採点役: " + JUDGE + "）", "", perAxis.join("\n"), "",
  "## 決まりを外したところ", "", fails.join("\n"), "",
  `かかった代金: 生成 $${runCost.toFixed(2)} ＋ 採点 $${judgeCost.toFixed(2)}`, "",
].join("\n"));
console.log(readFileSync(join(here, "out/summary.md"), "utf8"));
