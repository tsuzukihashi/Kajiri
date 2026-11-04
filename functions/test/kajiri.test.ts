import { test } from "node:test";
import assert from "node:assert/strict";
import { MODEL, makeClient } from "../src/claude.ts";
import { AppError } from "../src/errors.ts";
import { decompose, prep, resplit, work } from "../src/kajiri.ts";
import { DECOMPOSE_SCHEMA, PREP_SCHEMA, RESPLIT_SCHEMA } from "../src/prompts.ts";
import { parseDecomposeInput, parsePrepInput, parseResplitInput } from "../src/validate.ts";

/** Claude API の代わりに決まった返事を返す fetch。送った中身も控える */
function fakeFetch(response: { status: number; body: unknown }, seen: { body?: any; headers?: Headers }) {
  return (async (_url: unknown, init?: RequestInit) => {
    seen.body = JSON.parse(String(init?.body));
    seen.headers = new Headers(init?.headers);
    return new Response(JSON.stringify(response.body), {
      status: response.status,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

function message(text: string, stopReason: string) {
  return {
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: MODEL,
    content: [{ type: "text", text }],
    stop_reason: stopReason,
    usage: { input_tokens: 1, output_tokens: 1 },
  };
}

const sampleDecompose = {
  log_title: "確定申告",
  deadline: "2027-03-15",
  deadline_note: "一般的な期限",
  why: "春を気持ちよく迎えられる",
  steps: [
    {
      title: "分からないことを3つ書き出す",
      minutes: 5,
      owner: "self",
      quadrant: "stock",
      first_motion: "メモを開く",
      due: null,
      kajiri_work: null,
      ask_who: null,
      needs_computer: false,
    },
  ],
  comment: "まずはここからな。",
};

test("分解: Opus に、決まった形と代わりのモデルの指定を付けて送り、JSON を読む", async () => {
  const seen: { body?: any; headers?: Headers } = {};
  const client = makeClient("test-key", fakeFetch({ status: 200, body: message(JSON.stringify(sampleDecompose), "end_turn") }, seen));
  const result = await decompose({ memo: "確定申告", today: "2026-11-04", weekday: "水", overrun: 1.3 }, client);
  assert.deepEqual(result, sampleDecompose);
  assert.equal(seen.body.model, "claude-opus-5-5");
  assert.equal(seen.body.fallbacks, "default");
  assert.equal(seen.body.output_config.format.type, "json_schema");
  assert.equal(seen.body.output_config.effort, "medium");
  assert.match(seen.headers?.get("anthropic-beta") ?? "", /server-side-fallback-2026-07-01/);
  assert.match(seen.body.messages[0].content, /1\.3 倍/);
});

test("割り直し: 軽い考え方（low）で送る", async () => {
  const seen: { body?: any } = {};
  const body = { steps: sampleDecompose.steps, comment: "もっと小さくした。" };
  const client = makeClient("test-key", fakeFetch({ status: 200, body: message(JSON.stringify(body), "end_turn") }, seen));
  await resplit({ log_title: "年末調整", step: "用紙を出す", postponed: 3, today: "2026-11-04" }, client);
  assert.equal(seen.body.output_config.effort, "low");
});

test("カジリの番: Web 検索を付けて送り、1行目を見出しにする", async () => {
  const seen: { body?: any } = {};
  const client = makeClient(
    "test-key",
    fakeFetch({ status: 200, body: message("# 返信の下書き\nお問い合わせありがとうございます。", "end_turn") }, seen),
  );
  const result = await work(
    { log_title: "問い合わせ", step: "返信を書く", work: "返信の下書き", memo: "", today: "2026-11-04" },
    client,
  );
  assert.deepEqual(result, { title: "返信の下書き", body: "お問い合わせありがとうございます。" });
  assert.equal(seen.body.tools[0].type, "web_search_20260209");
});

test("断られたら、分かる言葉のエラーにする", async () => {
  const client = makeClient("test-key", fakeFetch({ status: 200, body: message("", "refusal") }, {}));
  await assert.rejects(
    decompose({ memo: "x", today: "2026-11-04" }, client),
    (e: unknown) => e instanceof AppError && e.code === "refused",
  );
});

test("混んでいるときは、待ってもらうエラーにする", async () => {
  const client = makeClient(
    "test-key",
    fakeFetch({ status: 429, body: { type: "error", error: { type: "rate_limit_error", message: "slow down" } } }, {}),
  );
  await assert.rejects(
    decompose({ memo: "x", today: "2026-11-04" }, client),
    (e: unknown) => e instanceof AppError && e.kind === "unavailable",
  );
});

test("入力の検査", () => {
  assert.throws(() => parseDecomposeInput({ memo: "", today: "2026-11-04" }), AppError);
  assert.throws(() => parseDecomposeInput({ memo: "x", today: "11/4" }), AppError);
  assert.equal(parseDecomposeInput({ memo: "x", today: "2026-11-04", overrun: 99 }).overrun, null);
  assert.equal(parseResplitInput({ log_title: "a", step: "b", postponed: 2.7, today: "2026-11-04" }).postponed, 2);
});

// structured outputs の制約: すべての object に additionalProperties: false と、全プロパティの required が要る
function assertStrictObjects(schema: unknown, path: string): void {
  if (typeof schema !== "object" || schema === null) return;
  const s = schema as Record<string, unknown>;
  if (s.type === "object") {
    assert.equal(s.additionalProperties, false, `${path} に additionalProperties: false が無い`);
    const props = Object.keys((s.properties as object) ?? {});
    assert.deepEqual([...(s.required as string[])].sort(), props.sort(), `${path} の required が足りない`);
  }
  for (const [k, v] of Object.entries(s)) assertStrictObjects(v, `${path}.${k}`);
}

test("スキーマが structured outputs の制約を守っている", () => {
  assertStrictObjects(DECOMPOSE_SCHEMA, "$");
  assertStrictObjects(RESPLIT_SCHEMA, "$");
});

test("準備: 予定を送り、届いていない id は捨てる", async () => {
  const seen: { body?: any; headers?: Headers } = {};
  const reply = {
    picks: [
      { event_id: "e1", reason: "荷造りがあるな", memo: "12月20日 引っ越し。荷造りの準備" },
      { event_id: "nope", reason: "x", memo: "x" },
    ],
    comment: "1つ見つけた。",
  };
  const client = makeClient("test-key", fakeFetch({ status: 200, body: message(JSON.stringify(reply), "end_turn") }, seen));
  const result = await prep(
    { today: "2026-11-04", events: [{ id: "e1", title: "引っ越し", when: "12/20(日) 終日", location: "" }] },
    client,
  );
  assert.deepEqual(result.picks.map((p) => p.event_id), ["e1"]);
  assert.equal(seen.body.output_config.format.type, "json_schema");
  assert.match(seen.body.messages[0].content, /id=e1 \| 12\/20\(日\) 終日 \| 引っ越し/);
});

test("準備: 予定が空なら断る", () => {
  assert.throws(() => parsePrepInput({ today: "2026-11-04", events: [] }), AppError);
});

test("準備の形: すべての object が additionalProperties:false で、全部が required", () => {
  const item = PREP_SCHEMA.properties.picks.items;
  assert.equal(PREP_SCHEMA.additionalProperties, false);
  assert.equal(item.additionalProperties, false);
  assert.deepEqual([...item.required].sort(), Object.keys(item.properties).sort());
});
