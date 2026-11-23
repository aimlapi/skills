# Changelog

All notable changes to this repository. Versions follow [semver](https://semver.org/): see [CONTRIBUTING.md](CONTRIBUTING.md#releases).

## [Unreleased]

## [1.0.0] - 2026-11-23

First public release.

### Added

- Skills: `aimlapi-setup`, `aimlapi-models`, `aimlapi-chat`, `aimlapi-protocols`, `aimlapi-images`, `aimlapi-async-jobs`, `aimlapi-speech`, `aimlapi-decisions`, `aimlapi-webhooks`, `aimlapi-batch`, `aimlapi-errors`, `aimlapi-costs`, `aimlapi-sandbox`.
- Standard-library scripts: model catalogue, prices with context bands and live speed (`models.py`), async jobs (`job.py`), speech (`speech.py`), decision model shapes (`decide.py`), sandbox requests (`try.py`), resumable batches (`batch.py`), webhook signature verification in Python and Node.
- npm package `@aimlapi/skills` with an installer for Claude Code, Cursor, Codex, Gemini CLI, OpenCode and Copilot.
- Installers without Node.js: `curl -fsSL https://aimlapi.com/skills/install.sh | sh` and `irm https://aimlapi.com/skills/install.ps1 | iex`, from the npm package and sha512-checked.
- Claude Code marketplace and plugin, Cursor plugin and marketplace, Codex cards.
- Repository checks (`tools/check.py`): frontmatter and description form, size budget, banned content and leaked keys, routes against the public API description; `--live` adds routes and model ids against the live API. CI also runs gitleaks and checks the npm package contents.
- Unit tests, live sandbox tests, and agent scenarios with criteria for every skill (`tests/skill-scenarios.md`).
