# Instructions for agents editing this repository

This repository is public. Everything in it is read by other people's coding agents and copied into their projects.

## Before you change a skill

- Read the skill's `SKILL.md` and the public docs page it links to (append `.md` to any `docs.aimlapi.com` URL).
- Check behaviour against the live API, not memory: `GET https://api.aimlapi.com/v1/models`, the model's `docsJson`, `GET https://api.aimlapi.com/docs-yaml`.
- Follow [CONTRIBUTING.md](CONTRIBUTING.md) § Writing a skill.

## Never add

| What | Why |
| ---- | --- |
| API keys, webhook secrets, tokens (other than the published test vectors in `tests/`) | Public repository |
| Prices, credit rates, per-model parameter lists, lists of models that support a feature | They change; the agent must read them from the API |
| Hosts other than `api.aimlapi.com`, `docs.aimlapi.com`, `mcp.aimlapi.com`, `aimlapi.com`, `cdn.aimlapi.com` | Other hosts are not public |
| Routes that are not in the public API description or `tools/allowed-routes.txt` | Undocumented routes can change without notice |
| Environment variable names of the platform, service names, internal ticket ids, people's names | Not public |
| Promises about latency, uptime or completion time | Not a contract |

`python3 tools/check.py` catches most of these. It is not a substitute for reading your diff.

## Verify

```bash
python3 tools/check.py
python3 -m unittest discover -s tests
node --test 'tests/*.test.mjs'
gh skill publish --dry-run .
```
