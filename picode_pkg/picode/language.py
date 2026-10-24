"""Model instruction: reply in the language of the user's message.

UI chrome language is separate (`picode.i18n`, config `ui_language`, default fa).
"""

from __future__ import annotations

LANGUAGE_RULE = (
    "Answer in the language of the user's message. "
    "If the user writes in English, answer in English. "
    "If the user writes in Persian, answer in Persian. "
    "Do not switch language unless the user asks."
)


def contains_persian(text: str) -> bool:
    return any("\u0600" <= ch <= "\u06FF" for ch in (text or ""))


def terminal_text(value: object, fallback: str = "—") -> str:
    """Display label for chrome. When UI is English, strip Persian API names."""
    text = "" if value is None else str(value).strip()
    if not text:
        return fallback
    try:
        from picode.i18n import get_ui_lang

        # Keep native-script API labels when UI is Persian or Arabic
        if get_ui_lang() in ("fa", "ar"):
            return text
    except Exception:  # noqa: BLE001
        pass
    if contains_persian(text):
        return fallback
    return text


def system_instruction(*parts: str) -> str:
    """System message for chat. Never asks the model to answer only in Persian."""
    chunks = [
        "You are PiCode, a coding assistant for PiGPT.",
        LANGUAGE_RULE,
    ]
    for part in parts:
        extra = (part or "").strip()
        if extra:
            chunks.append(extra)
    return "\n".join(chunks)
