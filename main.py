import asyncio
import os
from dotenv import load_dotenv

from agent.agent import run

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

async def main():
    print("Hello from agentic-postgrest-query!")
    # Define the local MCP server command

    await run()

if __name__ == "__main__":
    asyncio.run(main())
