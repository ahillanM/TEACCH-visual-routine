"""Deterministic validation of model output. The LLM is never trusted for correctness."""
import re
import uuid
from datetime import date as Date

from pydantic import BaseModel, Field

from .schemas import (CATEGORY_COLORS, ExistingItem, GenerateRoutineRequest, Issue,
                      ProposedItem, RoutineProposal, SubStepOut)

MAX_ITEMS = 20
MAX_SUBSTEPS = 10
MAX_TITLE = 80
# Anything that tries to act on data rather than describe an activity is rejected.
FORBIDDEN_KEYS = {"action", "actions", "publish", "published", "delete", "approve", "approved",
                  "status", "assign", "assignto", "sql", "userid", "role", "send", "notify"}


class LLMSubStep(BaseModel):
    title: str = ""
    durationMin: int | None = None


class LLMItem(BaseModel):
    title: str = ""
    date: str | None = None
    startTime: str | None = None
    endTime: str | None = None
    category: str | None = None
    pictogramKeyword: str | None = None
    subSteps: list[LLMSubStep] = Field(default_factory=list)


class LLMOutput(BaseModel):
    items: list[LLMItem]
    missingInformation: list[str] = Field(default_factory=list)
    unsupportedRequests: list[str] = Field(default_factory=list)


def parse_llm_output(raw: dict) -> LLMOutput:
    """Raises pydantic.ValidationError on a malformed structure."""
    return LLMOutput.model_validate(raw)


def _norm_time(value: str | None) -> tuple[str | None, bool]:
    """Returns (HH:MM or None, was_invalid). Accepts H:MM and normalises it."""
    if value is None or value == "":
        return None, False
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", value.strip())
    if not m or int(m[1]) > 23 or int(m[2]) > 59:
        return None, True
    return f"{int(m[1]):02d}:{m[2]}", False


def _norm_date(value: str | None) -> tuple[str | None, bool]:
    if value is None or value == "":
        return None, False
    try:
        return Date.fromisoformat(value.strip()).isoformat(), False
    except ValueError:
        return None, True


def _minutes(t: str) -> int:
    return int(t[:2]) * 60 + int(t[3:])


def _forbidden_keys(node, path="") -> list[str]:
    found = []
    if isinstance(node, dict):
        for k, v in node.items():
            if str(k).lower() in FORBIDDEN_KEYS:
                found.append(f"{path}{k}")
            found += _forbidden_keys(v, f"{path}{k}.")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            found += _forbidden_keys(v, f"{path}{i}.")
    return found


def _time_range(start: str | None, end: str | None) -> str:
    if start and end:
        return f"{start} - {end}"
    return start or ""


def _overlaps(a_start, a_end, b_start, b_end) -> bool:
    return _minutes(a_start) < _minutes(b_end) and _minutes(b_start) < _minutes(a_end)


def _existing_times(e: ExistingItem):
    s, bad_s = _norm_time(e.startTime)
    en, bad_e = _norm_time(e.endTime)
    d, bad_d = _norm_date(e.date)
    return s, en, d, (bad_s or bad_e or bad_d)


def build_proposal(raw: dict, req: GenerateRoutineRequest, source: str, model: str) -> RoutineProposal:
    """raw must already satisfy parse_llm_output."""
    out = parse_llm_output(raw)
    issues: list[Issue] = []

    def add(sev, code, msg, idx=None):
        issues.append(Issue(severity=sev, code=code, message=msg, itemIndex=idx))

    for key in _forbidden_keys(raw):
        add("error", "unsupported_action", f"Model output contained unsupported field '{key}'; ignored.")
    for text in out.unsupportedRequests:
        add("warning", "unsupported_request",
            f"This request is not supported by the planner and was ignored: {text[:120]}")

    llm_items = out.items
    if not llm_items:
        add("error", "no_activities", "No activities could be extracted from the instruction.")
    if len(llm_items) > MAX_ITEMS:
        add("error", "too_many_items", f"More than {MAX_ITEMS} activities; extra ones were dropped.")
        llm_items = llm_items[:MAX_ITEMS]

    items: list[ProposedItem] = []
    for i, it in enumerate(llm_items):
        title = it.title.strip()
        if not title:
            add("error", "missing_title", "Activity has no title.", i)
            title = "(untitled)"
        if len(title) > MAX_TITLE:
            add("warning", "title_truncated", f"Title longer than {MAX_TITLE} characters; shortened.", i)
            title = title[:MAX_TITLE]

        start, bad_s = _norm_time(it.startTime)
        end, bad_e = _norm_time(it.endTime)
        d, bad_d = _norm_date(it.date)
        if bad_s or bad_e:
            add("error", "invalid_time", "Time is not a valid HH:MM value; cleared.", i)
        if bad_d:
            add("error", "invalid_date", "Date is not a valid YYYY-MM-DD value; cleared.", i)
        if end and not start:
            add("warning", "end_without_start", "End time given without a start time; end cleared.", i)
            end = None
        if start and end and _minutes(end) <= _minutes(start):
            add("error", "invalid_range", "End time must be after start time.", i)
        if not start and not (bad_s or bad_e):
            add("info", "missing_time", "No time was given for this activity.", i)
        elif start and not end:
            add("info", "missing_end_time", "No end time or duration was given.", i)

        category = (it.category or "").strip().upper()
        if it.category and category not in CATEGORY_COLORS:
            add("info", "category_defaulted", f"Unknown category '{it.category[:30]}'; set to PERSONAL.", i)
        if category not in CATEGORY_COLORS:
            category = "PERSONAL"

        steps = [s for s in it.subSteps if s.title.strip()]
        if len(steps) > MAX_SUBSTEPS:
            add("warning", "substeps_truncated", f"More than {MAX_SUBSTEPS} sub-steps; extra dropped.", i)
            steps = steps[:MAX_SUBSTEPS]
        sub_out = []
        for s in steps:
            dur = s.durationMin
            if dur is not None and not (1 <= dur <= 600):
                add("warning", "invalid_duration", "Sub-step duration out of range; cleared.", i)
                dur = None
            sub_out.append(SubStepOut(title=s.title.strip()[:MAX_TITLE], durationMin=dur))

        items.append(ProposedItem(
            id=str(uuid.uuid4()), title=title, category=category,
            colorHex=CATEGORY_COLORS[category], date=d, startTime=start, endTime=end,
            timeRange=_time_range(start, end),
            pictogramKeyword=(it.pictogramKeyword or "").strip()[:40] or None,
            createdByStaff=req.requesterRole == "staff", subSteps=sub_out))

    _check_duplicates(items, add)
    _check_order(items, add)
    _check_overlaps(items, add)
    _check_existing(items, req.existingItems, add)

    dates = {it.date for it in items}
    proposal_date = dates.pop() if len(dates) == 1 else None
    if items and proposal_date is None:
        add("warning", "missing_date", "No (or inconsistent) date; the user must choose the day.")

    return RoutineProposal(
        proposalId=str(uuid.uuid4()), source=source, participantId=req.participantId,
        date=proposal_date, items=items, issues=issues,
        missingInformation=[m.strip()[:160] for m in out.missingInformation if m.strip()][:10],
        valid=not any(x.severity == "error" for x in issues), model=model)


def _check_duplicates(items, add):
    seen = {}
    for i, it in enumerate(items):
        key = (it.title.casefold(), it.date, it.startTime)
        if key in seen:
            add("warning", "duplicate_activity",
                f"'{it.title}' duplicates activity #{seen[key] + 1}.", i)
        else:
            seen[key] = i


def _check_order(items, add):
    last = None
    for i, it in enumerate(items):
        if not it.startTime:
            continue
        if last and last[1] == it.date and _minutes(it.startTime) < _minutes(last[0]):
            add("warning", "order_mismatch",
                "Listed order does not match the times; check this activity.", i)
        last = (it.startTime, it.date)


def _check_overlaps(items, add):
    timed = [(i, it) for i, it in enumerate(items) if it.startTime and it.endTime
             and _minutes(it.endTime) > _minutes(it.startTime)]
    for a in range(len(timed)):
        for b in range(a + 1, len(timed)):
            (i, x), (j, y) = timed[a], timed[b]
            if x.date == y.date and _overlaps(x.startTime, x.endTime, y.startTime, y.endTime):
                add("error", "overlap", f"'{x.title}' overlaps with '{y.title}'.", j)


def _check_existing(items, existing, add):
    for e in existing:
        s, en, d, bad = _existing_times(e)
        if bad or not (s and en):
            continue
        for i, it in enumerate(items):
            if it.startTime and it.endTime and it.date == d and \
                    _overlaps(it.startTime, it.endTime, s, en):
                add("warning", "conflict_existing",
                    f"'{it.title}' conflicts with existing '{e.title[:60]}'.", i)
