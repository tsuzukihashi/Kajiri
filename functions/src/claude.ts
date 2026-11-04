import Anthropic from "@anthropic-ai/sdk";
import { AppError } from "./errors.ts";

/** カジリの頭。分解の質がいちばん大事なので Opus にする */
export const MODEL = "claude-opus-5-5";

/** 安全のための判定で断られたら、サーバー側で別のモデルにやり直してもらう */
const FALLBACK_BETA = "server-side-fallback-2026-07-01";

export type Effort = "low" | "medium" | "high";

/** テストでは偽物の fetch を差し込めるようにする */
export function makeClient(apiKey: string, fetchImpl: typeof fetch | null): Anthropic {
  return new Anthropic(fetchImpl ? { apiKey, fetch: fetchImpl, maxRetries: 0 } : { apiKey });
}

/**
 * structured outputs（output_config.format）で、決まった形の JSON を受け取る。
 * 受け取った文章（ユーザーのタスクの中身）はログに書かない。
 */
export async function callJSON<T>(params: {
  client: Anthropic;
  system: string;
  user: string;
  schema: Record<string, unknown>;
  effort: Effort;
  maxTokens: number;
}): Promise<T> {
  const response = await send(() =>
    params.client.beta.messages.create({
      model: MODEL,
      max_tokens: params.maxTokens,
      betas: [FALLBACK_BETA],
      fallbacks: "default",
      system: params.system,
      messages: [{ role: "user", content: params.user }],
      output_config: { effort: params.effort, format: { type: "json_schema", schema: params.schema } },
    }),
  );
  const text = response.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
  if (!text) throw new AppError("internal", "empty", "カジリの返事が空でした。もう一度お試しください。");
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new AppError("internal", "invalid_json", "カジリの返事の形が正しくありませんでした。");
  }
}

/** Web 検索つきで、ふつうの文章を受け取る（カジリが調べものや下書きをするとき） */
export async function callWithSearch(params: {
  client: Anthropic;
  system: string;
  user: string;
  effort: Effort;
  maxTokens: number;
}): Promise<string> {
  const response = await send(() =>
    params.client.beta.messages.create({
      model: MODEL,
      max_tokens: params.maxTokens,
      betas: [FALLBACK_BETA],
      fallbacks: "default",
      system: params.system,
      messages: [{ role: "user", content: params.user }],
      tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 8 }],
      output_config: { effort: params.effort },
    }),
  );
  const text = response.content
    .flatMap((b) => (b.type === "text" ? [b.text] : []))
    .join("")
    .trim();
  if (!text) throw new AppError("internal", "empty", "カジリの返事が空でした。もう一度お試しください。");
  return text;
}

type BetaMessage = Awaited<ReturnType<Anthropic["beta"]["messages"]["create"]>> & { stop_reason?: string | null };

async function send(request: () => Promise<unknown>): Promise<Extract<BetaMessage, { content: unknown }>> {
  let response: Extract<BetaMessage, { content: unknown }>;
  try {
    response = (await request()) as Extract<BetaMessage, { content: unknown }>;
  } catch (e) {
    throw toAppError(e);
  }
  if (response.stop_reason === "refusal") {
    throw new AppError("failed-precondition", "refused", "この内容は、カジリには分けられませんでした。");
  }
  if (response.stop_reason === "max_tokens") {
    throw new AppError("internal", "truncated", "長すぎて分けきれませんでした。いくつかに分けて投げてみてください。");
  }
  return response;
}

function toAppError(e: unknown): AppError {
  // 中身（タスクの文章）は書かない。状態コードと種類だけ
  if (e instanceof Anthropic.RateLimitError || e instanceof Anthropic.InternalServerError) {
    console.error(`claude_api_error status=${e.status}`);
    return new AppError("unavailable", "upstream_busy", "混み合っています。少し待ってからもう一度お試しください。");
  }
  if (e instanceof Anthropic.APIConnectionError) {
    console.error("claude_api_error connection");
    return new AppError("unavailable", "upstream_unreachable", "カジリにつながりませんでした。少し待ってからもう一度お試しください。");
  }
  if (e instanceof Anthropic.APIError) {
    console.error(`claude_api_error status=${e.status}`);
    return new AppError("internal", "upstream_error", "カジリがうまく動きませんでした。");
  }
  console.error(`claude_api_error unknown name=${e instanceof Error ? e.name : "unknown"}`);
  return new AppError("internal", "upstream_error", "カジリがうまく動きませんでした。");
}
