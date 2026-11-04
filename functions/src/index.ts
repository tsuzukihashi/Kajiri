import { initializeApp } from "firebase-admin/app";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { makeClient } from "./claude.ts";
import { AppError } from "./errors.ts";
import { decompose, prep, resplit, weekly, work } from "./kajiri.ts";

/**
 * Kajiri の中継サーバ（Firebase Functions）。
 * - Anthropic の API キーは Secret Manager にだけ置く（コードにもアプリにも入れない）
 * - App Check で、本物の Kajiri アプリからの呼び出しだけを受け付ける
 * - 受け取ったタスクの中身は保存しない・ログに書かない
 */
initializeApp();
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

export const kajiriDecompose = onCall(
  { secrets: [anthropicApiKey], enforceAppCheck: true, timeoutSeconds: 180, memory: "512MiB" },
  (request) => run(() => decompose(request.data, makeClient(anthropicApiKey.value(), null))),
);

export const kajiriResplit = onCall(
  { secrets: [anthropicApiKey], enforceAppCheck: true, timeoutSeconds: 120 },
  (request) => run(() => resplit(request.data, makeClient(anthropicApiKey.value(), null))),
);

export const kajiriWork = onCall(
  { secrets: [anthropicApiKey], enforceAppCheck: true, timeoutSeconds: 300, memory: "512MiB" },
  (request) => run(() => work(request.data, makeClient(anthropicApiKey.value(), null))),
);

export const kajiriPrep = onCall(
  { secrets: [anthropicApiKey], enforceAppCheck: true, timeoutSeconds: 120 },
  (request) => run(() => prep(request.data, makeClient(anthropicApiKey.value(), null))),
);

export const kajiriWeekly = onCall(
  { secrets: [anthropicApiKey], enforceAppCheck: true, timeoutSeconds: 120 },
  (request) => run(() => weekly(request.data, makeClient(anthropicApiKey.value(), null))),
);

async function run<T>(task: () => Promise<T>): Promise<T> {
  try {
    return await task();
  } catch (e) {
    if (e instanceof AppError) {
      throw new HttpsError(e.kind, e.message, { code: e.code });
    }
    // 中身（タスクの文章）は書かない。種類だけ
    logger.error("internal_error", { name: e instanceof Error ? e.name : "unknown" });
    throw new HttpsError("internal", "サーバでエラーが起きました。");
  }
}
