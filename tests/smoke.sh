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
rm -f "$prompt"
