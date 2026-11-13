import os

from langchain_core.globals import set_llm_cache
from langchain_redis import RedisCache

def configure_llm_cache():
    redis_cache = RedisCache(
        redis_url=os.getenv("REDIS_URL", "redis://localhost:6379"),
        ttl=3600,
        prefix="abeg_exact_cache"
    )

    set_llm_cache(redis_cache)
    return redis_cache




