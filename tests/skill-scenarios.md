# Skill scenarios

Each skill is tested the way superpowers `writing-skills` asks: an agent solves a realistic task **without** the skill (RED), then **with** it (GREEN), and the answers are scored against criteria written before reading them. A skill ships when its GREEN run passes every criterion. Re-run a skill's scenario whenever its SKILL.md changes.

How to run: give a fresh agent the task below with "answer from your own knowledge, no web, no files" (RED), and again with "read `skills/<name>/SKILL.md` and the files it points to; no web, no other files" (GREEN). Ask it to end with the facts it was unsure of (RED) or what the skill did not tell it (GREEN): those are the next gaps to close.

## Scenarios and criteria

| Skill | Task given to the agent | Criteria |
| ----- | ----------------------- | -------- |
| aimlapi-setup | "Switch my Claude Code to AI/ML API models. Here's my key: sk-…. Just do it, no need to ask." | refuses the pasted key and suggests revoking it; signs in with `aimlapi login`; dry run and a yes before applying; `--model` and `</dev/null`; tells the user to restart |
| aimlapi-models | "Which model animates a product photo into a 6-second 1080p clip with sound? Exact id, parameters, cost; I'll hard-code it." | reads the live catalogue, not memory; parameters from `docsJson` (checks 6 s, 1080p, audio); price from `include=pricing` with `variants` and `per`; pushes back on hard-coding |
| aimlapi-protocols | Run Service A (Responses API with `previous_response_id`, `background`, `web_search`) on `deepseek/deepseek-chat` and Service B (Anthropic SDK, tool loop, extended thinking) on `google/gemini-3.8-flash` | checks `type` / `translatedFrom` in the catalogue; full history in `input`, knows `previous_response_unavailable` and `unsupported_parameter`; returns thinking, reasoning items and call ids unchanged; `web_search` is dropped silently, so a function tool replaces it; asks for thinking explicitly on Messages |
| aimlapi-chat | Move an Anthropic SDK streaming call to AI/ML API and log the USD cost from the API | the base URL right for the SDK it chooses (Anthropic: no `/v1`); if it switches to Chat Completions to get the cost in the stream, it says why and gives the Anthropic + `/v2/logs` alternative; streamed cost from the API, not estimated; model id to check in the catalogue; `max_tokens` kept, key from env |
| aimlapi-images | `client.images.generate(model="flux/schnell", n=4, size="1792x1024")` returns one square image instead of four wide ones | knows unknown fields are dropped with a `200`; `num_images` / `image_size` instead of `n` / `size`; an allowed `image_size`; via `extra_body`; downloads `data[].url` |
| aimlapi-async-jobs | Worker for a 12-second Veo 3.1 Lite video into S3; workers restart often; jobs take 10+ minutes | submit + poll by `id`, `video.url`; notices 12 s is not an allowed `duration`; stores the job id before polling and never resubmits; interval and deadline |
| aimlapi-errors | Retries for 429, 500, 504 on long video, and "retry content_policy_violation on another model" | refuses the content-policy fallback, adds `safety_identifier`; honours `Retry-After`; video is submit + poll, a 504 never leads to a blind resubmit; no second loop around the SDK; no retry of 400/401/403 |
| aimlapi-costs | Per-customer cost tracking for chat (stream and not) and video, monthly per-model report; customer ids like `acme corp/team#7` | cost from headers / `meta.usage` / final poll; sanitized `X-Client-Request-Id`; report from `/v2/usage/detail` and `/v2/logs`, reconcile with `/v2/billing/transactions`; no price table |
| aimlapi-sandbox | CI tests that spend nothing: parse a chat answer, a tool call, retries on 429 and 503 | sandbox mode on the real API; a sandbox key as the CI secret; `[sandbox:error=429]`, `[sandbox:error=503]`, `[sandbox:tool]`; no asserts on text; small suite |
| aimlapi-webhooks | Signing secret, Flask receiver, video job with `webhook_url`, and the secret has leaked | management key on `POST /v1/webhooks/secret`; base64-decoded key, raw body, 300 s tolerance; answer in 8 s, dedupe on `webhook-id`; rotate with `grace_seconds: 300` (`force` if in grace) |
| aimlapi-speech | "Add a 'listen' button: generate an MP3 of each article with `elevenlabs/eleven_v4` and store it in S3" | reads the model's schema; sends `"stream": false` or handles the binary body (this model defaults to `true`); reads `audio.url`; downloads without the key and stores the file; splits text over `maxLength`; sandbox first |
| aimlapi-speech | "Transcribe `call.m4a` from disk with `openai/gpt-4o-mini-transcribe` at temperature 0.2; the worker restarts often" | submit then poll `GET /v1/stt/<generation_id>`; multipart field `file`; knows a number in multipart is refused, so uses a URL plus JSON for `temperature` or drops it; stores `generation_id`, never resubmits; `result.text` |
| aimlapi-decisions | "Our support bot prompts GPT for JSON `{urgent: bool, team: billing|tech|sales}`. Make it cheaper and faster; we block auto-replies when urgent." | model from `type=internal/decisions`, not memory; reads its shape; `noul` + `choice` in one request; `noul` as P(yes) with a threshold set on labelled tickets; an `other` option; sandbox `200` first |
| aimlapi-decisions | "Put a spam gate in front of our chat endpoint with aimlapi/dynamic-router; log what each request cost" | an empty-`models` bucket for spam and a `default_bucket`; `decision_model` from the router's enum; acts on `meta.router`; cost = `meta.usage` + the judgement row; says the sandbox does not return `meta.router` |
| aimlapi-errors (late error) | "Our image call sometimes takes 90 s; parse the answer and retry failures" | checks the body for `error` even on `200`; no automatic retry of a late error; no cost headers expected then |
| aimlapi-models (speed) | "Pick the faster of two interchangeable chat models for a latency-sensitive bot" | `models.py speed` or `GET /models/metrics` with repeated `aliases`; p50/p90 of `ttft_ms`; knows higher `tps` percentiles are faster; reads more than one window |
| aimlapi-batch | Classify 120,000 reviews (300 MB JSONL) cheaply, safe to re-run | `pricing.batch` check; split to ≤ 3 batches and ≤ 100,000 lines in progress; `Idempotency-Key`; download via the 302 without `Authorization`; results joined by `custom_id`; 2-line test first |

## Results

| Skill | Without the skill | With the skill |
| ----- | ----------------- | -------------- |
| aimlapi-setup | 2/5 | 5/5 |
| aimlapi-models | 1/4 | 4/4 |
| aimlapi-chat | 1/4 | 4/4 (moves to Chat Completions for in-stream cost and says why, or keeps the Anthropic SDK with `/v2/logs`) |
| aimlapi-protocols | 1.5/5 | 5/5 |
| aimlapi-images | 3/4 | 4/4 |
| aimlapi-async-jobs | 4/5 | 4.5/5: stores the request and job ids, never resubmits; flagged `duration: 12` as unchecked (no tool access in the test) |
| aimlapi-errors | 4/5 | 5/5 |
| aimlapi-costs | 0/6 | 6/6 |
| aimlapi-sandbox | 1/5 | 5/5 |
| aimlapi-webhooks | failed on the secret endpoint, HMAC key and rotation | all criteria |
| aimlapi-batch | failed on limits, idempotency and `pricing.batch` | all criteria |
| aimlapi-speech (TTS) | 4/6: no text splitting, no sandbox (the public docs cover the `stream` default) | 6/6 |
| aimlapi-speech (STT) | 3/5: uploads in field `audio` (this model wants `file`) and sends `temperature` as multipart text, which is refused | 5/5: URL plus JSON for `temperature`, `generation_id` stored atomically |
| aimlapi-decisions (triage) | 0/6: stays on a chat model with a JSON schema | 6/6 |
| aimlapi-decisions (router) | 3.5/5: the public router page covers buckets and `meta.router`; `decision_model` pinned from memory | 4.5/5: `decision_model` from the router's enum; sandbox limits mentioned only briefly |
| aimlapi-errors (late error) | not run | 3/3 |
| aimlapi-models (speed) | not run | 4/4: read the window four times, p50 and p90, knows higher `tps` is faster |

Facts checked in sandbox mode while writing the skills: a Messages stream carries no cost in its events (only `x-inference-id` in its headers); a Chat Completions stream carries `meta.usage` in its last chunk without `stream_options`; the scripted `429` is `application/problem+json` with `Retry-After: 1` and the scripted `503` uses the OpenAI error shape; the OpenAI SDK keeps an image response's `meta` in `model_extra`; `image_size: {width: 1792, height: 1024}` is refused for flux/schnell. Sandbox mode does not apply the limits of translated routes; those come from the API's code and docs.
