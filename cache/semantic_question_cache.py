import os
import re

from langchain_core.outputs import Generation
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_redis import RedisSemanticCache

CACHE_VERSION = "_v1"

class QuestionCache:
    """Caches the agent's FINAL answer, keyed by the user's question only.

    Not registered with set_llm_cache, so it never touches the agent's internal model calls.
    """

    def __init__(self, distance_threshold: float | int = 0.2, ttl: int = 300):
        self._cache = RedisSemanticCache(
            embeddings=HuggingFaceEmbeddings(model="sentence-transformers/all-MiniLM-L6-v2"),
            redis_url=os.getenv("REDIS_URL", "redis://localhost:6379"),
            distance_threshold=distance_threshold,
            ttl=ttl,
            prefix="abeg_question_cache"
        )

    @staticmethod
    def _normalize(question: str) -> str:
        return " ".join(question.lower().split())

    @staticmethod
    def _namespace(question: str) -> str:
        ids = ",".join(sorted(re.findall(r"\d+", question)))
        return f"agent-answer:{CACHE_VERSION}:ids={ids}"

    async def get(self, question: str) -> str | None:
        normalized_q = self._normalize(question)
        hit = await self._cache.alookup(prompt=normalized_q, llm_string=self._namespace(question))
        if hit:
            print(f"Hit: {hit}")
        else:
            print("Not hits in cache")

        return hit[0].text if hit else None

    async def put(self, question: str, answer: str):
        normalized_q = self._normalize(question)
        await self._cache.aupdate(prompt=normalized_q, llm_string=self._namespace(question), return_val = [Generation(text=answer)])











