from langchain_core.caches import InMemoryCache
from langchain_groq import ChatGroq

cache = InMemoryCache(maxsize= 1000)

def get_llm():
    llm = ChatGroq(
        model="openai/gpt-oss-120b",
        # cache = cache
    )
    return llm

def get_security_llm():
    llm = ChatGroq(
        model="openai/gpt-oss-20b",
        temperature=0,
        timeout=10,
        cache = False
    )
    return llm