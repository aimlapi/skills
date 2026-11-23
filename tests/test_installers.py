"""install/install.sh and install/install.ps1 against a local fake npm registry. No network.

    python3 -m unittest tests.test_installers -v

The PowerShell cases run only where `pwsh` is installed (CI has it).
"""

from __future__ import annotations

import base64
import hashlib
import http.server
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SH = ROOT / "install" / "install.sh"
PS1 = ROOT / "install" / "install.ps1"
VERSION = json.loads((ROOT / "package.json").read_text())["version"]
SKILLS = sorted(p.parent.name for p in (ROOT / "skills").glob("*/SKILL.md"))


def build_tarball() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        tar.add(ROOT / "package.json", arcname="package/package.json")
        for name in SKILLS:
            tar.add(ROOT / "skills" / name, arcname=f"package/skills/{name}",
                    filter=lambda t: None if "__pycache__" in t.name or t.name.endswith(".pyc") else t)
    return buf.getvalue()


class FakeRegistry:
    def __init__(self, tarball: bytes, integrity_of: bytes | None = None):
        digest = base64.b64encode(hashlib.sha512(integrity_of or tarball).digest()).decode()
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path.endswith(".tgz"):
                    body, ctype = tarball, "application/octet-stream"
                elif self.path in ("/@aimlapi%2fskills/latest", f"/@aimlapi%2fskills/{VERSION}"):
                    body = json.dumps({"name": "@aimlapi/skills", "version": VERSION, "dist": {
                        "tarball": f"{outer.url}/@aimlapi/skills/-/skills-{VERSION}.tgz",
                        "integrity": f"sha512-{digest}"}}).encode()
                    ctype = "application/json"
                else:
                    self.send_response(404)
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()


class Base(unittest.TestCase):
    tarball = build_tarball()

    def setUp(self):
        self.registry = FakeRegistry(self.tarball)
        self.addCleanup(self.registry.close)
        self.home = Path(tempfile.mkdtemp())
        self.project = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q", str(self.project)], check=True)
        (self.project / "src").mkdir()
        self.addCleanup(shutil.rmtree, self.home, True)
        self.addCleanup(shutil.rmtree, self.project, True)

    def env(self, registry=None):
        env = {k: v for k, v in os.environ.items() if not k.startswith("AIMLAPI_")}
        env.update(HOME=str(self.home), AIMLAPI_NPM_REGISTRY=(registry or self.registry).url)
        return env

    def installed(self, base: Path, rel: str) -> list:
        d = base / rel
        return sorted(p.name for p in d.iterdir()) if d.is_dir() else []


class InstallSh(Base):
    def run_sh(self, *args, registry=None, piped=False):
        cmd = ["sh", "-s", "--", *args] if piped else ["sh", str(SH), *args]
        return subprocess.run(cmd, input=SH.read_bytes() if piped else None, cwd=self.project / "src",
                              env=self.env(registry), capture_output=True, timeout=120)

    def test_all_skills_for_claude_at_the_repository_root_through_a_pipe(self):
        r = self.run_sh(piped=True)
        self.assertEqual(r.returncode, 0, r.stderr.decode())
        self.assertEqual(self.installed(self.project, ".claude/skills"), SKILLS)
        self.assertTrue((self.project / ".claude/skills/aimlapi-models/scripts/models.py").is_file())

    def test_shared_agents_folder_and_user_scope(self):
        r = self.run_sh("--agent", "cursor,codex", "aimlapi-chat")
        self.assertEqual(r.returncode, 0, r.stderr.decode())
        self.assertEqual(self.installed(self.project, ".agents/skills"), ["aimlapi-chat"])
        r = self.run_sh("--scope", "user", "--agent", "opencode", "aimlapi-chat")
        self.assertEqual(r.returncode, 0, r.stderr.decode())
        self.assertEqual(self.installed(self.home, ".config/opencode/skills"), ["aimlapi-chat"])

    def test_update_replaces_the_old_copy(self):
        self.run_sh("aimlapi-costs")
        stale = self.project / ".claude/skills/aimlapi-costs/stale.md"
        stale.write_text("old")
        r = self.run_sh("aimlapi-costs")
        self.assertIn(b"updated", r.stderr)
        self.assertFalse(stale.exists())
        self.assertEqual(self.installed(self.project, ".claude/skills"), ["aimlapi-costs"])

    def test_bad_integrity_writes_nothing(self):
        bad = FakeRegistry(self.tarball, integrity_of=b"something else")
        self.addCleanup(bad.close)
        r = self.run_sh(registry=bad)
        self.assertEqual(r.returncode, 1)
        self.assertIn(b"integrity check failed", r.stderr)
        self.assertFalse((self.project / ".claude").exists())

    def test_dry_run_and_bad_input(self):
        r = self.run_sh("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr.decode())
        self.assertIn(b"would install", r.stderr)
        self.assertFalse((self.project / ".claude").exists())
        self.assertIn(b"no skill aimlapi-nope", self.run_sh("aimlapi-nope").stderr)
        self.assertIn(b"unknown agent", self.run_sh("--agent", "notepad").stderr)
        self.assertIn(b"project or user", self.run_sh("--scope", "global").stderr)


@unittest.skipUnless(shutil.which("pwsh"), "pwsh not installed")
class InstallPs1(Base):
    def run_ps(self, *args, registry=None):
        # Parameter names stay bare (-Agent); values are quoted.
        words = [a if a.startswith("-") else f"'{a}'" for a in args]
        script = "$ErrorActionPreference = 'Stop'; & ([scriptblock]::Create([IO.File]::ReadAllText($env:PS1))) " + " ".join(words)
        env = self.env(registry)
        env["PS1"] = str(PS1)
        env["USERPROFILE"] = str(self.home)
        return subprocess.run(["pwsh", "-NoProfile", "-NonInteractive", "-Command", script],
                              cwd=self.project / "src", env=env, capture_output=True, timeout=180)

    def test_all_skills_for_claude(self):
        r = self.run_ps()
        self.assertEqual(r.returncode, 0, (r.stdout + r.stderr).decode())
        self.assertEqual(self.installed(self.project, ".claude/skills"), SKILLS)

    def test_user_scope_cursor_one_skill(self):
        r = self.run_ps("-Agent", "cursor", "-Scope", "user", "aimlapi-chat")
        self.assertEqual(r.returncode, 0, (r.stdout + r.stderr).decode())
        self.assertEqual(self.installed(self.home, ".cursor/skills"), ["aimlapi-chat"])

    def test_bad_integrity_writes_nothing(self):
        bad = FakeRegistry(self.tarball, integrity_of=b"something else")
        self.addCleanup(bad.close)
        r = self.run_ps(registry=bad)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn(b"integrity", (r.stdout + r.stderr).lower())
        self.assertFalse((self.project / ".claude").exists())


if __name__ == "__main__":
    unittest.main()
