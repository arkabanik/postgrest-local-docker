from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.globals import set_llm_cache
from langchain_redis import RedisSemanticCache
import os


def configure_semantic_cache():

    embeddings = HuggingFaceEmbeddings(
        model="sentence-transformers/all-MiniLM-L6-v2"
    )

    redis_cache = RedisSemanticCache(
        embeddings=embeddings,
        redis_url=os.getenv("REDIS_URL", "redis://localhost:6379"),
        ttl=3600,
        prefix="abeg_semantic_cache"
    )

    set_llm_cache(redis_cache)
    return redis_cache
