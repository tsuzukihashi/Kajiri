// カジリの作業（kajiriWork）を、本番と同じプロンプト・同じ呼び方（Web 検索つき）で流し、出てきた文を保存する。
// 長さと形（□ の行の長さ・下に足した行の数・「要確認」の数）を数えて、ADHD の人が読める形になっているかを見る。
// 使い方（functions/ で npm run build のあと）:
//   ANTHROPIC_API_KEY=... node evals/work/run.mjs
//   ONLY=address,email で一部だけ流せる（summary.md はそのケースだけで書き直す）
// 結果: evals/work/out/<case>.txt と evals/work/out/summary.md
import { createRequire } from "node:module";
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, "../../functions/package.json"));
const Anthropic = require("@anthropic-ai/sdk").default;
const prompts = require(join(here, "../../functions/lib/prompts.js"));

const { today, cases } = JSON.parse(readFileSync(join(here, "cases.json"), "utf8"));
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY, maxRetries: 2 });
mkdirSync(join(here, "out"), { recursive: true });

function measure(text) {
  const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
  const checks = lines.filter((l) => l.startsWith("□") || l.startsWith("■"));
  return {
    chars: text.length,
    lines: lines.length,
    checks: checks.length,
    longestCheck: Math.max(0, ...checks.map((l) => l.replace(/^[□■]\s*/, "").length)),
    hedges: (text.match(/要確認/g) ?? []).length,
    notes: lines.filter((l) => l.startsWith("※")).length,
  };
}

const rows = [];
const only = process.env.ONLY?.split(",");
for (const c of cases.filter((c) => !only || only.includes(c.id))) {
  const started = performance.now();
  const response = await client.beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: prompts.workSystemPrompt(),
    messages: [{ role: "user", content: prompts.workUserText({ ...c.input, today }) }],
    tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 8 }],
    output_config: { effort: "medium" },
  });
  const text = response.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("").trim();
  writeFileSync(join(here, "out", `${c.id}.txt`), text + "\n");
  const m = measure(text);
  rows.push({ id: c.id, seconds: ((performance.now() - started) / 1000).toFixed(1), ...m });
  console.log(c.id, JSON.stringify(rows.at(-1)));
}

const header = "| ケース | 秒 | 文字数 | 行数 | □ の数 | いちばん長い □ | 要確認 | ※ の行 |\n|---|---|---|---|---|---|---|---|";
const body = rows.map((r) => `| ${r.id} | ${r.seconds} | ${r.chars} | ${r.lines} | ${r.checks} | ${r.longestCheck} | ${r.hedges} | ${r.notes} |`).join("\n");
writeFileSync(join(here, "out", "summary.md"), `# kajiriWork の出力の長さと形（${today}）\n\n${header}\n${body}\n`);
