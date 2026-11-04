/** 利用者に見せてよいエラー。message は画面にそのまま出る（日本語）。 */
export class AppError extends Error {
  readonly kind: AppErrorKind;
  readonly code: string;

  constructor(kind: AppErrorKind, code: string, message: string) {
    super(message);
    this.kind = kind;
    this.code = code;
  }
}

/** Firebase の HttpsError の code に対応させる種類 */
export type AppErrorKind = "invalid-argument" | "failed-precondition" | "unavailable" | "internal";
