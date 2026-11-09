from typing import Literal

from pydantic import Field, BaseModel


class SecurityAssessment(BaseModel):
    prompt_injection: bool
    harmful_content: bool
    category: str
    severity: Literal[
        "low",
        "medium",
        "high",
        "critical"
    ]
    action: Literal[
        "allow",
        "review",
        "block"
    ]
    confidence: float = Field(
        ge=0.0,
        le=1.0
    )
    reason: str