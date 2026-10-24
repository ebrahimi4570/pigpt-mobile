"""In-memory REPL / desktop chat session state (optionally persisted)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _empty_totals() -> dict[str, int]:
    return {
        "prompt_tokens": 0,
        "completion_tokens": 0,
        "total_tokens": 0,
        "turns": 0,
    }


@dataclass
class ReplSession:
    history: list[dict[str, str]] = field(default_factory=list)
    last_diff: str | None = None
    pending_edit_path: str | None = None
    pending_edit_content: str | None = None
    last_usage: dict[str, Any] | None = None
    last_model_id: str | None = None
    last_model_name: str | None = None
    chat_id: str | None = None
    title: str = "Chat"
    created_at: str = field(default_factory=_utcnow)
    updated_at: str = field(default_factory=_utcnow)
    usage_totals: dict[str, int] = field(default_factory=_empty_totals)
    # Desktop transcript lines for restoring the output pane per chat.
    ui_log: list[dict[str, str]] = field(default_factory=list)

    def touch(self) -> None:
        self.updated_at = _utcnow()

    def reset(self) -> None:
        self.history.clear()
        self.last_diff = None
        self.pending_edit_path = None
        self.pending_edit_content = None
        self.last_usage = None
        self.usage_totals = _empty_totals()
        self.ui_log.clear()
        self.touch()

    def add_turn(self, user: str, assistant: str) -> None:
        self.history.append({"role": "user", "content": user})
        self.history.append({"role": "assistant", "content": assistant})
        # Keep last 40 messages (20 turns) in session
        if len(self.history) > 40:
            self.history = self.history[-40:]
        if self.title in ("Chat", "Chat 1") or self.title.startswith("Chat "):
            snippet = (user or "").strip().replace("\n", " ")
            if snippet:
                self.title = (snippet[:40] + "…") if len(snippet) > 40 else snippet
        self.touch()

    def record_usage(self, usage: dict[str, Any] | None) -> None:
        if not usage:
            return
        self.last_usage = dict(usage)
        pt = int(usage.get("prompt_tokens") or 0)
        ct = int(usage.get("completion_tokens") or 0)
        tt = int(usage.get("total_tokens") or (pt + ct))
        self.usage_totals["prompt_tokens"] = int(self.usage_totals.get("prompt_tokens") or 0) + pt
        self.usage_totals["completion_tokens"] = (
            int(self.usage_totals.get("completion_tokens") or 0) + ct
        )
        self.usage_totals["total_tokens"] = int(self.usage_totals.get("total_tokens") or 0) + tt
        self.usage_totals["turns"] = int(self.usage_totals.get("turns") or 0) + 1
        self.touch()

    def append_ui(self, kind: str, text: str) -> None:
        body = (text or "").strip()
        if not body:
            return
        self.ui_log.append({"kind": kind, "text": body})
        if len(self.ui_log) > 200:
            self.ui_log = self.ui_log[-200:]
        self.touch()

    def history_for_api(self) -> list[dict[str, str]]:
        return list(self.history)

    def approx_tokens(self) -> int:
        chars = sum(len(m.get("content", "")) for m in self.history)
        return max(0, chars // 4)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.chat_id,
            "title": self.title,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "history": list(self.history),
            "last_diff": self.last_diff,
            "pending_edit_path": self.pending_edit_path,
            "pending_edit_content": self.pending_edit_content,
            "last_usage": self.last_usage,
            "last_model_id": self.last_model_id,
            "last_model_name": self.last_model_name,
            "usage_totals": dict(self.usage_totals),
            "ui_log": list(self.ui_log),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ReplSession:
        totals = data.get("usage_totals") if isinstance(data.get("usage_totals"), dict) else {}
        merged = _empty_totals()
        for key in merged:
            try:
                merged[key] = int(totals.get(key) or 0)
            except (TypeError, ValueError):
                merged[key] = 0
        history = data.get("history") if isinstance(data.get("history"), list) else []
        ui_log = data.get("ui_log") if isinstance(data.get("ui_log"), list) else []
        clean_hist: list[dict[str, str]] = []
        for item in history:
            if isinstance(item, dict) and item.get("role") and item.get("content") is not None:
                clean_hist.append(
                    {"role": str(item["role"]), "content": str(item["content"])}
                )
        clean_ui: list[dict[str, str]] = []
        for item in ui_log:
            if isinstance(item, dict) and item.get("text") is not None:
                clean_ui.append(
                    {
                        "kind": str(item.get("kind") or "system"),
                        "text": str(item["text"]),
                    }
                )
        return cls(
            chat_id=str(data.get("id") or "") or None,
            title=str(data.get("title") or "Chat"),
            created_at=str(data.get("created_at") or _utcnow()),
            updated_at=str(data.get("updated_at") or _utcnow()),
            history=clean_hist,
            last_diff=data.get("last_diff") if isinstance(data.get("last_diff"), str) else None,
            pending_edit_path=(
                str(data["pending_edit_path"])
                if data.get("pending_edit_path") is not None
                else None
            ),
            pending_edit_content=(
                str(data["pending_edit_content"])
                if data.get("pending_edit_content") is not None
                else None
            ),
            last_usage=data.get("last_usage") if isinstance(data.get("last_usage"), dict) else None,
            last_model_id=(
                str(data["last_model_id"]) if data.get("last_model_id") is not None else None
            ),
            last_model_name=(
                str(data["last_model_name"]) if data.get("last_model_name") is not None else None
            ),
            usage_totals=merged,
            ui_log=clean_ui,
        )
