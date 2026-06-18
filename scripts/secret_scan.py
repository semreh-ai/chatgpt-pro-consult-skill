#!/usr/bin/env python3
"""Conservative local scanner for ChatGPT Pro consult prompt files.

The scanner is intentionally simple and dependency-free. It blocks obvious
credential material and risky path references before a context bundle is sent to
an external backend. It is not a formal DLP system.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PATH_DENYLIST = [
    re.compile(r"(^|/|\\\\)\.env(\.|$)"),
    re.compile(r"(^|/|\\\\)id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$"),
    re.compile(r"(^|/|\\\\)(credentials|secrets?)\.(json|ya?ml|toml|ini|env)$", re.I),
    re.compile(r"(^|/|\\\\)(cookie|cookies|session|sessions)(\.|/|\\\\)", re.I),
]

CONTENT_DENYLIST = [
    ("PRIVATE_KEY", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("OPENAI_API_KEY", re.compile(r"sk-[A-Za-z0-9_-]{20,}")),
    ("GITHUB_TOKEN", re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}")),
    ("ANTHROPIC_API_KEY", re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")),
    ("AWS_ACCESS_KEY_ID", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("JWT", re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("BEARER_TOKEN", re.compile(r"Bearer\s+[A-Za-z0-9._~+/=-]{24,}", re.I)),
    ("COOKIE_HEADER", re.compile(r"\bCookie:\s*[^\n]{20,}", re.I)),
    ("DATABASE_URL_WITH_PASSWORD", re.compile(r"\b[a-z][a-z0-9+.-]*://[^\s:/]+:[^\s@/]+@", re.I)),
    ("GENERIC_SECRET_ASSIGNMENT", re.compile(r"(?i)\b(api[_-]?key|secret|token|password|passwd|pwd)\b\s*[:=]\s*['\"]?[^'\"\s]{16,}")),
]


def scan_text(text: str) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for label, pattern in CONTENT_DENYLIST:
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            snippet = match.group(0)[:120]
            findings.append({"type": label, "line": line, "snippet": snippet})
    return findings


def scan_paths(text: str) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for pattern in PATH_DENYLIST:
            if pattern.search(line):
                findings.append({"type": "RISKY_PATH_REFERENCE", "line": line_no, "snippet": line[:160]})
                break
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan a prompt/context bundle for obvious secrets.")
    parser.add_argument("path", help="Prompt/context file to scan")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    parser.add_argument("--max-bytes", type=int, default=1_000_000, help="Maximum file size to scan")
    args = parser.parse_args()

    path = Path(args.path)
    result: dict[str, object] = {"ok": False, "path": str(path), "findings": []}

    if not path.exists() or not path.is_file():
        result["error"] = "FILE_NOT_FOUND"
        print(json.dumps(result, indent=2) if args.json else f"FILE_NOT_FOUND: {path}")
        return 3

    size = path.stat().st_size
    result["bytes"] = size
    if size > args.max_bytes:
        result["error"] = "FILE_TOO_LARGE"
        print(json.dumps(result, indent=2) if args.json else f"FILE_TOO_LARGE: {size} > {args.max_bytes}")
        return 4

    text = path.read_text(encoding="utf-8", errors="replace")
    findings = scan_paths(text) + scan_text(text)
    result["findings"] = findings
    result["ok"] = not findings

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if findings:
            print(f"Blocked: {len(findings)} potential secret/path findings")
            for finding in findings[:20]:
                print(f"- line {finding['line']}: {finding['type']} :: {finding['snippet']}")
        else:
            print("OK: no obvious secrets found")

    return 0 if not findings else 4


if __name__ == "__main__":
    sys.exit(main())
