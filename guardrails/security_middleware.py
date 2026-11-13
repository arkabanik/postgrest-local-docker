from typing import Callable, Awaitable, Any

from langchain.agents.middleware import AgentMiddleware, ModelRequest, ModelResponse, ExtendedModelResponse
from langchain.agents.middleware.types import ResponseT
from langchain_core.messages import BaseMessage, AIMessage, HumanMessage
from langgraph.typing import ContextT

from security.security_classifier import LLMSecurityClassifier


class LLMSecurityMiddleware(AgentMiddleware):

    def __init__(self,security_model):
        super().__init__()
        self.classifier = LLMSecurityClassifier(security_model)

    def extract_text(self, message: BaseMessage) -> str:
        # print(f"Human message: {message}")

        content = message.content
        # print(f"Extracted content: {content}")

        if isinstance(content, str):
            return content

        else:
            # print("Extracted last human message content is not text. Handle it in the code.")
            pass


        return ""

    def extract_latest_human_message(self, messages: list[BaseMessage]) -> str :

        for message in reversed(messages):
            if isinstance(message, HumanMessage):
                return self.extract_text(message)

        return ""


    async def awrap_model_call(self, request: ModelRequest[Any], handler: Callable[[ModelRequest[Any]], Awaitable[ModelResponse[Any]]]):

        user_message = self.extract_latest_human_message(request.messages)

        if not user_message.strip():
            return await handler(request)

        try:

            security_assessment = await self.classifier.classify(user_message)
            # print(f"security assessment: {security_assessment.model_dump()}")

            # read the assessment and pass the request accordingly
            if security_assessment.prompt_injection:
                return AIMessage(
                    content="""Smart ass. I cannot process instructions that attempts to override system instructions
                    or bypass my security policies"""
                )

            if security_assessment.harmful_content:
                if security_assessment.action == "block":
                    return AIMessage(
                        content="""I cannot process this request
                        as it involves potentially unauthorised or harmful request"""
                    )

                if security_assessment.action == "review":
                    return AIMessage(
                        content="Need additional human review before proceeding with this request"
                    )

            if security_assessment.out_of_scope:
                if security_assessment.action == "block":
                    return AIMessage(
                        content="""I cannot process this request
                    as it involves potentially unauthorised or harmful request"""
                    )

            # Pass legitimate requests
            return await handler(request)

        except Exception as e:
            print(f"Exception is : {e}")











