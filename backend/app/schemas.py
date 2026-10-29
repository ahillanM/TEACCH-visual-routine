"""API contracts. Field names are camelCase to match the Flutter models."""
from typing import Literal

from pydantic import BaseModel, Field

Category = Literal["BBW_TRAINING", "RESIDENTIAL", "BREAK", "PERSONAL"]

# Same colours as lib/models/schedule_item.dart
CATEGORY_COLORS: dict[str, int] = {
    "BBW_TRAINING": 0xFF2B6CB0,
    "BREAK": 0xFFDD6B20,
    "RESIDENTIAL": 0xFF2F855A,
    "PERSONAL": 0xFF805AD5,
}


class ExistingItem(BaseModel):
    """Already-scheduled item the client wants conflict-checked (optional)."""
    title: str = ""
    date: str | None = None  # YYYY-MM-DD
    startTime: str | None = None  # HH:MM
    endTime: str | None = None


class GenerateRoutineRequest(BaseModel):
    instruction: str = Field(min_length=1)
    referenceDate: str | None = None  # YYYY-MM-DD "today" used to resolve "tomorrow"; default server today
    requesterRole: Literal["participant", "staff"] = "participant"
    participantId: str | None = None  # opaque, fictional in the hackathon; echoed back
    existingItems: list[ExistingItem] = Field(default_factory=list, max_length=100)


class SubStepOut(BaseModel):
    title: str
    durationMin: int | None = None  # null = not specified (never invented)
    isDone: bool = False


class ProposedItem(BaseModel):
    """ScheduleItem-compatible, plus structured times."""
    id: str
    title: str
    category: Category
    colorHex: int
    date: str | None = None
    startTime: str | None = None
    endTime: str | None = None
    timeRange: str  # "HH:MM - HH:MM" | "HH:MM" | "" (unknown)
    locationName: str = ""
    staffName: str = ""
    pictogramUrl: str = ""
    pictogramKeyword: str | None = None  # Flutter may resolve via ARASAAC search
    createdByStaff: bool
    isModifiedAlert: bool = False
    isCompleted: bool = False
    subSteps: list[SubStepOut] = Field(default_factory=list)


class Issue(BaseModel):
    severity: Literal["error", "warning", "info"]
    code: str
    message: str
    itemIndex: int | None = None


class RoutineProposal(BaseModel):
    proposalId: str
    status: Literal["draft"] = "draft"  # AI output is never published
    requiresApproval: Literal[True] = True
    source: Literal["text", "speech"]
    participantId: str | None = None
    date: str | None = None
    items: list[ProposedItem]
    issues: list[Issue]
    missingInformation: list[str]
    valid: bool  # false => at least one error issue; must be fixed before approval
    model: str


class TranscribeResponse(BaseModel):
    transcript: str
    language: str | None = None
    durationSec: float | None = None


class SpeechToRoutineResponse(BaseModel):
    transcript: str
    language: str | None = None
    proposal: RoutineProposal
