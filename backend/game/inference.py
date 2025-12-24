import argparse
import asyncio
import dataclasses
import json
import pathlib
import sys
from typing import Literal, Any

import dotenv
from openai import AsyncOpenAI

ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

dotenv.load_dotenv()

import config
from game.system import System


OPENAI_BASE_URL = "https://api.proxyapi.ru/openai/v1/"
DM_MODEL = config.DM_MODEL
PLAYER_MODEL = config.PLAYER_MODEL
CHARACTER_MODEL = config.CHARACTER_MODEL
DEFAULT_MODEL = PLAYER_MODEL
DEFAULT_PROMPT = "Write one short sentence greeting the players as a dungeon master."


@dataclasses.dataclass
class MessageIn:
    role: Literal["system", "developer", "user", "assistant"]
    content: str
    name: str | None = None

    def to_dict(self) -> dict[str, str]:
        data = {"role": self.role, "content": self.content}
        if self.name:
            data["name"] = self.name
        return data


@dataclasses.dataclass
class InferenceEvent: ...


@dataclasses.dataclass
class InferenceChunkGenerated(InferenceEvent):
    chunk: str


class LlmChat(System[InferenceEvent]):
    def __init__(self, id_: int | None = None):
        super().__init__(id_ if id_ is not None else id(self))


class OpenaiChat(LlmChat):
    def __init__(self, model: str = DEFAULT_MODEL):
        super().__init__()
        if not config.PROXY_API_KEY:
            raise RuntimeError(
                "PROXY_API_KEY is not set. Add it to .env or environment variables."
            )
        self.client = get_openai_client()
        self.model = model
        self.messages: list[dict[str, str]] = []

    def add_message(self, message: MessageIn):
        self.messages.append(message.to_dict())

    async def complete(self) -> str:
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=self.messages,
        )
        content = response.choices[0].message.content or ""
        self.messages.append({"role": "assistant", "content": content})
        return content

    async def stream_complete(self) -> str:
        stream = await self.client.chat.completions.create(
            model=self.model,
            messages=self.messages,
            stream=True,
        )
        parts: list[str] = []
        async for chunk in stream:
            piece = chunk.choices[0].delta.content or ""
            if piece:
                parts.append(piece)
                self.emit(InferenceChunkGenerated(piece))
        content = "".join(parts)
        self.messages.append({"role": "assistant", "content": content})
        return content


_openai_client: AsyncOpenAI | None = None


def get_openai_client() -> AsyncOpenAI:
    global _openai_client
    if _openai_client is None:
        if not config.PROXY_API_KEY:
            raise RuntimeError(
                "PROXY_API_KEY is not set. Add it to .env or environment variables."
            )
        _openai_client = AsyncOpenAI(
            api_key=config.PROXY_API_KEY,
            base_url=OPENAI_BASE_URL,
        )
    return _openai_client


async def create_chat_completion(
    *,
    model: str,
    messages: list[dict[str, str]],
    tools: list[dict[str, Any]] | None = None,
    tool_choice: dict[str, Any] | str | None = None,
    temperature: float = 0.7,
) -> Any:
    client = get_openai_client()
    return await client.chat.completions.create(
        model=model,
        messages=messages,
        tools=tools,
        tool_choice=tool_choice,
        temperature=temperature,
    )


async def create_chat_completion_stream(
    *,
    model: str,
    messages: list[dict[str, str]],
    tools: list[dict[str, Any]] | None = None,
    tool_choice: dict[str, Any] | str | None = None,
    temperature: float = 0.7,
) -> Any:
    client = get_openai_client()
    return await client.chat.completions.create(
        model=model,
        messages=messages,
        tools=tools,
        tool_choice=tool_choice,
        temperature=temperature,
        stream=True,
    )


def extract_tool_call_args(message: Any, name: str) -> dict[str, Any] | None:
    tool_calls = getattr(message, "tool_calls", None) or []
    for tool_call in tool_calls:
        function = getattr(tool_call, "function", None)
        if function is None or function.name != name:
            continue
        try:
            return json.loads(function.arguments)
        except json.JSONDecodeError:
            return None
    return None


def extract_tool_calls(message: Any) -> list[dict[str, Any]]:
    tool_calls = getattr(message, "tool_calls", None) or []
    calls: list[dict[str, Any]] = []
    for tool_call in tool_calls:
        function = getattr(tool_call, "function", None)
        if function is None or not getattr(function, "name", None):
            continue
        raw_args = getattr(function, "arguments", "") or ""
        args: dict[str, Any] = {}
        if raw_args:
            try:
                parsed = json.loads(raw_args)
                if isinstance(parsed, dict):
                    args = parsed
            except json.JSONDecodeError:
                args = {}
        calls.append(
            {
                "id": getattr(tool_call, "id", None),
                "name": function.name,
                "arguments": raw_args,
                "args": args,
            }
        )
    return calls


CHARACTER_PROFILE_TOOL = {
    "type": "function",
    "function": {
        "name": "submit_character_profile",
        "description": "Finalize the character profile when all fields are known.",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "concept": {"type": "string"},
                "strength": {"type": "integer"},
                "dexterity": {"type": "integer"},
                "intelligence": {"type": "integer"},
                "lore": {"type": "string"},
            },
            "required": [
                "name",
                "concept",
                "strength",
                "dexterity",
                "intelligence",
                "lore",
            ],
        },
    },
}

DM_RESOLVE_TOOL = {
    "type": "function",
    "function": {
        "name": "resolve_turn",
        "description": "Return world updates and per-player consequences.",
        "parameters": {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "world_update": {
                    "type": "object",
                    "properties": {
                        "scene": {"type": "string"},
                        "location": {"type": "string"},
                        "threat": {"type": "integer"},
                        "npcs": {"type": "array", "items": {"type": "string"}},
                    },
                },
                "player_consequences": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "player_id": {"type": "integer"},
                            "text": {"type": "string"},
                        },
                        "required": ["player_id", "text"],
                    },
                },
            },
            "required": ["summary", "player_consequences"],
        },
    },
}

ADVICE_ASK_DM_TOOL = {
    "type": "function",
    "function": {
        "name": "ask_dm",
        "description": "Ask the Dungeon Master a question about the world or situation.",
        "parameters": {
            "type": "object",
            "properties": {
                "question": {"type": "string"},
            },
            "required": ["question"],
        },
    },
}


async def send_test_prompt(prompt: str, model: str) -> str:
    chat = OpenaiChat(model=model)
    chat.add_message(MessageIn(role="user", content=prompt))
    return await chat.complete()


def _parse_args():
    parser = argparse.ArgumentParser(
        description="Send a test prompt to the proxy OpenAI API."
    )
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    return parser.parse_args()


async def main():
    args = _parse_args()
    print(f"Prompt: {args.prompt}")
    response = await send_test_prompt(args.prompt, args.model)
    print("Response:")
    print(response)


if __name__ == "__main__":
    asyncio.run(main())
