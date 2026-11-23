# AI/ML API skills

This extension adds skills for building on AI/ML API (https://api.aimlapi.com), an OpenAI-compatible API for many model providers. Load the matching skill from `skills/` before writing code that calls AI/ML API: `aimlapi-models` to pick a model, read its parameters and price, then the skill for the job (`aimlapi-chat`, `aimlapi-images`, `aimlapi-async-jobs`, `aimlapi-speech`, `aimlapi-batch` and others).

- Read model ids, parameters and prices from the live catalogue (`GET /v1/models`), never from memory.
- The API key comes from the `AIMLAPI_API_KEY` environment variable. Never print it, write it into files, or put it on a command line.
- Test new code for free in sandbox mode first (`aimlapi-sandbox`).
