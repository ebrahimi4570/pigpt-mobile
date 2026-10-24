"""Live activity / progress for CLI status and Windows shell."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from contextlib import contextmanager
from typing import Any

# Optional sink: (kind, message) — kind is thinking|reading|writing|running|error|info|done
activity_hook: Callable[[str, str], None] | None = None


def report(kind: str, message: str = "") -> None:
    """Emit a live activity event (Windows UI). `done` may have an empty message."""
    text = (message or "").strip()
    if not text and kind != "done":
        return
    hook = activity_hook
    if hook is not None:
        try:
            hook(kind, text)
        except Exception:  # noqa: BLE001
            pass


@contextmanager
def busy(console: Any, message: str, *, kind: str = "thinking") -> Iterator[None]:
    """CLI spinner + live hook for Windows. Same core path for both shells."""
    report(kind, message)
    status = getattr(console, "status", None)
    if callable(status):
        with status(f"[dim]{message}[/dim]"):
            try:
                yield
            finally:
                report("done")
        return
    try:
        yield
    finally:
        report("done")
