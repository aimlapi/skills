// node --test 'tests/*.test.mjs'
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AGENTS, install, parseArgs, readSkills, targets } from "../cli/aimlapi-skills.mjs";

const quiet = () => {};

function project() {
  const root = mkdtempSync(join(tmpdir(), "aimlapi-skills-"));
  mkdirSync(join(root, ".git"));
  mkdirSync(join(root, "src", "deep"), { recursive: true });
  return root;
}

test("every skill folder is offered", () => {
  const names = readSkills().map((s) => s.name);
  assert.ok(names.length >= 13);
  assert.ok(names.every((n) => n.startsWith("aimlapi-")));
  assert.ok(readSkills().every((s) => s.description.startsWith("Use when")));
});

test("install from a subfolder lands at the repository root, default agent claude", () => {
  const root = project();
  const opts = parseArgs(["install", "aimlapi-models"]);
  install(opts, { cwd: join(root, "src", "deep") }, quiet);
  assert.ok(existsSync(join(root, ".claude", "skills", "aimlapi-models", "SKILL.md")));
  assert.ok(existsSync(join(root, ".claude", "skills", "aimlapi-models", "scripts", "models.py")));
});

test("agents that share .agents/skills get one copy", () => {
  const root = project();
  const opts = parseArgs(["install", "aimlapi-chat", "--agent", "cursor,codex", "--agent", "gemini"]);
  assert.deepEqual(targets(opts, { cwd: root }), [join(root, ".agents", "skills")]);
});

test("user scope goes to each agent's home folder", () => {
  const home = mkdtempSync(join(tmpdir(), "aimlapi-home-"));
  const opts = parseArgs(["install", "--scope", "user", "--agent", "claude,cursor,opencode"]);
  assert.deepEqual(targets(opts, { cwd: home, home }), [
    join(home, ".claude", "skills"),
    join(home, ".cursor", "skills"),
    join(home, ".config", "opencode", "skills"),
  ]);
});

test("installing again replaces the old copy, including removed files", () => {
  const root = project();
  const opts = parseArgs(["install", "aimlapi-costs"]);
  install(opts, { cwd: root }, quiet);
  const dest = join(root, ".claude", "skills", "aimlapi-costs");
  writeFileSync(join(dest, "stale.md"), "old");
  const lines = [];
  install(opts, { cwd: root }, (l) => lines.push(l));
  assert.ok(!existsSync(join(dest, "stale.md")));
  assert.match(lines[0], /^updated /);
  assert.ok(!readdirSync(join(root, ".claude", "skills")).some((n) => n.includes(".tmp-")));
});

test("dry run writes nothing", () => {
  const root = project();
  install(parseArgs(["install", "--dry-run"]), { cwd: root }, quiet);
  assert.ok(!existsSync(join(root, ".claude")));
});

test("bad input is a usage error", () => {
  assert.throws(() => parseArgs(["install", "--agent", "notepad"]), /unknown agent/);
  assert.throws(() => parseArgs(["install", "--scope", "global"]), /project or user/);
  assert.throws(() => parseArgs(["install", "--dir"]), /needs a value/);
  assert.throws(() => install(parseArgs(["install", "aimlapi-nope"]), { cwd: project() }, quiet), /unknown skill/);
});

test("every agent maps both scopes", () => {
  for (const [key, agent] of Object.entries(AGENTS)) {
    assert.ok(agent.project && agent.user, key);
  }
});
