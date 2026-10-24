"""Readline tab completion for slash commands."""

from __future__ import annotations

# English fallbacks; UI shows localized descriptions via picode.i18n.
SLASH_COMMANDS: list[tuple[str, str]] = [
    ("/help", "List commands"),
    ("/status", "Auth, plan, quota, API, project"),
    ("/model", "Current model or set model"),
    ("/models", "List allowed models"),
    ("/permissions", "File/shell/SSH/web permissions"),
    ("/perm", "Alias for /permissions"),
    ("/ssh", "Manage SSH connections"),
    ("/language", "UI language fa|en|tr|ar"),
    ("/login", "Sign in again via browser"),
    ("/update", "Check/install PiCode update"),
    ("/logout", "Sign out and clear token"),
    ("/read", "Read a project file"),
    ("/edit", "Edit a file with AI"),
    ("/apply", "Apply pending patch"),
    ("/run", "Run a shell command"),
    ("/workspaces", "List workspaces"),
    ("/compact", "Session context / token summary"),
    ("/context", "Alias for /compact"),
    ("/cost", "Usage and daily quota"),
    ("/usage", "Alias for /cost"),
    ("/settings", "Open settings (desktop)"),
    ("/project", "Project root path"),
    ("/index", "Repo index / search"),
    ("/commit", "Suggest commit message"),
    ("/pr", "Suggest PR title and body"),
    ("/config", "Key CLI configuration"),
    ("/reset", "Clear chat history this session"),
    ("/diff", "Last edit diff"),
    ("/clear", "Clear screen"),
    ("/clean", "Clear screen and chat history"),
    ("/exit", "Exit REPL"),
    ("/quit", "Exit REPL"),
]

COMMAND_NAMES = [name for name, _ in SLASH_COMMANDS]
NEEDS_ARGS = {"/read", "/edit", "/run"}
_COMPLETER_STATE: list[str] = []


def _completer(text: str, state: int) -> str | None:
    if state == 0:
        if not text.startswith("/"):
            return None
        needle = text.lower()
        _COMPLETER_STATE.clear()
        _COMPLETER_STATE.extend(sorted(c for c in COMMAND_NAMES if c.startswith(needle)))
        if needle in ("/permissions", "/perm"):
            for sub in (" ask", " auto", " deny"):
                _COMPLETER_STATE.append(needle.split()[0] + sub)
    if state < len(_COMPLETER_STATE):
        return _COMPLETER_STATE[state]
    return None


def setup_readline() -> bool:
    try:
        import readline  # type: ignore[import-not-found]
    except ImportError:
        return False
    readline.set_completer_delims(" \t\n")
    readline.parse_and_bind("tab: complete")
    readline.set_completer(_completer)
    return True


def print_command_menu(console) -> None:
    from rich.table import Table

    from picode.i18n import localized_commands, t

    table = Table(title=t("help.slash_title"), show_header=True, header_style="bold cyan")
    table.add_column("Command", style="green")
    table.add_column("Description")
    for cmd, desc in localized_commands():
        table.add_row(cmd, desc)
    console.print(table)
