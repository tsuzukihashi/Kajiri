#!/usr/bin/env python3
"""公開リポジトリに秘密情報が入るのを止める。

使い方:
  python3 scripts/check_secrets.py --hook     # Claude Code の PreToolUse フック（stdin に JSON）
  python3 scripts/check_secrets.py --staged   # git の pre-commit（ステージ済みのファイルを調べる）
  python3 scripts/check_secrets.py PATH ...   # 手で調べる

見つかったら終了コード 2 で止める（Claude Code のフックは 2 で書き込みを止める）。
標準ライブラリだけで動く。
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

# 中身に入っていたら止めるもの
SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("Anthropic の API キー", re.compile(r"sk-ant-[A-Za-z0-9_\-]{20,}")),
    ("秘密鍵", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("AWS のアクセスキー", re.compile(r"AKIA[0-9A-Z]{16}")),
    # Firebase の iOS 用 API キー。GoogleService-Info.plist（.gitignore 済み）以外に出てきたら止める
    ("Google の API キー", re.compile(r"AIza[0-9A-Za-z_\-]{35}")),
    # シミュレータ用の App Check デバッグトークン。漏れると誰でも中継サーバを呼べる
    (
        "App Check のデバッグトークン",
        re.compile(
            r"FIRAAppCheckDebugToken[^\n]{0,40}?"
            r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        ),
    ),
]

# このパスは秘密の置き場（.gitignore 済み）なので、書き込むときは中身を調べない
SECRET_HOME_PATHS = (
    "ios/Config/Local.xcconfig",
    "ios/Kajiri/GoogleService-Info.plist",
    "functions/.secret.local",
)

# コミットしてはいけないもの
FORBIDDEN_COMMIT_PREFIXES: tuple[str, ...] = ()
FORBIDDEN_COMMIT_NAMES = ("Local.xcconfig", "GoogleService-Info.plist", ".secret.local")

SELF = Path(__file__).resolve()

HOW_TO_STORE = (
    "Anthropic の API キーは `firebase functions:secrets:set ANTHROPIC_API_KEY` で Firebase にだけ置き、"
    "Firebase の設定は ios/Kajiri/GoogleService-Info.plist（.gitignore 済み）に置いてください。"
)


def find_secrets(text: str) -> list[str]:
    return [label for label, pattern in SECRET_PATTERNS if pattern.search(text)]


def is_secret_home(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return any(normalized.endswith(p) for p in SECRET_HOME_PATHS)


def run_hook() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    tool_input = payload.get("tool_input") or {}
    file_path = str(tool_input.get("file_path") or "")
    if file_path and (is_secret_home(file_path) or Path(file_path).resolve() == SELF):
        return 0

    texts = [str(tool_input.get("content") or ""), str(tool_input.get("new_string") or "")]
    for edit in tool_input.get("edits") or []:
        texts.append(str(edit.get("new_string") or ""))

    hits = sorted({h for t in texts for h in find_secrets(t)})
    if hits:
        print(
            f"公開リポジトリに入れてはいけない情報（{', '.join(hits)}）が {file_path or 'このファイル'} に含まれています。"
            + HOW_TO_STORE,
            file=sys.stderr,
        )
        return 2
    return 0


def staged_files() -> list[str]:
    out = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in out.stdout.splitlines() if line]


def run_staged() -> int:
    problems: list[str] = []
    for path in staged_files():
        name = Path(path).name
        if path.startswith(FORBIDDEN_COMMIT_PREFIXES) or name in FORBIDDEN_COMMIT_NAMES:
            problems.append(f"{path}: 公開してはいけないファイルです")
            continue
        if Path(path).resolve() == SELF:
            continue
        blob = subprocess.run(["git", "show", f":{path}"], capture_output=True)
        text = blob.stdout.decode("utf-8", errors="ignore")
        for hit in find_secrets(text):
            problems.append(f"{path}: {hit}")
    if problems:
        print("コミットを止めました。公開リポジトリに入れてはいけないものがあります:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        print(HOW_TO_STORE, file=sys.stderr)
        return 2
    return 0


def run_paths(paths: list[str]) -> int:
    problems = []
    for p in paths:
        path = Path(p)
        files = [f for f in path.rglob("*") if f.is_file()] if path.is_dir() else [path]
        for f in files:
            if f.resolve() == SELF or any(part in {"node_modules", ".git", "lib"} for part in f.parts):
                continue
            if is_secret_home(str(f)):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for hit in find_secrets(text):
                problems.append(f"{f}: {hit}")
    for line in problems:
        print(line, file=sys.stderr)
    return 2 if problems else 0


def main() -> int:
    args = sys.argv[1:]
    if args[:1] == ["--hook"]:
        return run_hook()
    if args[:1] == ["--staged"]:
        return run_staged()
    return run_paths(args or ["."])


if __name__ == "__main__":
    sys.exit(main())
