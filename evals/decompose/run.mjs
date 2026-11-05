// 分解（kajiriDecompose）を、モデルだけ差し替えて流す。プロンプトと JSON の形は本番（functions/lib）と同じものを使う。
// 使い方（functions/ で npm run build のあと）:
//   ANTHROPIC_API_KEY=... node evals/decompose/run.mjs claude-opus-5-5:medium claude-sonnet-5-5:medium claude-haiku-5-5:medium
// 結果: evals/decompose/out/results.jsonl（1行 = 1ケース × 1モデル × 1回）
import { createRequire } from "node:module";
import { readFileSync, mkdirSync, appendFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, "../../functions/package.json"));
const Anthropic = require("@anthropic-ai/sdk").default;
const prompts = require(join(here, "../../functions/lib/prompts.js"));

// 1M トークンあたりのドル（入力 / 出力）。claude-api の models.md より
const PRICE = {
  "claude-fable-5-1": [10, 50],
  "claude-opus-5-5": [4, 20],
  "claude-sonnet-5-5": [2, 10],
  "claude-haiku-5-5": [0.1, 0.5],
};
// Haiku 5.5 はサーバー側のやり直し（fallbacks）が無い
const NO_FALLBACK = new Set(["claude-haiku-5-5"]);

const { today, weekday, cases } = JSON.parse(readFileSync(join(here, "cases.json"), "utf8"));
const reps = Number(process.env.REPS ?? 2);
const variants = process.argv.slice(2).map((v) => {
  const [model, effort] = v.split(":");
  if (!PRICE[model]) throw new Error(`料金表に無いモデル: ${model}`);
  return { model, effort: effort ?? "medium" };
});
if (!variants.length) throw new Error("モデルを1つ以上渡してください（例: claude-sonnet-5-5:medium）");

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY, maxRetries: 2 });
mkdirSync(join(here, "out"), { recursive: true });
const outFile = join(here, "out/results.jsonl");
const done = new Set(
  existsSync(outFile)
    ? readFileSync(outFile, "utf8").trim().split("\n").filter(Boolean).map((l) => {
        const r = JSON.parse(l);
        return `${r.variant}|${r.case_id}|${r.rep}`;
      })
    : [],
);

async function once(variant, c, rep) {
  const key = `${variant.model}:${variant.effort}|${c.id}|${rep}`;
  if (done.has(key)) return;
  const params = {
    model: variant.model,
    max_tokens: 16000,
    system: prompts.decomposeSystemPrompt(),
    messages: [{ role: "user", content: prompts.decomposeUserText({ memo: c.memo, today, weekday, overrun: null }) }],
    output_config: { effort: variant.effort, format: { type: "json_schema", schema: prompts.DECOMPOSE_SCHEMA } },
  };
  if (!NO_FALLBACK.has(variant.model)) {
    params.betas = ["server-side-fallback-2026-07-01"];
    params.fallbacks = "default";
  }
  const started = performance.now();
  let row = { variant: `${variant.model}:${variant.effort}`, case_id: c.id, rep };
  try {
    const res = await client.beta.messages.create(params);
    const ms = Math.round(performance.now() - started);
    const text = res.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    const [pin, pout] = PRICE[variant.model];
    const u = res.usage ?? {};
    const cost = ((u.input_tokens ?? 0) * pin + (u.output_tokens ?? 0) * pout) / 1e6;
    let output = null;
    try { output = JSON.parse(text); } catch { /* 形が崩れていたら null のまま */ }
    row = { ...row, served_model: res.model, stop_reason: res.stop_reason, latency_ms: ms,
            input_tokens: u.input_tokens, output_tokens: u.output_tokens, cost_usd: Number(cost.toFixed(5)), output };
  } catch (e) {
    row = { ...row, error: `${e.status ?? ""} ${e.message ?? e}`.slice(0, 300), latency_ms: Math.round(performance.now() - started) };
  }
  appendFileSync(outFile, JSON.stringify(row) + "\n");
  console.log(row.variant, c.id, rep, row.error ? `ERROR ${row.error}` : `${row.latency_ms}ms $${row.cost_usd}`);
}

// 同時に投げすぎない（モデルごとに 4 本ずつ）
for (const variant of variants) {
  const jobs = [];
  for (let rep = 1; rep <= reps; rep++) for (const c of cases) jobs.push(() => once(variant, c, rep));
  const workers = Array.from({ length: 4 }, async () => { while (jobs.length) await jobs.shift()(); });
  await Promise.all(workers);
}
