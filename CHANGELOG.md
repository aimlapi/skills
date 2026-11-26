# Changelog

All notable changes to this repository. Versions follow [semver](https://semver.org/): see [CONTRIBUTING.md](CONTRIBUTING.md#releases).

## [Unreleased]

## [1.0.7] - 2026-11-26

### Added

- `.tessl-plugin/plugin.json`: the 13 skills as one plugin, `aimlapi/skills`, in the Tessl registry.

### Fixed

- `aimlapi-webhooks`: creating or rotating the signing secret saves the response to `webhook-secret.json` and prints a masked copy, so the `whsec_` value never reaches the agent's context (Tessl's security review rated the old step Medium).

## [1.0.6] - 2026-11-26

### Fixed

- Examples that static scanners such as Skills Directory read as risky: sample URLs in `job.py` and `speech.py` no longer contain `.../` (read as path traversal), the catalogue check in `aimlapi-protocols` saves the response to a file instead of piping it into `python3`, and `aimlapi-images` sends the catalogue step to `aimlapi-models` and keeps one Python example for generation (a `curl` in the same file as the API key was read as credential exfiltration). Skills Directory's own scan grades these four skills A 100.

## [1.0.5] - 2026-11-24

### Fixed

- Skill READMEs link to the repository by full URL, so the links also work in a copy of one skill.
- `aimlapi-decisions` no longer needs the `aimlapi-sandbox` folder next to it to test a request body: it names the sandbox header.
- `aimlapi-setup`: the links from `references/troubleshooting.md` to `agents.md` point at the right file.

## [1.0.4] - 2026-11-24

### Added

- Codex marketplace file `.agents/plugins/marketplace.json`, so `codex plugin marketplace add aimlapi/skills` and `codex plugin add aimlapi@aimlapi` install the skills straight from this repository.

## [1.0.3] - 2026-11-23

### Added

- Plugin manifests for Codex (`.codex-plugin/plugin.json`) and Antigravity (`.antigravity-plugin/plugin.json`), and an AI/ML API logo (`assets/logo.png`) in the Claude Code, Cursor, Codex and Antigravity manifests.
- Directory listing details in the Claude Code plugin: documentation, support, privacy policy and terms links.
- README: install with Codex and Antigravity, and what the skills do with your key.

### Changed

- The npm installer moved from `bin/` to `cli/`, so the Claude plugin root has no `bin/` folder (claude.ai and Cowork don't install a plugin that has one). `npx @ai-ml.api/skills` works as before.

## [1.0.2] - 2026-11-23

### Added

- Gemini CLI extension: `gemini-extension.json` and `GEMINI.md` at the root, so `gemini extensions install https://github.com/aimlapi/skills` installs the skills and asks for `AIMLAPI_API_KEY` once.
- README: install with Gemini CLI and with `npx skills add aimlapi/skills`.

## [1.0.1] - 2026-11-23

### Fixed

- The npm package is `@ai-ml.api/skills` (AI/ML API's npm organization). Version 1.0.0 was never published to npm: the `@aimlapi` scope is not ours. The install scripts and `npx` commands use the new name.

## [1.0.0] - 2026-11-23

First public release.

### Added

- Skills: `aimlapi-setup`, `aimlapi-models`, `aimlapi-chat`, `aimlapi-protocols`, `aimlapi-images`, `aimlapi-async-jobs`, `aimlapi-speech`, `aimlapi-decisions`, `aimlapi-webhooks`, `aimlapi-batch`, `aimlapi-errors`, `aimlapi-costs`, `aimlapi-sandbox`.
- Standard-library scripts: model catalogue, prices with context bands and live speed (`models.py`), async jobs (`job.py`), speech (`speech.py`), decision model shapes (`decide.py`), sandbox requests (`try.py`), resumable batches (`batch.py`), webhook signature verification in Python and Node.
- npm package `@ai-ml.api/skills` with an installer for Claude Code, Cursor, Codex, Gemini CLI, OpenCode and Copilot.
- Installers without Node.js: `curl -fsSL https://aimlapi.com/skills/install.sh | sh` and `irm https://aimlapi.com/skills/install.ps1 | iex`, from the npm package and sha512-checked.
- Claude Code marketplace and plugin, Cursor plugin and marketplace, Codex cards.
- Repository checks (`tools/check.py`): frontmatter and description form, size budget, banned content and leaked keys, routes against the public API description; `--live` adds routes and model ids against the live API. CI also runs gitleaks and checks the npm package contents.
- Unit tests, live sandbox tests, and agent scenarios with criteria for every skill (`tests/skill-scenarios.md`).
