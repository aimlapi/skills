"""The SDK code shown in aimlapi-chat and aimlapi-costs, run in sandbox mode. Skipped unless enabled.

    pip install openai anthropic
    AIMLAPI_LIVE_TESTS=1 AIMLAPI_API_KEY=<sandbox key> python3 -m unittest tests.test_sdk_examples
"""

from __future__ import annotations

import json
import os
import unittest

try:
    import anthropic
    from openai import OpenAI
except ImportError:  # SDKs are optional for the rest of the suite
    OpenAI = anthropic = None

ENABLED = os.environ.get("AIMLAPI_LIVE_TESTS") == "1" and os.environ.get("AIMLAPI_API_KEY") and OpenAI is not None
SANDBOX = {"X-AIMLAPI-Sandbox": "1"}
TOOLS = [{"type": "function", "function": {
    "name": "get_weather", "description": "Current weather for a city",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]},
}}]


@unittest.skipUnless(ENABLED, "set AIMLAPI_LIVE_TESTS=1 and AIMLAPI_API_KEY, and install openai and anthropic")
class OpenAISDK(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = OpenAI(base_url="https://api.aimlapi.com/v1", api_key=os.environ["AIMLAPI_API_KEY"], default_headers=SANDBOX)

    def test_chat(self):
        out = self.client.chat.completions.create(model="openai/gpt-4o-mini", messages=[{"role": "user", "content": "hi"}], max_tokens=50)
        self.assertTrue(out.choices[0].message.content)

    def test_stream_cost_in_last_chunk(self):
        last = None
        for chunk in self.client.chat.completions.create(model="openai/gpt-4o-mini", messages=[{"role": "user", "content": "hi"}], stream=True):
            last = chunk
        self.assertIn("usage", (last.model_extra or {}).get("meta", {}))

    def test_tool_loop(self):
        messages = [{"role": "user", "content": "What's the weather in Lisbon?"}]
        first = self.client.chat.completions.create(model="openai/gpt-4o-mini", messages=messages, tools=TOOLS, max_tokens=300)
        self.assertEqual(first.choices[0].finish_reason, "tool_calls")
        messages.append(first.choices[0].message)
        for call in first.choices[0].message.tool_calls:
            json.loads(call.function.arguments)
            messages.append({"role": "tool", "tool_call_id": call.id, "content": '{"temp_c": 19}'})
        final = self.client.chat.completions.create(model="openai/gpt-4o-mini", messages=messages, tools=TOOLS, max_tokens=300)
        self.assertTrue(final.choices[0].message.content)

    def test_json_schema(self):
        out = self.client.chat.completions.create(
            model="openai/gpt-4o-mini", max_tokens=200,
            messages=[{"role": "user", "content": "Extract the city and date: 'Meet me in Porto on 3 May'"}],
            response_format={"type": "json_schema", "json_schema": {"name": "meeting", "strict": True, "schema": {
                "type": "object", "properties": {"city": {"type": "string"}, "date": {"type": "string"}},
                "required": ["city", "date"], "additionalProperties": False}}},
        )
        self.assertEqual(set(json.loads(out.choices[0].message.content)), {"city", "date"})

    def test_cost_headers(self):
        raw = self.client.chat.completions.with_raw_response.create(
            model="openai/gpt-4o-mini", messages=[{"role": "user", "content": "hi"}], max_tokens=20,
            extra_headers={"X-Client-Request-Id": "order-8f21c4"},
        )
        raw.parse()
        self.assertEqual(raw.headers.get("x-client-request-id"), "order-8f21c4")
        self.assertIsNotNone(raw.headers.get("x-inference-id"))
        self.assertIsNotNone(raw.headers.get("x-aimlapi-usd-spent"))

    def test_embeddings(self):
        out = self.client.embeddings.create(model="openai/text-embedding-3-small", input=["first", "second"])
        self.assertEqual(len(out.data), 2)

    def test_images_extra_body(self):
        out = self.client.images.generate(model="flux/schnell", prompt="a lighthouse", extra_body={"image_size": "landscape_16_9", "num_images": 1})
        self.assertTrue(out.data[0].url)

    def test_responses_background(self):
        out = self.client.responses.create(model="openai/gpt-4o-mini", input="hi", background=True, max_output_tokens=200)
        self.assertIn(out.status, {"queued", "in_progress", "completed"})


@unittest.skipUnless(ENABLED, "set AIMLAPI_LIVE_TESTS=1 and AIMLAPI_API_KEY, and install openai and anthropic")
class AnthropicSDK(unittest.TestCase):
    def test_messages_and_tool_loop(self):
        client = anthropic.Anthropic(base_url="https://api.aimlapi.com", api_key=os.environ["AIMLAPI_API_KEY"], default_headers=SANDBOX)
        tools = [{"name": "get_weather", "description": "Current weather for a city",
                  "input_schema": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}]
        messages = [{"role": "user", "content": "What's the weather in Lisbon?"}]
        first = client.messages.create(model="anthropic/claude-haiku-5-5", max_tokens=300, tools=tools, messages=messages)
        self.assertEqual(first.stop_reason, "tool_use")
        messages.append({"role": "assistant", "content": first.content})
        messages.append({"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": b.id, "content": '{"temp_c": 19}'} for b in first.content if b.type == "tool_use"
        ]})
        final = client.messages.create(model="anthropic/claude-haiku-5-5", max_tokens=300, tools=tools, messages=messages)
        self.assertTrue(final.content[0].text)


if __name__ == "__main__":
    unittest.main()
