"""Terminal chrome: brand panels and the slash-command picker."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.text import Text

from picode import BRAND_NAME
from picode.mentions import at_token_span, file_menu_rows
from picode.repl_input import NEEDS_ARGS, SLASH_COMMANDS

BRAND = "#2dd4bf"
# Desktop window sets this so panels follow the view, not a console.
PANEL_COLUMNS: int | None = None


def brand_panel(body: str, *, title: str = "") -> Panel:
    """Half the terminal by default; grow to two thirds only for a long line."""
    width = PANEL_COLUMNS or max(Console().width or 80, 24)
    min_w = max(24, width // 2)
    max_w = max(min_w, (width * 2) // 3)
    plain = Text.from_markup(body).plain
    longest = max((len(line) for line in plain.splitlines()), default=0)
    needed = longest + 6
    if needed <= min_w:
        panel_w = min_w
    else:
        panel_w = min(max_w, needed)
    return Panel(
        body,
        title=title,
        title_align="left",
        border_style=BRAND,
        width=panel_w,
        expand=False,
        padding=(1, 2),
    )


def _read_key() -> str:
    """One key: printable char, or up/down/left/right/enter/backspace/esc/interrupt/eof."""
    if os.name == "nt":
        import msvcrt

        ch = msvcrt.getwch()
        if ch in ("\x00", "\xe0"):
            nxt = msvcrt.getwch()
            return {"H": "up", "P": "down", "K": "left", "M": "right"}.get(nxt, "")
        if ch == "\x03":
            return "interrupt"
        if ch == "\x04":
            return "eof"
        if ch == "\x1b":
            return "esc"
        if ch in ("\r", "\n"):
            return "enter"
        if ch == "\x08":
            return "backspace"
        return ch

    import select
    import termios
    import tty

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
        if ch == "\x1b":
            if select.select([sys.stdin], [], [], 0.05)[0]:
                seq = sys.stdin.read(1)
                if seq == "[" and select.select([sys.stdin], [], [], 0.05)[0]:
                    arrow = sys.stdin.read(1)
                    return {"A": "up", "B": "down", "C": "right", "D": "left"}.get(arrow, "")
            return "esc"
        if ch == "\x03":
            return "interrupt"
        if ch == "\x04":
            return "eof"
        if ch in ("\r", "\n"):
            return "enter"
        if ch in ("\x7f", "\x08"):
            return "backspace"
        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


PROMPT_PLAIN = f"{BRAND_NAME}> "
MENU_ROWS = 8


class LineState:
    """REPL line plus slash-menu selection. Menu follows the buffer; Enter is not required to open it."""

    def __init__(self, buf: list[str] | None = None, cursor: int = 0, selected: int = 0, dismissed: bool = False):
        self.buf = list(buf or [])
        self.cursor = cursor
        self.selected = selected
        self.dismissed = dismissed

    def text(self) -> str:
        return "".join(self.buf)


def slash_token(state: LineState) -> str | None:
    """Command prefix when `/` is at the start and the name is still being typed."""
    if state.dismissed:
        return None
    text = state.text()
    if not text.startswith("/"):
        return None
    if " " in text:
        return None
    return text


def matching_commands(state: LineState) -> list[tuple[str, str]]:
    token = slash_token(state)
    if token is None:
        return []
    needle = token.lower()
    from picode.i18n import localized_commands

    return [(name, desc) for name, desc in localized_commands() if name.lower().startswith(needle)]


def active_menu(
    state: LineState,
    root: Path | None = None,
) -> tuple[str, list[tuple[str, str]]]:
    """Slash menu wins when the line is a `/` command. Otherwise `@` lists files."""
    if slash_token(state) is not None:
        return "slash", matching_commands(state)
    if state.dismissed:
        return "", []
    span = at_token_span(state.text(), state.cursor)
    if span is None:
        return "", []
    from picode.config_helpers import project_root

    folder = root if root is not None else project_root()
    return "file", file_menu_rows(folder, span[2])


def _after_edit(buf: list[str], cursor: int) -> LineState:
    return LineState(buf, cursor, 0, False)


def _insert_mention(state: LineState, chosen: str) -> LineState:
    span = at_token_span(state.text(), state.cursor)
    if span is None:
        return state
    start, end, _query = span
    insertion = chosen if chosen.endswith("/") else chosen + " "
    text = state.text()
    updated = text[:start] + insertion + text[end:]
    cursor = start + len(insertion)
    return LineState(list(updated), cursor, 0, False)


def apply_key(
    state: LineState,
    key: str,
    root: Path | None = None,
) -> tuple[LineState, str | None, str]:
    """Apply one key. Third value is continue | submit | eof | interrupt.

    A buffer that starts with `/` already has a command list (`matching_commands`).
    Enter runs the highlighted command. `@` lists files; Enter inserts the file.
    Enter on any other line submits that line.
    """
    menu_kind, rows = active_menu(state, root)
    if key == "interrupt":
        return state, None, "interrupt"
    if key == "eof" and not state.buf:
        return state, None, "eof"
    if key == "esc":
        text = state.text()
        if (
            slash_token(state) is not None
            or text.startswith("/")
            or at_token_span(text, state.cursor) is not None
        ):
            return LineState(state.buf, state.cursor, 0, True), None, "continue"
        return state, None, "continue"
    if key == "up" and rows:
        selected = (state.selected - 1) % len(rows)
        return LineState(state.buf, state.cursor, selected, False), None, "continue"
    if key == "down" and rows:
        selected = (state.selected + 1) % len(rows)
        return LineState(state.buf, state.cursor, selected, False), None, "continue"
    if key == "enter":
        if rows and menu_kind == "slash":
            name = rows[min(state.selected, len(rows) - 1)][0]
            if name in NEEDS_ARGS:
                buf = list(name + " ")
                return LineState(buf, len(buf), 0, False), None, "continue"
            return state, name, "submit"
        if rows and menu_kind == "file":
            chosen = rows[min(state.selected, len(rows) - 1)][0]
            return _insert_mention(state, chosen), None, "continue"
        return state, state.text().strip(), "submit"
    if key == "backspace" and state.cursor > 0:
        cursor = state.cursor - 1
        buf = state.buf[:cursor] + state.buf[cursor + 1 :]
        return _after_edit(buf, cursor), None, "continue"
    if key == "left" and state.cursor > 0:
        return LineState(state.buf, state.cursor - 1, state.selected, state.dismissed), None, "continue"
    if key == "right" and state.cursor < len(state.buf):
        return LineState(state.buf, state.cursor + 1, state.selected, state.dismissed), None, "continue"
    if key and len(key) == 1 and key.isprintable():
        buf = state.buf[: state.cursor] + [key] + state.buf[state.cursor :]
        return _after_edit(buf, state.cursor + 1), None, "continue"
    return state, None, "continue"


def _prompt_ansi() -> str:
    return f"\033[1;38;2;45;212;191m{BRAND_NAME}>\033[0m "


def _window(rows: list[tuple[str, str]], selected: int) -> tuple[list[tuple[str, str]], int]:
    if len(rows) <= MENU_ROWS:
        return rows, 0
    offset = min(max(0, selected - MENU_ROWS // 2), len(rows) - MENU_ROWS)
    return rows[offset : offset + MENU_ROWS], offset


def _paint(
    console: Console,
    state: LineState,
    rows: list[tuple[str, str]],
    prev_extra: int,
    *,
    menu_kind: str = "slash",
) -> int:
    width = max(console.width or 80, 20)
    text = state.text()
    extra: list[str] = []
    if rows:
        selected = min(state.selected, len(rows) - 1)
        window, offset = _window(rows, selected)
        for i, (name, desc) in enumerate(window):
            idx = offset + i
            mark = ">" if idx == selected else " "
            name_w = max(14, min(40, len(name)))
            line = f" {mark} {name:<{name_w}} {desc}"
            extra.append(line[: width - 1])
        from picode.i18n import t

        verb = t("help.menu_insert") if menu_kind == "file" else t("help.menu_run")
        hint = t(
            "help.menu_hint",
            n=selected + 1,
            total=len(rows),
            verb=verb,
        )
        extra.append(hint[: width - 1])
    file = console.file
    file.write("\r\033[2K" + _prompt_ansi() + text)
    for line in extra:
        file.write("\n\033[2K" + line)
    leftover = max(0, prev_extra - len(extra))
    for _ in range(leftover):
        file.write("\n\033[2K")
    down = len(extra) + leftover
    if down:
        file.write(f"\033[{down}A")
    col = len(PROMPT_PLAIN) + state.cursor
    file.write("\r")
    if col:
        file.write(f"\033[{col}C")
    file.flush()
    return len(extra)


def _end_line(console: Console, state: LineState) -> None:
    tail = len(state.text()) - state.cursor
    if tail > 0:
        console.file.write(f"\033[{tail}C")
    console.file.write("\033[J\n")
    console.file.flush()


def read_repl_line(console: Console) -> str | None:
    """Read one REPL line. `/` lists commands and `@` lists files before Enter."""
    state = LineState()
    prev_extra = 0
    while True:
        menu_kind, rows = active_menu(state)
        prev_extra = _paint(console, state, rows, prev_extra, menu_kind=menu_kind)
        key = _read_key()
        state, submitted, kind = apply_key(state, key)
        if kind == "interrupt":
            _end_line(console, state)
            raise KeyboardInterrupt
        if kind == "eof":
            _end_line(console, state)
            return None
        if kind == "submit":
            _end_line(console, state)
            return submitted
