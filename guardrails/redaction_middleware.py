import re
from typing import Any, Callable, Awaitable

from langchain.agents import create_agent
from langchain.agents.middleware import AgentMiddleware, ModelRequest, ModelResponse
from langchain_core.messages import BaseMessage, ToolMessage, SystemMessage, HumanMessage, AnyMessage
from langgraph.prebuilt.tool_node import ToolCallRequest
from langgraph.types import Command

from llm.llm import get_llm


class RedactionAgentMiddleware(AgentMiddleware):
    def __init__(self):
        super().__init__()
        # Pre-compile multi regex pattern
        self.customer_regex = re.compile(r"\b(?:CUS|CUST|CUSTOMER)[-_]?\d{4,12}\b", re.IGNORECASE)
        self.order_regex = re.compile(r"\b(?:ORD|ORDER)[-_]?\d{4,12}\b", re.IGNORECASE)

    def redact_value(self, value: Any) -> Any:
        if isinstance(value, str):
            return self.customer_regex.sub("[CUSTOMER_ID]", value)

        if isinstance(value, list):
            return [
                self.redact_value(v) for v in value
            ]

        if isinstance(value, dict):
            return {
                k: self.redact_value(v) for k, v in value.items()
            }

        if isinstance(value, tuple):
            return tuple(
                self.redact_value(v) for v in value
            )

        return value

    def redact_message(self, message:BaseMessage):
        return message.model_copy(
            update={
                "content": self.redact_value(
                    message.content
                )
            }
        )


    async def awrap_model_call(self, request: ModelRequest[Any], handler: Callable[[ModelRequest[Any]], Awaitable[ModelResponse[Any]]] ):

        print(f"wrap_model_call() called here")
        # Before Model Call: Redact sensitive information from the request

        # sanitized_messages = [self.redact_message(message) for message in request.messages]
        sanitized_messages = [
            # AnyMessage(
            #     content=self.redact_message(message) for message in request.messages
            # )
            self.redact_message(message) for message in request.messages
        ]
        # request.system_message is already a SystemMessage (or None) — redact its
        # content, don't wrap the message object inside another SystemMessage.

        sanitized_system_message = (
            self.redact_message(request.system_message)
            if request.system_message is not None
            else None
        )

        sanitized_request = request.override(
            messages=sanitized_messages,
            system_message=sanitized_system_message
        )

        return await handler(sanitized_request)

    async def awrap_tool_call(self, request: ToolCallRequest, handler: Callable[[ToolCallRequest], Awaitable[ToolMessage]] ):
        print(f"wrap_tool_call() called here")
        return await handler(request)
