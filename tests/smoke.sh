#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 scripts/secret_scan.py templates/context-bundle.md --json >/tmp/chatgpt-pro-consult-scan.json
CHATGPT_PRO_CONSULT_COMMAND="./examples/custom-backend.sh" \
  bash scripts/preflight.sh --backend custom --json >/tmp/chatgpt-pro-consult-preflight.json

prompt="$(mktemp)"
cat > "$prompt" <<'EOF'
# Task
Smoke test the custom backend contract.

# Question for ChatGPT Pro
Return a short acknowledgement.
EOF

CHATGPT_PRO_CONSULT_COMMAND="./examples/custom-backend.sh" \
  bash scripts/chatgpt-pro-consult.sh \
    --prompt-file "$prompt" \
    --backend custom \
    --room smoke-test \
    --state-dir /tmp/chatgpt-pro-consult-smoke \
    --format json >/tmp/chatgpt-pro-consult-result.json

grep -q '"status": "success"' /tmp/chatgpt-pro-consult-result.json

if CHATGPT_PRO_CONSULT_COMMAND="echo 'Bearer abcdefghijklmnopqrstuvwxyz1234567890' >&2; exit 42" \
  bash scripts/chatgpt-pro-consult.sh \
    --prompt-file "$prompt" \
    --backend custom \
    --room smoke-redaction \
    --state-dir /tmp/chatgpt-pro-consult-smoke-redaction \
    --format json >/tmp/chatgpt-pro-consult-redaction.json; then
  echo "expected failing backend" >&2
  exit 1
fi
grep -q 'Bearer \[REDACTED_TOKEN\]' /tmp/chatgpt-pro-consult-redaction.json
if grep -q 'abcdefghijklmnopqrstuvwxyz1234567890' /tmp/chatgpt-pro-consult-redaction.json; then
  echo "receipt leaked raw backend token" >&2
  exit 1
fi
rm -f "$prompt"
