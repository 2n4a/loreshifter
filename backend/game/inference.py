import dataclasses
from typing import Literal

from openai import AsyncOpenAI

import config
from game.system import System


@dataclasses.dataclass
class MessageIn:
    role: Literal["user", "developer"]
    content: str
    name: str | None = None


@dataclasses.dataclass
class InferenceEvent:
    ...


@dataclasses.dataclass
class InferenceChunkGenerated(InferenceEvent):
    chunk: str


class LlmChat(System[InferenceEvent]):
    def __init__(self):
        super().__init__()


class OpenaiChat(LlmChat):
    def __init__(self, model: str):
        super().__init__()
        api_key = config.PROXY_API_KEY
        self.client = AsyncOpenAI(api_key=api_key, base_url="https://api.proxyapi.ru/openai/v1/")
        self.messages = []
        self.completion = None

    def add_message(self, message: MessageIn):
        self.messages.extend(message)

    async def complete(self):
        if self.completion is None:
            self.completion = self.client.chat.completions.create(
                model="gpt-5-nano",
                messages=self.messages,
                stream=True,
            )

        async for chunk in self.completion:
            self.emit(InferenceChunkGenerated(chunk.choices[0].delta))

        self.messages.append()




if __name__ == "__main__":
    import dotenv
    dotenv.load_dotenv()

    completion = client.chat.completions.create(
        model="gpt-5-nano",
        messages=[
            {
                "role": "user",
                "content": "Hello, how are you?"
            }
        ],
        stream=True,
    )
    for chunk in completion:
        print(chunk)
