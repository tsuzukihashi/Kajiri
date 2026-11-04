#!/usr/bin/env bash
# git init のあとに一度だけ実行する。コミットのたびに秘密情報が入っていないかを調べる。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
hook=".git/hooks/pre-commit"
cat > "$hook" <<'EOF'
#!/usr/bin/env bash
exec python3 scripts/check_secrets.py --staged
EOF
chmod +x "$hook"
echo "pre-commit フックを入れました: $hook"
