import time
from pathlib import Path

from langchain.agents import create_agent
from langchain.agents.middleware import PIIMiddleware
from langchain.mcp import MCPAdapter
from langchain_core.decisions import Question
from langchain_core.messages import ToolMessage

from cache.llm_cache import configure_llm_cache
from cache.semantic_cache import configure_semantic_cache
from cache.semantic_question_cache import QuestionCache
from guardrails.redaction_middleware import RedactionAgentMiddleware
from guardrails.security_middleware import LLMSecurityMiddleware
from llm.llm import get_llm, get_security_llm
from system_prompt import SYSTEM_PROMPT


async def run():

    # Modern MCP Configuration Dictionary Structure
    # Note: Transport key is no longer needed; it is inferred automatically from 'command'
    print("Connecting to local MCP server via stdio transport...")
    # Load tools dynamically from the running MCP server
    # This automatically manages the async stdio connection lifetime
    # Use MCPAdapter context manager to automatically start/stop the server
    async with MCPAdapter(Path(__file__).parent.parent / "server.py") as adapter:
        try:
            # Retrieve tools using the modern API method
            mcp_tools = await adapter.list_tools()
            print(f"Successfully loaded {len(mcp_tools)} tools from MCP server.")

            for tool in mcp_tools:
                print(f"{tool.name} : {tool.description}")

        except Exception as e:
            print(f"Failed to extract tools from adapter: {e}")
            return

    # configure_llm_cache()
    question_semantic_cache = QuestionCache(0.2, 60)
    agent = create_agent(
        model = get_llm(),
        tools = mcp_tools,
        middleware = [
            LLMSecurityMiddleware(get_security_llm()),
            PIIMiddleware("email", strategy="redact", apply_to_input=True, apply_to_output=True, apply_to_tool_results=True),
            PIIMiddleware("credit_card",strategy="mask", apply_to_input=True, apply_to_output=True, apply_to_tool_results=True),
            RedactionAgentMiddleware()
        ],
        system_prompt = SYSTEM_PROMPT
    )

    # bot_chain = get_chain(mcp_tools)

    while True:
        user_query = input("Enter your query (or type 'exit' to quit): ")

        if user_query.lower() == 'exit' or user_query.lower() == 'quit':
            return

        try:
            #Look up cache to check if we have answered anything like this before?
            start_time = time.perf_counter()
            cached_answer = await question_semantic_cache.get(user_query)
            if cached_answer:
                time_taken = time.perf_counter() - start_time
                print(f"Time taken to process the query: {time_taken:.2f} seconds")
                print(f"Response: {cached_answer}")
                continue

            # If no cache hit, run the full agent
            start_time = time.perf_counter()
            response = await agent.ainvoke({"messages": [
                ("human", user_query)
            ]})
            time_taken = time.perf_counter() - start_time
            print(f"Time taken to process the query: {time_taken:.2f} seconds")
            result = response["messages"][-1].content
            print(f"Response: {result}")

            tool_used = any(isinstance(m, ToolMessage) for m in response["messages"])

            if tool_used and isinstance(result, str) and result.strip():
                await question_semantic_cache.put(user_query, result)

            # await question_semantic_cache.put(user_query, response['messages'][-1].content)
        except Exception as e:
            print(f"Error: {e}")



