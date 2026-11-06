// メモから予定を読み取る精度を測る。プロンプトと JSON の形は本番（functions/lib）と同じものを使う。
// 予定は確認なしでカレンダーに入るので、「入れてはいけないものを入れた」「日時を間違えた」を重い失敗として数える。
// あわせて evals/decompose/cases.json のメモも流し、予定を足したせいで薪の決まりが崩れていないかを見る。
// 使い方（functions/ で npm run build のあと）:
//   ANTHROPIC_API_KEY=... REPS=2 node evals/events/run.mjs claude-sonnet-5-5:medium
// 結果: evals/events/out/results.jsonl と out/summary.md
import { createRequire } from "node:module";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, "../../functions/package.json"));
const Anthropic = require("@anthropic-ai/sdk").default;
const prompts = require(join(here, "../../functions/lib/prompts.js"));

const { today, weekday, cases } = JSON.parse(readFileSync(join(here, "cases.json"), "utf8"));
const old = JSON.parse(readFileSync(join(here, "../decompose/cases.json"), "utf8"));
const reps = Number(process.env.REPS ?? 2);
const [model, effort] = (process.argv[2] ?? "claude-sonnet-5-5:medium").split(":");
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY, maxRetries: 2 });

async function ask(memo, day, week) {
  const res = await client.beta.messages.create({
    model,
    max_tokens: 16000,
    system: prompts.decomposeSystemPrompt(),
    messages: [{ role: "user", content: prompts.decomposeUserText({ memo, today: day, weekday: week, overrun: null }) }],
    output_config: { effort, format: { type: "json_schema", schema: prompts.DECOMPOSE_SCHEMA } },
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
  });
  return JSON.parse(res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join(""));
}

/** 重い失敗: 入れてはいけない予定を入れた・日時や名前が違う。軽い失敗: 入れるべき予定を入れなかった */
function check(c, o) {
  const wrong = [];
  const missed = [];
  const expected = [...c.events];
  for (const e of o.events) {
    const i = expected.findIndex((x) => e.title.includes(x.has) || x.has.includes(e.title));
    if (i < 0) { wrong.push(`余計: ${e.title} ${e.date} ${e.start_time}`); continue; }
    const [x] = expected.splice(i, 1);
    if (e.date !== x.date || e.start_time !== x.start) wrong.push(`日時: ${e.title} ${e.date} ${e.start_time}（正しくは ${x.date} ${x.start}）`);
    if (x.end && e.end_time !== x.end) wrong.push(`終わり: ${e.end_time}（正しくは ${x.end}）`);
  }
  for (const x of expected) missed.push(`入っていない: ${x.has}`);
  if (c.steps === true && o.steps.length === 0) missed.push("薪が無い");
  if (c.steps === false && o.steps.length > 0) missed.push(`準備の無い予定に薪 ${o.steps.length} 本`);
  return { wrong, missed };
}

const jobs = [];
for (let rep = 0; rep < reps; rep++) {
  for (const c of cases) jobs.push({ kind: "events", c, rep });
  for (const c of old.cases) jobs.push({ kind: "steps", c, rep });
}
const rows = [];
async function worker() {
  for (let job = jobs.shift(); job; job = jobs.shift()) {
    const { kind, c, rep } = job;
    try {
      const o = await ask(c.memo, kind === "events" ? today : old.today, kind === "events" ? weekday : old.weekday);
      if (kind === "events") rows.push({ kind, id: c.id, rep, ...check(c, o), events: o.events, steps: o.steps.length });
      else {
        const bad = [];
        if (o.steps.length < 3 || o.steps.length > 10) bad.push(`本数 ${o.steps.length}`);
        if (o.steps.some((s) => s.minutes < 1 || s.minutes > 15)) bad.push("15分を超える薪");
        rows.push({ kind, id: c.id, rep, bad, memo: c.memo, events: o.events });
      }
    } catch (error) {
      rows.push({ kind, id: c.id, rep, error: String(error.message ?? error) });
    }
  }
}
await Promise.all(Array.from({ length: 6 }, worker));

mkdirSync(join(here, "out"), { recursive: true });
writeFileSync(join(here, "out/results.jsonl"), rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
const ev = rows.filter((r) => r.kind === "events");
const st = rows.filter((r) => r.kind === "steps");
const lines = [
  `# 予定の読み取り（${model}:${effort}、${reps} 回ずつ）`,
  "",
  `- 予定のメモ: ${ev.length} 回`,
  `- 重い失敗（余計・日時違い）: ${ev.filter((r) => r.wrong?.length).length} 回`,
  `- 軽い失敗（入れ忘れ・薪の有無）: ${ev.filter((r) => r.missed?.length).length} 回`,
  `- エラー: ${rows.filter((r) => r.error).length} 回`,
  `- 前からの分解のメモ: ${st.length} 回、薪の決まり違反 ${st.filter((r) => r.bad?.length).length} 回`,
  "",
  "## 失敗",
  ...ev.filter((r) => r.wrong?.length || r.missed?.length || r.error).map((r) => `- ${r.id}#${r.rep}: ${[...(r.wrong ?? []), ...(r.missed ?? []), r.error ?? ""].filter(Boolean).join(" / ")}`),
  ...st.filter((r) => r.bad?.length || r.error).map((r) => `- ${r.id}#${r.rep}: ${[...(r.bad ?? []), r.error ?? ""].filter(Boolean).join(" / ")}`),
  "",
  "## 前からの分解のメモで入った予定（目で見る）",
  ...st.filter((r) => r.events?.length).map((r) => `- ${r.id}#${r.rep}: ${r.events.map((e) => `${e.title} ${e.date} ${e.start_time}`).join(", ")}`),
  "",
];
writeFileSync(join(here, "out/summary.md"), lines.join("\n"));
console.log(lines.join("\n"));
