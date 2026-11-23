# Contributing

Thanks for helping agents use AI/ML API well. Fixes to wrong or unclear instructions are the most valuable contribution: if a skill led your agent astray, open an issue with the prompt you gave and what the agent did.

## Layout

```
skills/<name>/
├── SKILL.md            # what the agent reads: frontmatter + instructions, under 300 lines
├── README.md           # for people: what it covers, how to install it
├── references/*.md     # detail the agent loads only when needed
├── scripts/            # runnable helpers, standard library only
└── agents/openai.yaml  # display card for Codex
preview/<name>/         # same shape; not installed until the feature ships
tools/                  # repository checks
tests/                  # unit tests for scripts
```

## Writing a skill

- [ ] `name` in the frontmatter equals the folder name, starts with `aimlapi-`, and uses `a-z`, `0-9` and `-` only.
- [ ] `description` says what the skill does **and** when to use it, with the words a user would type (under 1024 characters).
- [ ] `license: Apache-2.0` and `metadata.version` equal to the repository version.
- [ ] Sections in this order: `## When to use`, `## Steps`, `## Rules`, `## Errors`, `## Check before done`, `## Reference`.
- [ ] Every request example uses `https://api.aimlapi.com` and reads the key from `AIMLAPI_API_KEY`.
- [ ] No prices, model lists, per-model parameter lists, or limits that are not on a public docs page. Tell the agent where to read them at run time instead.
- [ ] Every route you name is in the public API description or in [`tools/allowed-routes.txt`](tools/allowed-routes.txt) with a link to the docs page that documents it.
- [ ] Model ids in examples exist in `GET /v1/models` today.
- [ ] Scripts use the standard library only, read the key from the environment, never print it, and send `x-aimlapi-client: aimlapi-skills/<version>`.

## Checks

Run before opening a pull request:

```bash
python3 tools/check.py          # frontmatter, structure, banned content, routes
python3 -m unittest discover -s tests
node --test 'tests/*.test.mjs'
gh skill publish --dry-run .    # the parser `gh skill install` uses
```

CI runs the same checks on every pull request, and every night it also checks routes and model ids against the live API and runs the examples in sandbox mode.

## Pull requests

- One skill or one concern per pull request.
- Sign off your commits (`git commit -s`): we use the [Developer Certificate of Origin](https://developercertificate.org/).
- A maintainer from [CODEOWNERS](.github/CODEOWNERS) reviews every change; changes to a skill about a specific feature are also reviewed by that feature's owner.

## Releases

One version for the whole repository (semver), kept in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json`, `package.json` and each `metadata.version`. `python3 tools/check.py` fails if they differ.

- **major**: a skill renamed or removed
- **minor**: a new skill or a new section
- **patch**: wording and fixes

Move a skill out of `preview/` only after its feature is live for every customer. Tag `vX.Y.Z` on `main` and add the entry to [CHANGELOG.md](CHANGELOG.md); the release workflow creates the GitHub release (with `install/install.sh` and `install/install.ps1` attached; aimlapi.com/skills/install.* serves them) and publishes `@aimlapi/skills` to npm with provenance (it needs the `NPM_TOKEN` secret and a public repository).
