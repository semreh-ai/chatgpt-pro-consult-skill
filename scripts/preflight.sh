#!/usr/bin/env bash
set -euo pipefail

backend="${CHATGPT_PRO_CONSULT_BACKEND:-auto}"
json=false
prompt_file=""

usage() {
  cat <<'EOF'
Usage: preflight.sh [--backend auto|custom|chatgpt-pro|oracle] [--prompt-file FILE] [--json]

Checks whether a ChatGPT Pro consult backend is available. If --prompt-file is
provided, also runs the local secret scanner.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend) backend="${2:-}"; shift 2 ;;
    --prompt-file) prompt_file="${2:-}"; shift 2 ;;
    --json) json=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

has_cmd() { command -v "$1" >/dev/null 2>&1; }

available=()
[[ -n "${CHATGPT_PRO_CONSULT_COMMAND:-}" ]] && available+=("custom")
has_cmd chatgpt-pro && available+=("chatgpt-pro")
has_cmd oracle && available+=("oracle")

selected=""
case "$backend" in
  auto)
    if [[ ${#available[@]} -gt 0 ]]; then selected="${available[0]}"; fi
    ;;
  custom)
    [[ -n "${CHATGPT_PRO_CONSULT_COMMAND:-}" ]] && selected="custom"
    ;;
  chatgpt-pro)
    has_cmd chatgpt-pro && selected="chatgpt-pro"
    ;;
  oracle)
    has_cmd oracle && selected="oracle"
    ;;
  *) echo "Unknown backend: $backend" >&2; exit 2 ;;
esac

scan_ok=true
scan_output=""
if [[ -n "$prompt_file" ]]; then
  if ! scan_output="$(python3 "$(dirname "$0")/secret_scan.py" "$prompt_file" --json 2>&1)"; then
    scan_ok=false
  fi
fi

ok=false
[[ -n "$selected" && "$scan_ok" == true ]] && ok=true

if [[ "$json" == true ]]; then
  python3 - "$ok" "$backend" "$selected" "$scan_ok" "${available[*]:-}" "$scan_output" <<'PY'
import json, sys
ok = sys.argv[1] == 'true'
backend, selected = sys.argv[2], sys.argv[3]
scan_ok = sys.argv[4] == 'true'
available = [x for x in sys.argv[5].split() if x]
scan_raw = sys.argv[6]
try:
    scan = json.loads(scan_raw) if scan_raw else None
except Exception:
    scan = {"ok": False, "raw": scan_raw}
print(json.dumps({
    "ok": ok,
    "requested_backend": backend,
    "selected_backend": selected or None,
    "available_backends": available,
    "prompt_scan_ok": scan_ok,
    "prompt_scan": scan,
}, indent=2))
PY
else
  echo "Requested backend: $backend"
  echo "Available backends: ${available[*]:-(none)}"
  echo "Selected backend: ${selected:-(none)}"
  [[ -n "$prompt_file" ]] && echo "Prompt scan ok: $scan_ok"
fi

[[ "$ok" == true ]] || exit 5
