"""Local repository index for better codebase-aware CLI answers."""

from __future__ import annotations

import hashlib
import json
import re
import time
from pathlib import Path
from typing import Any

from picode.config_helpers import project_picode_dir, project_root

IGNORE_DIRS = {
    ".git",
    ".hg",
    ".svn",
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
    ".next",
    "dist",
    "build",
    "target",
    ".picode",
    ".cursor",
    ".idea",
    ".vs",
}

CODE_EXTS = {
    ".py",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".go",
    ".rs",
    ".java",
    ".kt",
    ".cs",
    ".rb",
    ".php",
    ".swift",
    ".md",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
    ".css",
    ".scss",
    ".sql",
    ".sh",
    ".ps1",
}

SYMBOL_RE = re.compile(
    r"^\s*(?:export\s+)?(?:async\s+)?(?:def|class|function|const|let|var|interface|type|fn|pub\s+fn|struct)\s+([A-Za-z_][\w]*)",
    re.M,
)


def _legacy_index_dir() -> Path:
    d = Path.home() / ".picode" / "indexes"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _root_key(root: Path) -> str:
    return hashlib.sha1(str(root.resolve()).encode("utf-8")).hexdigest()[:16]


def index_path(root: Path | None = None) -> Path:
    """Prefer per-project `<root>/.picode/index.json` (ignored from source walks)."""
    root = (root or project_root()).resolve()
    return project_picode_dir(root) / "index.json"


def _legacy_index_path(root: Path) -> Path:
    return _legacy_index_dir() / f"{_root_key(root)}.json"


def build_repo_index(root: Path | None = None, max_files: int = 4000) -> dict[str, Any]:
    root = (root or project_root()).resolve()
    files: list[dict[str, Any]] = []
    count = 0
    for path in root.rglob("*"):
        if count >= max_files:
            break
        if not path.is_file():
            continue
        parts = set(path.parts)
        if parts & IGNORE_DIRS:
            continue
        if path.suffix.lower() not in CODE_EXTS and path.name not in {
            "Dockerfile",
            "Makefile",
            "VERSION",
        }:
            continue
        try:
            if path.stat().st_size > 400_000:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        rel = str(path.relative_to(root)).replace("\\", "/")
        symbols = SYMBOL_RE.findall(text)[:40]
        files.append(
            {
                "path": rel,
                "ext": path.suffix.lower(),
                "bytes": path.stat().st_size,
                "symbols": symbols,
                "preview": text[:400],
            }
        )
        count += 1

    payload = {
        "root": str(root),
        "built_at": time.time(),
        "file_count": len(files),
        "files": files,
    }
    index_path(root).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    return payload


def load_repo_index(root: Path | None = None) -> dict[str, Any] | None:
    root = (root or project_root()).resolve()
    for p in (index_path(root), _legacy_index_path(root)):
        if not p.exists():
            continue
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
    return None


def query_repo_index(query: str, root: Path | None = None, limit: int = 8) -> list[dict[str, Any]]:
    idx = load_repo_index(root)
    if not idx:
        idx = build_repo_index(root)
    q = query.lower().strip()
    terms = [t for t in re.split(r"\W+", q) if len(t) > 1]
    scored: list[tuple[float, dict[str, Any]]] = []
    for f in idx.get("files") or []:
        path = str(f.get("path") or "").lower()
        syms = " ".join(f.get("symbols") or []).lower()
        preview = str(f.get("preview") or "").lower()
        score = 0.0
        for t in terms:
            if t in path:
                score += 4
            if t in syms:
                score += 3
            if t in preview:
                score += 1
        if score > 0:
            scored.append((score, f))
    scored.sort(key=lambda x: (-x[0], x[1].get("path") or ""))
    return [f for _, f in scored[:limit]]


def format_context_block(hits: list[dict[str, Any]]) -> str:
    if not hits:
        return ""
    lines = ["[repo index context]"]
    for h in hits:
        sym = ", ".join((h.get("symbols") or [])[:8])
        lines.append(f"- {h.get('path')} symbols=[{sym}]")
        prev = (h.get("preview") or "").strip().replace("\n", " ")[:180]
        if prev:
            lines.append(f"  preview: {prev}")
    return "\n".join(lines)
