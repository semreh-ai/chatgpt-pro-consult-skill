#!/usr/bin/env bash
set -euo pipefail

# Example backend for chatgpt-pro-consult.
# The wrapper provides:
#   PROMPT_FILE, ROOM, RECEIPT_PATH, TIMEOUT_SECONDS
# Replace this with a real local ChatGPT Pro / browser / MCP adapter.

: "${PROMPT_FILE:?PROMPT_FILE is required}"
: "${ROOM:=default}"

echo "[custom backend example] room=$ROOM"
echo "[custom backend example] prompt_sha256=$(sha256sum "$PROMPT_FILE" | awk '{print $1}')"
echo
sed -n '1,80p' "$PROMPT_FILE"
