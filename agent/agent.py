from pathlib import Path

from langchain.agents import create_agent
from langchain.agents.middleware import PIIMiddleware
from langchain.mcp import MCPAdapter

from guardrails.redaction_middleware import RedactionAgentMiddleware
from llm.llm import get_llm
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

    agent = create_agent(
        model = get_llm(),
        tools = mcp_tools,
        middleware = [
            PIIMiddleware("email", strategy="redact", apply_to_input=True, apply_to_output=True, apply_to_tool_results=True),
            PIIMiddleware("credit_card",strategy="mask", apply_to_input=True, apply_to_output=True, apply_to_tool_results=True),
            RedactionAgentMiddleware()
        ],
        system_prompt = SYSTEM_PROMPT
    )

    # bot_chain = get_chain(mcp_tools)

    while True:
        user_query = input("Enter your query (or type 'exit' to quit): ")

        if user_query.lower() == 'exit':
            return

        try:
            # response = bot_chain.invoke({"user_input": user_query})
            response = await agent.ainvoke({"messages": [
                ("human", user_query)
            ]})
            print(f"Response: {response['messages'][-1].content}")
        except Exception as e:
            print(f"Error: {e}")



