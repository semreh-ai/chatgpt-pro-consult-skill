#!/usr/bin/env bash
set -euo pipefail

backend="${CHATGPT_PRO_CONSULT_BACKEND:-auto}"
prompt_file=""
room="default"
timeout_seconds=600
format="text"
state_dir=".chatgpt-pro-consult"
receipt_path=""

usage() {
  cat <<'EOF'
Usage: chatgpt-pro-consult.sh --prompt-file FILE [options]

Options:
  --backend auto|custom|chatgpt-pro|oracle
  --room ROOM
  --timeout SECONDS
  --format text|json
  --state-dir DIR
  --receipt PATH

Exit codes:
  0 success
  2 invalid CLI arguments
  3 prompt file missing/unreadable
  4 secret scan blocked the prompt
  5 no backend available
  6 backend failed
  7 lock conflict
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend) backend="${2:-}"; shift 2 ;;
    --prompt-file) prompt_file="${2:-}"; shift 2 ;;
    --room) room="${2:-}"; shift 2 ;;
    --timeout) timeout_seconds="${2:-}"; shift 2 ;;
    --format) format="${2:-}"; shift 2 ;;
    --state-dir) state_dir="${2:-}"; shift 2 ;;
    --receipt) receipt_path="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$prompt_file" ]] || { echo "--prompt-file is required" >&2; exit 2; }
[[ -r "$prompt_file" ]] || { echo "Prompt file missing/unreadable: $prompt_file" >&2; exit 3; }
[[ "$format" == "text" || "$format" == "json" ]] || { echo "--format must be text or json" >&2; exit 2; }
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] || { echo "--timeout must be seconds" >&2; exit 2; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! scan_json="$(python3 "$script_dir/secret_scan.py" "$prompt_file" --json 2>&1)"; then
  if [[ "$format" == "json" ]]; then
    python3 - "$scan_json" <<'PY'
import json, sys
try:
    scan=json.loads(sys.argv[1])
except Exception:
    scan={"raw":sys.argv[1]}
print(json.dumps({"ok": False, "error_code": "SECRET_SCAN_BLOCKED", "scan": scan}, indent=2))
PY
  else
    echo "$scan_json" >&2
  fi
  exit 4
fi

safe_room="$(printf '%s' "$room" | tr -c 'A-Za-z0-9._-' '-')"
mkdir -p "$state_dir/locks" "$state_dir/receipts" "$state_dir/responses"
lock_path="$state_dir/locks/$safe_room.lock"
if ! mkdir "$lock_path" 2>/dev/null; then
  echo "Room is locked: $room ($lock_path)" >&2
  exit 7
fi
trap 'rm -rf "$lock_path"' EXIT

if [[ -z "$receipt_path" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  receipt_path="$state_dir/receipts/$ts-$safe_room.json"
fi
response_path="$state_dir/responses/$(basename "$receipt_path" .json).txt"

has_cmd() { command -v "$1" >/dev/null 2>&1; }
select_backend() {
  case "$backend" in
    auto)
      if [[ -n "${CHATGPT_PRO_CONSULT_COMMAND:-}" ]]; then echo custom; return 0; fi
      if has_cmd chatgpt-pro; then echo chatgpt-pro; return 0; fi
      if has_cmd oracle; then echo oracle; return 0; fi
      return 1
      ;;
    custom)
      [[ -n "${CHATGPT_PRO_CONSULT_COMMAND:-}" ]] && echo custom || return 1
      ;;
    chatgpt-pro)
      has_cmd chatgpt-pro && echo chatgpt-pro || return 1
      ;;
    oracle)
      has_cmd oracle && echo oracle || return 1
      ;;
    *) return 2 ;;
  esac
}

if ! selected="$(select_backend)"; then
  if [[ "$format" == "json" ]]; then
    python3 - <<PY
import json
print(json.dumps({"ok": False, "error_code": "NO_BACKEND", "requested_backend": "$backend"}, indent=2))
PY
  else
    echo "No ChatGPT Pro backend available for: $backend" >&2
  fi
  exit 5
fi

run_backend() {
  case "$selected" in
    custom)
      PROMPT_FILE="$prompt_file" ROOM="$room" RECEIPT_PATH="$receipt_path" TIMEOUT_SECONDS="$timeout_seconds" \
        timeout "$timeout_seconds" bash -lc "$CHATGPT_PRO_CONSULT_COMMAND"
      ;;
    chatgpt-pro)
      if chatgpt-pro --help 2>&1 | grep -q -- '--prompt-file'; then
        timeout "$timeout_seconds" chatgpt-pro --prompt-file "$prompt_file" --room "$room"
      else
        timeout "$timeout_seconds" chatgpt-pro < "$prompt_file"
      fi
      ;;
    oracle)
      timeout "$timeout_seconds" oracle -p "$(cat "$prompt_file")"
      ;;
  esac
}

status="success"
error_msg=""
if ! output="$(run_backend 2>&1)"; then
  status="failure"
  error_msg="$output"
else
  printf '%s\n' "$output" > "$response_path"
fi

prompt_sha="$(sha256sum "$prompt_file" | awk '{print $1}')"
response_sha=""
[[ -f "$response_path" ]] && response_sha="$(sha256sum "$response_path" | awk '{print $1}')"

python3 - "$receipt_path" "$status" "$selected" "$room" "$prompt_file" "$prompt_sha" "$response_path" "$response_sha" "$error_msg" <<'PY'
import json, sys, datetime, re
receipt, status, backend, room, prompt_file, prompt_sha, response_path, response_sha, error = sys.argv[1:]

def redact_error(text):
    if not text:
        return None
    patterns = [
        (re.compile(r"sk-[A-Za-z0-9_-]{20,}"), "[REDACTED_OPENAI_API_KEY]"),
        (re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"), "[REDACTED_GITHUB_TOKEN]"),
        (re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"), "[REDACTED_ANTHROPIC_API_KEY]"),
        (re.compile(r"AKIA[0-9A-Z]{16}"), "[REDACTED_AWS_ACCESS_KEY_ID]"),
        (re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"), "[REDACTED_JWT]"),
        (re.compile(r"Bearer\s+[A-Za-z0-9._~+/=-]{24,}", re.I), "Bearer [REDACTED_TOKEN]"),
        (re.compile(r"Cookie:\s*[^\n]{20,}", re.I), "Cookie: [REDACTED_COOKIE]"),
        (re.compile(r"\b[a-z][a-z0-9+.-]*://([^\s:/]+):([^\s@/]+)@", re.I), lambda m: m.group(0).replace(m.group(2), "[REDACTED_PASSWORD]")),
        (re.compile(r"(?i)\b(api[_-]?key|secret|token|password|passwd|pwd)\b\s*[:=]\s*['\"]?[^'\"\s]{16,}"), lambda m: re.sub(r"[:=].*", ": [REDACTED]", m.group(0))),
        (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S), "[REDACTED_PRIVATE_KEY]"),
    ]
    redacted = text
    for pattern, repl in patterns:
        redacted = pattern.sub(repl, redacted)
    return redacted[:2000]

data = {
    "schema_version": "1.0",
    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": status,
    "backend": backend,
    "room": room,
    "prompt_file": prompt_file,
    "prompt_sha256": prompt_sha,
    "response_path": response_path if response_sha else None,
    "response_sha256": response_sha or None,
    "redactions_applied": True,
    "error": redact_error(error),
}
with open(receipt, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
print(json.dumps(data, indent=2))
PY

if [[ "$status" != "success" ]]; then
  exit 6
fi

if [[ "$format" == "text" ]]; then
  echo
  echo "--- ChatGPT Pro backend response ($selected) ---"
  cat "$response_path"
fi
