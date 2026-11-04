import { AppError } from "./errors.ts";

const MAX_MEMO = 4_000;
const MAX_TITLE = 200;

export type DecomposeInput = { memo: string; today: string; weekday: string; overrun: number | null };
export type ResplitInput = { logTitle: string; step: string; postponed: number; today: string };
export type WorkInput = { logTitle: string; step: string; work: string; memo: string; today: string };
export type PrepEvent = { id: string; title: string; when: string; location: string };
export type PrepInput = { today: string; events: PrepEvent[] };

const MAX_EVENTS = 60;

export type WeeklyInput = {
  week: string;
  days: number[];
  done: { title: string; log: string }[];
  postponed: { title: string; count: number }[];
  kajiriDone: number;
  resplit: number;
  overrun: number | null;
  thrown: number;
};

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

export function parsePrepInput(body: unknown): PrepInput {
  if (!isRecord(body)) bad("JSON のオブジェクトを送ってください");
  const events = body.events;
  if (!Array.isArray(events) || events.length === 0) bad("events が空です");
  if (events.length > MAX_EVENTS) bad("events が多すぎます");
  return {
    today: day(body.today),
    events: events.map((e): PrepEvent => {
      if (!isRecord(e)) bad("events の中身がオブジェクトではありません");
      return {
        id: text(e.id, "id", MAX_TITLE),
        title: text(e.title, "title", MAX_TITLE),
        when: text(e.when, "when", 60),
        location: typeof e.location === "string" ? e.location.slice(0, MAX_TITLE) : "",
      };
    }),
  };
}

function count(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? Math.max(0, Math.min(999, Math.floor(v))) : 0;
}

export function parseWeeklyInput(body: unknown): WeeklyInput {
  if (!isRecord(body)) bad("JSON のオブジェクトを送ってください");
  const days = Array.isArray(body.days) ? body.days.slice(0, 7).map(count) : [];
  if (days.length !== 7) bad("days は7日分を送ってください");
  const done = Array.isArray(body.done) ? body.done.slice(0, 60) : [];
  const postponed = Array.isArray(body.postponed) ? body.postponed.slice(0, 20) : [];
  const overrun = body.overrun;
  return {
    week: text(body.week, "week", 40),
    days,
    done: done.map((d) => {
      if (!isRecord(d)) bad("done の中身がオブジェクトではありません");
      return { title: text(d.title, "title", MAX_TITLE), log: typeof d.log === "string" ? d.log.slice(0, MAX_TITLE) : "" };
    }),
    postponed: postponed.map((p) => {
      if (!isRecord(p)) bad("postponed の中身がオブジェクトではありません");
      return { title: text(p.title, "title", MAX_TITLE), count: count(p.count) };
    }),
    kajiriDone: count(body.kajiri_done),
    resplit: count(body.resplit),
    overrun: typeof overrun === "number" && overrun > 0 && overrun < 10 ? overrun : null,
    thrown: count(body.thrown),
  };
}
