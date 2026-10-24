"""@ file mentions: list the project folder and attach file text to the model prompt."""

from __future__ import annotations

from pathlib import Path

from picode.repo_index import IGNORE_DIRS

MAX_ATTACH_CHARS = 12_000
MAX_ATTACHED_FILES = 8
BINARY_NOTE = "Binary file; contents not included."
DIRECTORY_NOTE = "Directory; contents not included."
MISSING_NOTE = "File not found."
TRUNCATED_NOTE = "[truncated]"


def at_token_span(text: str, cursor: int) -> tuple[int, int, str] | None:
    """@ token touching the cursor. The @ must start the line or follow whitespace."""
    if cursor < 0 or cursor > len(text):
        return None
    start = cursor
    while start > 0 and not text[start - 1].isspace():
        start -= 1
    if start >= len(text) or text[start] != "@":
        return None
    query = text[start + 1 : cursor]
    if any(ch.isspace() for ch in query):
        return None
    return start, cursor, query.replace("\\", "/")


def iter_mention_tokens(text: str) -> list[str]:
    tokens: list[str] = []
    i = 0
    raw = text or ""
    while i < len(raw):
        if raw[i] == "@" and (i == 0 or raw[i - 1].isspace()):
            j = i + 1
            while j < len(raw) and not raw[j].isspace():
                j += 1
            token = raw[i + 1 : j].strip().rstrip(".,;:)]}")
            if token:
                tokens.append(token.replace("\\", "/"))
            i = j
            continue
        i += 1
    return tokens


def file_menu_rows(root: Path, query: str) -> list[tuple[str, str]]:
    """Menu rows as (@relative, file|folder), one directory level, filtered live."""
    parent, name_q = _split_query(query)
    if parent is None:
        return []
    directory = _inside(root, parent)
    if directory is None or not directory.is_dir():
        return []
    rows: list[tuple[str, bool, str]] = []
    try:
        children = list(directory.iterdir())
    except OSError:
        return []
    needle = name_q.lower()
    for child in children:
        if child.name in IGNORE_DIRS or child.name in (".", ".."):
            continue
        if needle and not child.name.lower().startswith(needle):
            continue
        try:
            resolved = child.resolve()
        except OSError:
            continue
        root_r = root.resolve()
        if resolved != root_r and root_r not in resolved.parents:
            continue
        rel = f"{parent}/{child.name}" if parent else child.name
        rel = rel.replace("\\", "/")
        is_dir = child.is_dir()
        rows.append((rel.lower(), is_dir, rel if not is_dir else rel))
    rows.sort(key=lambda item: (not item[1], item[0]))
    visible: list[tuple[str, str]] = []
    for _key, is_dir, rel in rows[:100]:
        if is_dir:
            visible.append((f"@{rel}/", "folder"))
        else:
            visible.append((f"@{rel}", "file"))
    return visible


def expand_mentions(text: str, root: Path) -> str:
    """Add path and text for each @file. The user's sentence stays first."""
    tokens = iter_mention_tokens(text)
    if not tokens:
        return text
    blocks: list[str] = []
    seen: set[str] = set()
    omitted = 0
    for token in tokens:
        if token in seen:
            continue
        seen.add(token)
        if len(blocks) >= MAX_ATTACHED_FILES:
            omitted += 1
            continue
        blocks.append(f"path: {token}\n{_describe(root, token)}")
    if not blocks:
        return text
    extra = "\nNot all files were attached." if omitted else ""
    return text.rstrip() + "\n\nAttached files:\n\n" + "\n\n".join(blocks) + extra


def _split_query(query: str) -> tuple[str | None, str]:
    raw = (query or "").replace("\\", "/").lstrip("/")
    if raw.startswith("/") or any(part == ".." for part in raw.split("/")):
        return None, ""
    if "/" in raw:
        parent, name = raw.rsplit("/", 1)
        return parent, name
    return "", raw


def _inside(root: Path, relative: str) -> Path | None:
    root_r = root.resolve()
    if not relative:
        return root_r
    if any(part == ".." for part in relative.split("/")):
        return None
    path = (root_r / relative).resolve()
    if path != root_r and root_r not in path.parents:
        return None
    return path


def _describe(root: Path, token: str) -> str:
    if any(part == ".." for part in token.split("/")) or token.startswith("/"):
        return MISSING_NOTE
    path = _inside(root, token.rstrip("/"))
    if path is None or not path.exists():
        return MISSING_NOTE
    if path.is_dir():
        return DIRECTORY_NOTE
    return _read_for_prompt(path)


def _read_for_prompt(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            blob = handle.read(MAX_ATTACH_CHARS + 1)
    except OSError:
        return MISSING_NOTE
    if _looks_binary(blob):
        return BINARY_NOTE
    text = blob.decode("utf-8", errors="replace")
    if len(blob) > MAX_ATTACH_CHARS:
        return text[:MAX_ATTACH_CHARS] + "\n" + TRUNCATED_NOTE
    return text


def _looks_binary(blob: bytes) -> bool:
    if not blob:
        return False
    if b"\x00" in blob:
        return True
    sample = blob[:4096]
    weird = sum(byte < 9 or 13 < byte < 32 for byte in sample)
    return weird / len(sample) > 0.10
