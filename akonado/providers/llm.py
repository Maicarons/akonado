"""OpenAI-compatible LLM provider.

Works with any OpenAI-compatible API (OpenAI, MiMo, DeepSeek, etc.).
Configure via environment variables: LLM_API_KEY, LLM_BASE_URL, LLM_MODEL.
"""

from __future__ import annotations

from ..config import LLM_API_KEY, LLM_BASE_URL, LLM_MODEL
from .base import LLMProvider


class OpenAICompatibleLLM(LLMProvider):
    """LLM provider using the OpenAI chat completions API format."""

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        self._api_key = api_key or LLM_API_KEY
        self._base_url = base_url or LLM_BASE_URL
        self._model = model or LLM_MODEL

    def available(self) -> bool:
        return bool(self._api_key)

    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        if not self.available():
            raise RuntimeError("LLM API key not configured. Set LLM_API_KEY in .env")

        try:
            from openai import OpenAI
        except ImportError:
            raise ImportError("pip install openai")

        client = OpenAI(api_key=self._api_key, base_url=self._base_url)
        resp = client.chat.completions.create(
            model=self._model,
            temperature=temperature,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return resp.choices[0].message.content
