"""Local file helpers for picode agent."""

from __future__ import annotations

from pathlib import Path


def read_project_file(path: str | Path, *, root: Path | None = None) -> str:
    p = Path(path).expanduser()
    if not p.is_absolute() and root:
        p = (root / p).resolve()
    else:
        p = p.resolve()
    if root:
        root_r = root.resolve()
        if root_r not in p.parents and p != root_r:
            raise PermissionError("Path must stay inside the project folder")
    return p.read_text(encoding="utf-8")


def write_project_file(path: str | Path, content: str, *, root: Path | None = None) -> Path:
    p = Path(path).expanduser()
    if not p.is_absolute() and root:
        p = (root / p).resolve()
    else:
        p = p.resolve()
    if root:
        root_r = root.resolve()
        if root_r not in p.parents and p != root_r:
            raise PermissionError("Path must stay inside the project folder")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    return p
