#!/usr/bin/env node
// Install AI/ML API agent skills into the folder your coding agent reads.
// Node 18+, no dependencies.
//
//   npx @ai-ml.api/skills list
//   npx @ai-ml.api/skills install [skill ...] [--agent claude] [--scope project|user] [--dir PATH] [--dry-run]

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, realpathSync, renameSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PACKAGE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(PACKAGE_ROOT, "skills");

// Where each agent reads skills; the same places `gh skill install` uses.
// project: relative to the repository root. user: relative to the home folder.
export const AGENTS = {
  claude: { name: "Claude Code", project: ".claude/skills", user: ".claude/skills" },
  cursor: { name: "Cursor", project: ".agents/skills", user: ".cursor/skills" },
  codex: { name: "Codex", project: ".agents/skills", user: ".codex/skills" },
  gemini: { name: "Gemini CLI", project: ".agents/skills", user: ".gemini/skills" },
  opencode: { name: "OpenCode", project: ".agents/skills", user: ".config/opencode/skills" },
  copilot: { name: "GitHub Copilot", project: ".agents/skills", user: ".copilot/skills" },
  universal: { name: "any agent that reads .agents/skills", project: ".agents/skills", user: ".agents/skills" },
};

const HELP = `Install AI/ML API agent skills.

Usage:
  npx @ai-ml.api/skills list
  npx @ai-ml.api/skills install [skill ...] [options]

With no skill names, every skill is installed. Installing again updates them.

Options:
  --agent <name>   ${Object.keys(AGENTS).join(", ")} (default: claude; repeat or comma-separate for several)
  --scope <scope>  project (the current repository, default) or user (every project)
  --dir <path>     install into this folder instead
  --dry-run        show what would be written, write nothing
  -h, --help       this help
  -v, --version    package version
`;

export function readSkills(root = SKILLS_DIR) {
  return readdirSync(root)
    .filter((name) => existsSync(join(root, name, "SKILL.md")))
    .sort()
    .map((name) => {
      const text = readFileSync(join(root, name, "SKILL.md"), "utf8");
      const match = text.match(/^description:\s*"?(.*?)"?\s*$/m);
      return { name, description: match ? match[1] : "" };
    });
}

export function parseArgs(argv) {
  const opts = { command: null, skills: [], agents: [], scope: "project", dir: null, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = () => {
      const v = argv[++i];
      if (v === undefined || v.startsWith("-")) {
        throw new UsageError(`${arg} needs a value`);
      }
      return v;
    };
    if (arg === "-h" || arg === "--help") {
      opts.command = "help";
    } else if (arg === "-v" || arg === "--version") {
      opts.command = "version";
    } else if (arg === "--agent") {
      opts.agents.push(...value().split(",").map((a) => a.trim()).filter(Boolean));
    } else if (arg === "--scope") {
      opts.scope = value();
    } else if (arg === "--dir") {
      opts.dir = value();
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg.startsWith("-")) {
      throw new UsageError(`unknown option ${arg}`);
    } else if (!opts.command) {
      opts.command = arg;
    } else {
      opts.skills.push(arg);
    }
  }
  if (!["project", "user"].includes(opts.scope)) {
    throw new UsageError(`--scope must be project or user, not ${opts.scope}`);
  }
  for (const agent of opts.agents) {
    if (!AGENTS[agent]) {
      throw new UsageError(`unknown agent ${agent}; use one of ${Object.keys(AGENTS).join(", ")}`);
    }
  }
  return opts;
}

class UsageError extends Error {}

function projectRoot(start) {
  for (let dir = resolve(start); ; dir = dirname(dir)) {
    if (existsSync(join(dir, ".git"))) {
      return dir;
    }
    if (dirname(dir) === dir) {
      return resolve(start);
    }
  }
}

export function targets(opts, { cwd = process.cwd(), home = homedir() } = {}) {
  if (opts.dir) {
    return [resolve(cwd, opts.dir)];
  }
  const agents = opts.agents.length ? opts.agents : ["claude"];
  const base = opts.scope === "user" ? home : projectRoot(cwd);
  return [...new Set(agents.map((a) => join(base, AGENTS[a][opts.scope])))];
}

export function install(opts, env = {}, log = console.log) {
  const available = readSkills(env.skillsDir);
  const names = opts.skills.length ? opts.skills : available.map((s) => s.name);
  const unknown = names.filter((n) => !available.some((s) => s.name === n));
  if (unknown.length) {
    throw new UsageError(`unknown skill ${unknown.join(", ")}; run "list" to see them`);
  }
  const written = [];
  for (const target of targets(opts, env)) {
    for (const name of names) {
      const dest = join(target, name);
      const verb = existsSync(dest) ? "update" : "install";
      if (opts.dryRun) {
        log(`would ${verb} ${dest}`);
        continue;
      }
      mkdirSync(target, { recursive: true });
      // Copy next to the destination, then swap, so a failed copy never leaves half a skill.
      const tmp = `${dest}.tmp-${process.pid}`;
      rmSync(tmp, { recursive: true, force: true });
      cpSync(join(env.skillsDir ?? SKILLS_DIR, name), tmp, { recursive: true });
      rmSync(dest, { recursive: true, force: true });
      renameSync(tmp, dest);
      written.push(dest);
      log(`${verb === "update" ? "updated" : "installed"} ${dest}`);
    }
  }
  return written;
}

function main(argv) {
  const opts = parseArgs(argv);
  if (opts.command === "version") {
    console.log(JSON.parse(readFileSync(join(PACKAGE_ROOT, "package.json"), "utf8")).version);
    return 0;
  }
  if (!opts.command || opts.command === "help") {
    console.log(HELP);
    return opts.command === "help" ? 0 : 2;
  }
  if (opts.command === "list") {
    for (const skill of readSkills()) {
      console.log(`${skill.name}\n  ${skill.description}\n`);
    }
    return 0;
  }
  if (opts.command === "install") {
    const written = install(opts);
    if (!opts.dryRun && written.length) {
      console.log("\nRestart your agent (or start a new session) so it loads the skills.");
      console.log("Scripts and examples read your key from AIMLAPI_API_KEY.");
    }
    return 0;
  }
  throw new UsageError(`unknown command ${opts.command}; use list or install`);
}

// Run only when started as a program (npx and npm link start it through a symlink), not when imported by tests.
const startedAsProgram = (() => {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
})();

if (startedAsProgram) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (err) {
    console.error(`error: ${err.message}`);
    process.exitCode = err instanceof UsageError ? 2 : 1;
  }
}
