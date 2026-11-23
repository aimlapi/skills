# AI/ML API Skills

[Agent Skills](https://agentskills.io/specification) that teach coding agents to build on [AI/ML API](https://aimlapi.com): one OpenAI-compatible API for 10,000+ AI models and tools across chat, image, video, music, speech and embeddings.

With them installed, an agent reads models, parameters and prices from the live catalogue instead of guessing, waits on long jobs the way the API expects, retries only what is safe to retry, and tests your code in sandbox mode before it spends anything.

Works with Claude Code, Cursor, Codex, OpenCode, Gemini CLI, Windsurf and any other agent that supports the Agent Skills format.

## Install

### Claude Code

```
/plugin marketplace add aimlapi/skills
/plugin install aimlapi@aimlapi
```

Claude Code updates third-party marketplaces only when you turn it on: `/plugin` → **Marketplaces** → `aimlapi` → auto-update. Otherwise run `/plugin marketplace update aimlapi` to get a new version.

### One command, no Node.js

macOS and Linux:

```bash
curl -fsSL https://aimlapi.com/skills/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://aimlapi.com/skills/install.ps1 | iex
```

Both install every skill into the current repository for Claude Code. They download the `@aimlapi/skills` package from npm and check its sha512 before writing anything. Options go after `sh -s --`, for example `curl -fsSL https://aimlapi.com/skills/install.sh | sh -s -- --agent cursor --scope user aimlapi-models`.

### npm (any agent)

Requires Node.js 18 or later.

```bash
npx @aimlapi/skills install
```

This installs every skill into the current repository for Claude Code. Choose the agent with `--agent cursor` (or `codex`, `gemini`, `opencode`, `copilot`, `universal`), install for every project with `--scope user`, or name the skills you want: `npx @aimlapi/skills install aimlapi-models aimlapi-chat`. Run the same command again to update. `npx @aimlapi/skills list` shows what is in the package.

### GitHub CLI (any agent)

Requires [GitHub CLI](https://cli.github.com/) 2.90 or later.

```bash
gh skill install aimlapi/skills --all --agent claude-code
```

Without `--all` or a skill name, a non-interactive shell only lists the skills. One skill only:

```bash
gh skill install aimlapi/skills aimlapi-async-jobs
```

Add `--scope user` to install for every project, or `--agent cursor` (or `codex`, `opencode`, …) to target one agent.

### Cursor

In **Customize**, add a plugin **From GitHub Repository** with `aimlapi/skills`, then **Install** it for the project or for your user.

### Manual

```bash
git clone --depth 1 https://github.com/aimlapi/skills.git /tmp/aimlapi-skills
cp -r /tmp/aimlapi-skills/skills/* ~/.config/opencode/skills/   # or your agent's skills folder
rm -rf /tmp/aimlapi-skills
```

## Skills

Agents load a skill on their own when your request matches its description.

| Skill | Use it to |
| ----- | --------- |
| [aimlapi-setup](skills/aimlapi-setup/README.md) | Connect a coding agent to AI/ML API with the `aimlapi` CLI, without the agent ever touching your API key |
| [aimlapi-models](skills/aimlapi-models/README.md) | Find, compare and price models from the live catalogue, read the exact parameters a model accepts, and check deprecations |
| [aimlapi-chat](skills/aimlapi-chat/README.md) | Call text models through Chat Completions, Responses or Messages: OpenAI and Anthropic SDKs, streaming, tools, structured output, image, PDF, audio and video input |
| [aimlapi-protocols](skills/aimlapi-protocols/README.md) | Run any chat model through Chat Completions, Responses or Messages: DeepSeek or Gemini behind the Anthropic SDK or Claude Code, Claude behind the Responses API or Codex, and what a translated route does not keep |
| [aimlapi-images](skills/aimlapi-images/README.md) | Generate and edit images |
| [aimlapi-async-jobs](skills/aimlapi-async-jobs/README.md) | Run video and music jobs and background responses: submit, poll, download |
| [aimlapi-speech](skills/aimlapi-speech/README.md) | Text-to-speech and speech-to-text: synthesize audio, transcribe files and URLs |
| [aimlapi-errors](skills/aimlapi-errors/README.md) | Read error responses, decide what to retry and how, and avoid the mistakes that get requests refused |
| [aimlapi-costs](skills/aimlapi-costs/README.md) | Get the cost of each call, trace requests end to end, and report usage and spend |
| [aimlapi-sandbox](skills/aimlapi-sandbox/README.md) | Test an integration for free: live response formats, scripted errors and slow answers |
| [aimlapi-webhooks](skills/aimlapi-webhooks/README.md) | Get async results as signed webhooks instead of polling: signing secret, receiver, signature check, rotation, delivery log |
| [aimlapi-batch](skills/aimlapi-batch/README.md) | Run large chat-completion jobs through the OpenAI-format Batch API at the batch price: JSONL, Files and Uploads, limits, results |
| [aimlapi-decisions](skills/aimlapi-decisions/README.md) | Get typed answers with calibrated probabilities from decision models, and use routers that pick a model per request |

## Requirements

- An AI/ML API key in the `AIMLAPI_API_KEY` environment variable for the scripts and the code the skills write. Create one at [aimlapi.com/app/keys](https://aimlapi.com/app/keys) and set it in your shell or secret store. [`aimlapi-setup`](skills/aimlapi-setup/SKILL.md) is a different thing: it connects the agent itself to AI/ML API models and keeps the key out of the agent's reach, so it does not set `AIMLAPI_API_KEY`.
- Scripts need only `curl`, `python3` (3.9+, standard library) or `node` (18+). Nothing to `npm install` or `pip install`.

The catalogue and deprecation feed need no key.

## How the skills are written

Model lists, prices and per-model parameters change weekly, so no skill copies them. The agent reads them from `GET /v1/models` and the model's `docsJson` when it needs them, and a skill says what to do when the API refuses something rather than listing what it accepts today.

No skill asks for, prints or stores an API key.

CI checks every route a skill names against the public API description and runs the examples in sandbox mode every night. Each skill was also tested on a fresh agent, once without it and once with it: the scenarios and results are in [tests/skill-scenarios.md](tests/skill-scenarios.md).

## Other ways to connect an agent

| Way | Where |
| --- | ----- |
| MCP server (OAuth, no key to paste) | [`https://mcp.aimlapi.com/mcp`](https://docs.aimlapi.com/quickstart/mcp.md) |
| `aimlapi` CLI: configures Claude Code, Codex, OpenCode, Cline and more | [docs](https://docs.aimlapi.com/quickstart/cli.md) |
| Docs for agents | [`llms.txt`](https://docs.aimlapi.com/llms.txt); append `.md` to any docs URL for Markdown |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report a security issue as described in [SECURITY.md](SECURITY.md).

## License

[Apache License 2.0](LICENSE). The license does not grant rights to the AI/ML API name or logo.
