"""Local multi-chat persistence under `<project>/.picode/chats/`."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from picode.config_helpers import project_picode_dir, project_root
from picode.session import ReplSession

CHATS_SUBDIR = "chats"
INDEX_NAME = "index.json"


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def chats_dir(root: Path | None = None) -> Path:
    d = project_picode_dir(root) / CHATS_SUBDIR
    d.mkdir(parents=True, exist_ok=True)
    return d


def _index_path(root: Path | None = None) -> Path:
    return chats_dir(root) / INDEX_NAME


def _chat_path(chat_id: str, root: Path | None = None) -> Path:
    safe = "".join(c for c in chat_id if c.isalnum() or c in "-_")
    if not safe:
        raise ValueError("Invalid chat id")
    return chats_dir(root) / f"{safe}.json"


def _load_index(root: Path | None = None) -> dict[str, Any]:
    path = _index_path(root)
    if not path.is_file():
        return {"chats": [], "active_id": None}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"chats": [], "active_id": None}
    if not isinstance(data, dict):
        return {"chats": [], "active_id": None}
    chats = data.get("chats")
    if not isinstance(chats, list):
        chats = []
    return {"chats": chats, "active_id": data.get("active_id")}


def _save_index(data: dict[str, Any], root: Path | None = None) -> None:
    path = _index_path(root)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def list_chats(root: Path | None = None) -> list[dict[str, Any]]:
    """Return chat summaries newest-first."""
    idx = _load_index(root)
    rows: list[dict[str, Any]] = []
    for item in idx.get("chats") or []:
        if not isinstance(item, dict):
            continue
        cid = str(item.get("id") or "").strip()
        if not cid:
            continue
        rows.append(
            {
                "id": cid,
                "title": str(item.get("title") or "Chat"),
                "updated_at": str(item.get("updated_at") or ""),
                "created_at": str(item.get("created_at") or ""),
            }
        )
    rows.sort(key=lambda r: r.get("updated_at") or "", reverse=True)
    return rows


def get_active_id(root: Path | None = None) -> str | None:
    idx = _load_index(root)
    aid = idx.get("active_id")
    return str(aid) if aid else None


def set_active_id(chat_id: str | None, root: Path | None = None) -> None:
    idx = _load_index(root)
    idx["active_id"] = chat_id
    _save_index(idx, root)


def new_chat_id() -> str:
    return uuid.uuid4().hex[:12]


def default_title(n: int | None = None) -> str:
    if n is None:
        n = len(list_chats()) + 1
    return f"Chat {n}"


def create_chat(
    *,
    title: str | None = None,
    root: Path | None = None,
) -> ReplSession:
    session = ReplSession(chat_id=new_chat_id(), title=title or default_title())
    save_chat(session, root=root)
    set_active_id(session.chat_id, root=root)
    return session


def save_chat(session: ReplSession, *, root: Path | None = None) -> None:
    if not session.chat_id:
        session.chat_id = new_chat_id()
    session.touch()
    payload = session.to_dict()
    path = _chat_path(session.chat_id, root)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    idx = _load_index(root)
    found = False
    for item in idx["chats"]:
        if isinstance(item, dict) and str(item.get("id")) == session.chat_id:
            item["title"] = session.title
            item["updated_at"] = session.updated_at
            item["created_at"] = session.created_at
            found = True
            break
    if not found:
        idx["chats"].append(
            {
                "id": session.chat_id,
                "title": session.title,
                "created_at": session.created_at,
                "updated_at": session.updated_at,
            }
        )
    idx["active_id"] = session.chat_id
    _save_index(idx, root)


def load_chat(chat_id: str, *, root: Path | None = None) -> ReplSession | None:
    path = _chat_path(chat_id, root)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    session = ReplSession.from_dict(data)
    set_active_id(session.chat_id, root=root)
    return session


def delete_chat(chat_id: str, *, root: Path | None = None) -> None:
    path = _chat_path(chat_id, root)
    if path.is_file():
        try:
            path.unlink()
        except OSError:
            pass
    idx = _load_index(root)
    idx["chats"] = [
        c
        for c in (idx.get("chats") or [])
        if not (isinstance(c, dict) and str(c.get("id")) == chat_id)
    ]
    if idx.get("active_id") == chat_id:
        idx["active_id"] = idx["chats"][0]["id"] if idx["chats"] else None
    _save_index(idx, root)


def ensure_active_chat(root: Path | None = None) -> ReplSession:
    """Load active chat or create the first one for this project."""
    base = root or project_root()
    chats_dir(base)
    aid = get_active_id(base)
    if aid:
        loaded = load_chat(aid, root=base)
        if loaded is not None:
            return loaded
    existing = list_chats(base)
    if existing:
        loaded = load_chat(str(existing[0]["id"]), root=base)
        if loaded is not None:
            return loaded
    return create_chat(root=base)


def rename_chat(chat_id: str, title: str, *, root: Path | None = None) -> None:
    session = load_chat(chat_id, root=root)
    if session is None:
        return
    session.title = (title or "").strip() or session.title
    save_chat(session, root=root)
