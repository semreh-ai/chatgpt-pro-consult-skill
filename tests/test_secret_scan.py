import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN = ROOT / "scripts" / "secret_scan.py"


class SecretScanTests(unittest.TestCase):
    def run_scan(self, text: str):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as f:
            f.write(text)
            path = f.name
        try:
            proc = subprocess.run(
                ["python3", str(SCAN), path, "--json"],
                text=True,
                capture_output=True,
                check=False,
            )
            return proc.returncode, json.loads(proc.stdout)
        finally:
            Path(path).unlink(missing_ok=True)

    def test_clean_prompt_passes(self):
        code, data = self.run_scan("# Task\nReview this architecture.\n")
        self.assertEqual(code, 0)
        self.assertTrue(data["ok"])

    def test_openai_key_blocks(self):
        code, data = self.run_scan("OPENAI_API_KEY=sk-" + "a" * 40)
        self.assertEqual(code, 4)
        self.assertFalse(data["ok"])
        self.assertTrue(any(f["type"] == "OPENAI_API_KEY" for f in data["findings"]))

    def test_private_key_blocks(self):
        code, data = self.run_scan("-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----")
        self.assertEqual(code, 4)
        self.assertFalse(data["ok"])


if __name__ == "__main__":
    unittest.main()
