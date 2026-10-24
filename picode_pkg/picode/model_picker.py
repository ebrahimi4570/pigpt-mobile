"""Filterable model picker — display labels only; API ids stay intact."""

from __future__ import annotations

from typing import Any


def strip_arvan_prefix(label: str) -> str:
    """Display-only: drop a leading ``arvan_`` from the visible name."""
    text = (label or "").strip()
    if text.lower().startswith("arvan_"):
        return text[6:]
    return text


def model_label(model: dict[str, Any]) -> str:
    """Single visible name for the picker (no id/provider columns)."""
    from picode.language import terminal_text

    for key in ("display_name_en", "display_name", "slug", "id"):
        raw = terminal_text(model.get(key), "")
        if raw:
            return strip_arvan_prefix(raw)
    mid = str(model.get("id") or "").strip()
    return strip_arvan_prefix(mid) if mid else "model"


def model_id(model: dict[str, Any]) -> str:
    return str(model.get("id") or "").strip()


def filter_models(
    models: list[dict[str, Any]],
    query: str = "",
) -> list[tuple[str, str, dict[str, Any]]]:
    """Return (label, real_id, model) rows filtered by typed query (label or id)."""
    needle = (query or "").strip().lower()
    rows: list[tuple[str, str, dict[str, Any]]] = []
    for m in models:
        mid = model_id(m)
        if not mid:
            continue
        label = model_label(m)
        if needle and needle not in label.lower() and needle not in mid.lower():
            # Also match stripped query against raw id (arvan_…)
            if needle not in strip_arvan_prefix(mid).lower():
                continue
        rows.append((label, mid, m))
    return rows


def pick_model_cli(
    console: Any,
    models: list[dict[str, Any]],
    *,
    current_id: str | None = None,
) -> dict[str, Any] | None:
    """Interactive CLI picker: type to filter, up/down, Enter select, Esc cancel."""
    from picode.i18n import t
    from picode.ui import MENU_ROWS, _read_key

    if not models:
        console.print(f"[yellow]{t('warn.no_models')}[/yellow]")
        return None

    query = ""
    selected = 0
    prev_extra = 0
    file = console.file

    def rows() -> list[tuple[str, str, dict[str, Any]]]:
        return filter_models(models, query)

    def paint() -> int:
        nonlocal selected
        items = rows()
        if not items:
            selected = 0
        else:
            selected = min(selected, len(items) - 1)
        width = max(console.width or 80, 20)
        extra: list[str] = []
        title = t("desk.models_pick")
        extra.append(f" {title}  filter: {query!r}"[: width - 1])
        if not items:
            extra.append(f" {t('warn.no_models')}"[: width - 1])
        else:
            if len(items) <= MENU_ROWS:
                window, offset = items, 0
            else:
                offset = min(max(0, selected - MENU_ROWS // 2), len(items) - MENU_ROWS)
                window = items[offset : offset + MENU_ROWS]
            for i, (label, mid, _m) in enumerate(window):
                idx = offset + i
                mark = ">" if idx == selected else " "
                cur = " *" if current_id and mid == current_id else ""
                line = f" {mark} {label}{cur}"
                extra.append(line[: width - 1])
            hint = t(
                "help.menu_hint",
                n=selected + 1,
                total=len(items),
                verb=t("help.menu_run"),
            )
            extra.append(hint[: width - 1])
        file.write("\r\033[2K")
        for i, line in enumerate(extra):
            if i:
                file.write("\n")
            file.write("\033[2K" + line)
        leftover = max(0, prev_extra - len(extra))
        for _ in range(leftover):
            file.write("\n\033[2K")
        down = len(extra) + leftover
        if down:
            file.write(f"\033[{down}A")
        file.flush()
        return len(extra)

    while True:
        prev_extra = paint()
        key = _read_key()
        items = rows()
        if key == "esc" or key == "interrupt":
            if prev_extra:
                file.write("\033[J\n")
                file.flush()
            return None
        if key == "up" and items:
            selected = (selected - 1) % len(items)
            continue
        if key == "down" and items:
            selected = (selected + 1) % len(items)
            continue
        if key == "enter":
            if prev_extra:
                file.write("\033[J\n")
                file.flush()
            if not items:
                return None
            return items[selected][2]
        if key == "backspace":
            query = query[:-1]
            selected = 0
            continue
        if key and len(key) == 1 and key.isprintable():
            query += key
            selected = 0
