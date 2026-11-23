"""Live tests against api.aimlapi.com. Skipped unless enabled.

    AIMLAPI_LIVE_TESTS=1 python3 -m unittest tests.test_live              # catalogue only, no key
    AIMLAPI_LIVE_TESTS=1 AIMLAPI_API_KEY=<sandbox key> python3 -m unittest tests.test_live

With a key, every inference test runs in sandbox mode: nothing is charged. Use a sandbox key
(created with "mode": "sandbox") so a mistake can never start a paid request.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIVE = os.environ.get("AIMLAPI_LIVE_TESTS") == "1"
KEY = bool(os.environ.get("AIMLAPI_API_KEY"))


def run(script: str, *args: str, timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-I", str(ROOT / script), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        env={k: v for k, v in os.environ.items() if k in {"AIMLAPI_API_KEY", "PATH", "HOME"}},
    )


MODELS = "skills/aimlapi-models/scripts/models.py"
TRY = "skills/aimlapi-sandbox/scripts/try.py"
JOB = "skills/aimlapi-async-jobs/scripts/job.py"


@unittest.skipUnless(LIVE, "set AIMLAPI_LIVE_TESTS=1")
class Catalogue(unittest.TestCase):
    def test_search(self):
        out = run(MODELS, "search", "gpt-4o-mini", "--limit", "3")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("openai/gpt-4o-mini", out.stdout)

    def test_params_reads_docs_json(self):
        out = run(MODELS, "--json", "params", "flux/schnell")
        self.assertEqual(out.returncode, 0, out.stderr)
        data = json.loads(out.stdout)
        self.assertIn("prompt", data["required"])

    def test_price_kind(self):
        out = run(MODELS, "--json", "price", "openai/gpt-4o-mini")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn(json.loads(out.stdout)["pricing"]["kind"], {"fixed", "variants", "variable"})

    def test_status_of_unknown_model(self):
        out = run(MODELS, "status", "does-not-exist-model")
        self.assertIn("probably never existed", out.stdout)


@unittest.skipUnless(LIVE and KEY, "set AIMLAPI_LIVE_TESTS=1 and AIMLAPI_API_KEY")
class Sandbox(unittest.TestCase):
    def assert_sandbox_ok(self, out: subprocess.CompletedProcess) -> None:
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn("x-aimlapi-sandbox: true", out.stdout)

    def test_chat(self):
        self.assert_sandbox_ok(run(TRY, "chat", json.dumps({
            "model": "openai/gpt-4o-mini",
            "messages": [{"role": "user", "content": "hi"}],
            "max_tokens": 20,
        })))

    def test_chat_tool_call(self):
        out = run(TRY, "chat", json.dumps({
            "model": "openai/gpt-4o-mini",
            "messages": [{"role": "user", "content": "[sandbox:tool] weather in Lisbon"}],
            "tools": [{"type": "function", "function": {
                "name": "get_weather",
                "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]},
            }}],
        }))
        self.assert_sandbox_ok(out)
        self.assertIn("tool_calls", out.stdout)

    def test_scripted_429(self):
        out = run(TRY, "chat", json.dumps({
            "model": "openai/gpt-4o-mini",
            "messages": [{"role": "user", "content": "[sandbox:error=429] hi"}],
        }))
        self.assertEqual(out.returncode, 1)
        self.assertIn("HTTP 429", out.stdout)
        self.assertIn("retry-after", out.stdout.lower())

    def test_messages(self):
        self.assert_sandbox_ok(run(TRY, "messages", json.dumps({
            "model": "anthropic/claude-haiku-5-5",
            "max_tokens": 20,
            "messages": [{"role": "user", "content": "hi"}],
        })))

    def test_messages_on_a_translated_model(self):
        self.assert_sandbox_ok(run(TRY, "messages", json.dumps({
            "model": "openai/gpt-4o-mini",
            "max_tokens": 20,
            "messages": [{"role": "user", "content": "hi"}],
        })))

    def test_image(self):
        out = run(TRY, "image", json.dumps({"model": "flux/schnell", "prompt": "a red cube"}))
        self.assert_sandbox_ok(out)
        self.assertIn('"url"', out.stdout)

    def test_embeddings(self):
        self.assert_sandbox_ok(run(TRY, "embed", json.dumps({"model": "openai/text-embedding-3-small", "input": "hello"})))

    def test_video_job(self):
        out = run(JOB, "submit", "video", "--sandbox", "--interval", "3", "--timeout", "120", "--body", json.dumps({
            "model": "google/veo-3.1-lite-generate-001",
            "prompt": "a paper boat in the rain",
            "duration": 4,
        }), timeout=180)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn('"completed"', out.stdout)


if __name__ == "__main__":
    unittest.main()
