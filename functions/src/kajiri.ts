import type Anthropic from "@anthropic-ai/sdk";
import { callJSON, callWithSearch } from "./claude.ts";
import {
  DECOMPOSE_SCHEMA,
  PREP_SCHEMA,
  RESPLIT_SCHEMA,
  WEEKLY_SCHEMA,
  decomposeSystemPrompt,
  decomposeUserText,
  prepSystemPrompt,
  prepUserText,
  resplitSystemPrompt,
  resplitUserText,
  weeklySystemPrompt,
  weeklyUserText,
  workSystemPrompt,
  workUserText,
} from "./prompts.ts";
import { parseDecomposeInput, parsePrepInput, parseResplitInput, parseWeeklyInput, parseWorkInput } from "./validate.ts";

/** 雑なメモを、1本の丸太と薪に分ける */
export async function decompose(data: unknown, client: Anthropic): Promise<unknown> {
  const input = parseDecomposeInput(data);
  return callJSON({
    client,
    system: decomposeSystemPrompt(),
    user: decomposeUserText(input),
    schema: DECOMPOSE_SCHEMA,
    effort: "medium",
    maxTokens: 16_000,
  });
}

/** 後回しにされた一歩を、もっと小さく割り直す */
export async function resplit(data: unknown, client: Anthropic): Promise<unknown> {
  const input = parseResplitInput(data);
  return callJSON({
    client,
    system: resplitSystemPrompt(),
    user: resplitUserText(input),
    schema: RESPLIT_SCHEMA,
    effort: "low",
    maxTokens: 8_000,
  });
}

/** カジリの番の一歩（下書き・調べもの・一覧）を片づける。1行目が見出し、2行目からが中身 */
export async function work(data: unknown, client: Anthropic): Promise<{ title: string; body: string }> {
  const input = parseWorkInput(data);
  const text = await callWithSearch({
    client,
    system: workSystemPrompt(),
    user: workUserText(input),
    effort: "medium",
    maxTokens: 16_000,
  });
  const [first, ...rest] = text.split("\n");
  const title = (first ?? "").replace(/^#+\s*/, "").trim();
  return { title: title || input.work, body: rest.join("\n").trim() || text };
}

/** カレンダーの予定から、当日までに準備が要りそうなものを選ぶ */
export async function prep(data: unknown, client: Anthropic): Promise<{ picks: { event_id: string; reason: string; memo: string }[]; comment: string }> {
  const input = parsePrepInput(data);
  const result = await callJSON<{ picks: { event_id: string; reason: string; memo: string }[]; comment: string }>({
    client,
    system: prepSystemPrompt(),
    user: prepUserText(input),
    schema: PREP_SCHEMA,
    effort: "low",
    maxTokens: 8_000,
  });
  // 届いていない id を返してきたら捨てる（アプリ側で予定と結び付けられない）
  const ids = new Set(input.events.map((e) => e.id));
  return { picks: result.picks.filter((p) => ids.has(p.event_id)).slice(0, 5), comment: result.comment };
}

/** 1週間の記録から、よかったところ・次の一歩・今日のひとことを書く */
export async function weekly(data: unknown, client: Anthropic): Promise<unknown> {
  const input = parseWeeklyInput(data);
  return callJSON({
    client,
    system: weeklySystemPrompt(),
    user: weeklyUserText(input),
    schema: WEEKLY_SCHEMA,
    effort: "low",
    maxTokens: 4_000,
  });
}
