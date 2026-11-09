from typing import Callable, Awaitable, Any

from langchain.agents.middleware import AgentMiddleware, ModelRequest, ModelResponse, ExtendedModelResponse
from langchain.agents.middleware.types import ResponseT
from langchain_core.messages import BaseMessage, AIMessage
from langgraph.typing import ContextT

from security.security_classifier import LLMSecurityClassifier


class LLMSecurityMiddleware(AgentMiddleware):

    def __init__(self,security_model):
        super().__init__()
        self.classifier = LLMSecurityClassifier(security_model)

    def extract_text(self, message: BaseMessage) -> str:
        pass

    def extract_latest_human_message(self, messages: list[BaseMessage]):
        pass

    async def awrap_model_call(self, request: ModelRequest[Any], handler: Callable[[ModelRequest[Any]], Awaitable[ModelResponse[Any]]]):
        user_message = self.extract_latest_human_message(request.messages)

        if not user_message.strip():
            return await handler(request)

        try:

            security_assessment = self.classifier.classify(user_message)

            







