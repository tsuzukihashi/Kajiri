import { AppError } from "./errors.ts";

const MAX_MEMO = 4_000;
const MAX_TITLE = 200;

export type DecomposeInput = { memo: string; today: string; weekday: string; overrun: number | null };
export type ResplitInput = { logTitle: string; step: string; postponed: number; today: string };
export type WorkInput = { logTitle: string; step: string; work: string; memo: string; today: string };

function bad(message: string): never {
  throw new AppError("invalid-argument", "bad_request", message);
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function text(v: unknown, name: string, max: number): string {
  if (typeof v !== "string" || v.trim() === "") bad(`${name} が空です`);
  if (v.length > max) bad(`${name} が長すぎます`);
  return v.trim();
}

function day(v: unknown): string {
  if (typeof v !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(v)) bad("today は YYYY-MM-DD で送ってください");
  return v;
}

export function parseDecomposeInput(body: unknown): DecomposeInput {
  if (!isRecord(body)) bad("JSON のオブジェクトを送ってください");
  const overrun = body.overrun;
  return {
    memo: text(body.memo, "memo", MAX_MEMO),
    today: day(body.today),
    weekday: typeof body.weekday === "string" ? body.weekday.slice(0, 8) : "",
    overrun: typeof overrun === "number" && overrun > 0 && overrun < 10 ? overrun : null,
  };
}

export function parseResplitInput(body: unknown): ResplitInput {
  if (!isRecord(body)) bad("JSON のオブジェクトを送ってください");
  const postponed = typeof body.postponed === "number" ? Math.max(0, Math.min(99, Math.floor(body.postponed))) : 0;
  return {
    logTitle: text(body.log_title, "log_title", MAX_TITLE),
    step: text(body.step, "step", MAX_TITLE),
    postponed,
    today: day(body.today),
  };
}

export function parseWorkInput(body: unknown): WorkInput {
  if (!isRecord(body)) bad("JSON のオブジェクトを送ってください");
  return {
    logTitle: text(body.log_title, "log_title", MAX_TITLE),
    step: text(body.step, "step", MAX_TITLE),
    work: text(body.work, "work", MAX_TITLE * 2),
    memo: typeof body.memo === "string" ? body.memo.slice(0, MAX_MEMO) : "",
    today: day(body.today),
  };
}
