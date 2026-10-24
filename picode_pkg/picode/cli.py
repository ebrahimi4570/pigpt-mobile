from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console
from picode.ui import brand_panel, read_repl_line

from picode import BRAND_NAME, PRODUCT, WEB_BRAND, __version__
from picode.api_client import (
    ApiClient,
    api_base,
    browser_login_with_pkce,
    get_token,
    has_saved_token,
    load_config,
    plan_display_name,
    probe_session,
    save_config,
    wait_for_device_token,
)
from picode.config_helpers import project_root
from picode.session import ReplSession
from picode.slash import do_chat, do_edit, do_read, handle_slash
from picode.updates import maybe_notify_update, run_self_update, update_notice

app = typer.Typer(
    name=PRODUCT,
    help=(
        f"{BRAND_NAME} - command-line coding assistant for {WEB_BRAND}\n\n"
        f"Run without a subcommand to enter the interactive REPL. "
        f"Inside REPL: /help"
    ),
    add_completion=False,
    no_args_is_help=False,
)
console = Console()


def _save_token(access: str, api_url: str) -> None:
    cfg = load_config()
    cfg["token"] = access
    cfg["api_url"] = api_url
    save_config(cfg)


def _clear_token() -> None:
    cfg = load_config()
    cfg.pop("token", None)
    save_config(cfg)


def _is_logged_in() -> bool:
    """Saved CLI credentials — billing/quota errors must not log the user out."""
    return has_saved_token()


def _login_success_panel(me: dict) -> str:
    plan = me.get("plan") or {}
    return (
        f"Signed in · {me.get('display_name') or me.get('phone')}\n"
        f"Plan: {plan_display_name(plan)}"
    )


def _announce_authorize_url(url: str) -> None:
    """Always show the full authorize URL (copy-paste) alongside browser-open hint."""
    console.print(
        brand_panel(
            "If the browser did not open, copy this URL and open it manually:\n\n"
            f"[bold underline]{url}[/bold underline]\n\n"
            "After you sign in on the web and approve, return to this terminal — "
            "the CLI will pick up your token via polling.\n"
            "Config: ~/.picode/",
            title=f"{BRAND_NAME} sign-in — authorize link",
        )
    )
    console.print(f"[bold]Authorize URL:[/bold]\n{url}\n")


def _run_browser_login(*, open_browser: bool = True, api_url: str | None = None) -> bool:
    """Run browser / device login. Returns True on success."""
    cfg = load_config()
    if api_url:
        cfg["api_url"] = api_url.rstrip("/")
        save_config(cfg)

    base = api_url or api_base()
    client = ApiClient(base=base, token="")

    console.print(
        "[dim]Preparing sign-in… Opening browser when possible.[/dim]"
    )
    try:
        access = browser_login_with_pkce(
            client,
            open_browser=open_browser,
            on_authorize_url=_announce_authorize_url,
        )
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        console.print("Fallback: [bold]picode login --manual[/bold] or --token")
        return False

    _save_token(access, client.base)
    me = ApiClient(base=client.base, token=access).me()
    console.print(brand_panel(_login_success_panel(me), title=BRAND_NAME))
    maybe_notify_update(console, force=True)
    return True


def _warn_saved_session_invalid() -> None:
    console.print(
        "[yellow]API session expired.[/yellow] "
        f"/login or [bold]{PRODUCT} login[/bold] — "
        "token stays in ~/.picode/ until /logout; browser will not open automatically."
    )


def _ensure_login(*, interactive: bool = True) -> bool:
    """Browser auth only when there is no saved token (never on expired JWT alone)."""
    if has_saved_token():
        return True
    if not interactive:
        console.print(f"[red]Not signed in. {PRODUCT} login[/red]")
        return False
    console.print("[yellow]Not signed in — starting browser sign-in…[/yellow]")
    return _run_browser_login()


def _repl_auth_at_start() -> None:
    """REPL entry: auto-browser only for first-time (no token); never clear token here."""
    if not has_saved_token():
        if not _ensure_login(interactive=True):
            console.print(f"[red]Sign-in failed. {PRODUCT} login[/red]")
            raise typer.Exit(1)
        return

    state = probe_session()
    if state == "unauthorized":
        _warn_saved_session_invalid()
    elif state == "degraded":
        console.print(
            "[dim]API temporarily unreachable — REPL is open; "
            f"/status or {PRODUCT} login[/dim]"
        )


def _print_status() -> None:
    from picode.slash import _print_status

    _print_status(ApiClient())


def run_repl() -> None:
    """Interactive session (Claude Code–style default entry)."""
    session = ReplSession()

    from picode.i18n import t

    console.print(
        brand_panel(
            t(
                "help.repl_welcome",
                brand=BRAND_NAME,
                version=__version__,
                web=WEB_BRAND,
                project=project_root(),
            ),
            title=BRAND_NAME,
        )
    )

    _repl_auth_at_start()

    maybe_notify_update(console)

    while True:
        try:
            line = read_repl_line(console)
        except (EOFError, KeyboardInterrupt):
            console.print()
            break
        if not line:
            continue
        if line.startswith("/"):
            if not handle_slash(
                line,
                session,
                on_login=lambda: _run_browser_login(),
                on_logout=_clear_token,
            ):
                break
            continue
        from picode.billing_guard import require_ai_credit

        client = ApiClient()
        if not require_ai_credit(client, console):
            continue
        do_chat(session, line)

    from picode.i18n import t as _t

    console.print(f"[dim]{_t('help.goodbye', brand=BRAND_NAME)}[/dim]")


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    version: bool = typer.Option(False, "--version", "-V", help="Show version"),
) -> None:
    if version:
        console.print(f"{BRAND_NAME} {__version__}")
        raise typer.Exit()
    if ctx.invoked_subcommand is None:
        run_repl()


@app.command("login")
def login_cmd(
    token: Optional[str] = typer.Option(None, "--token", "-t", help="JWT token (fallback)"),
    api_url: Optional[str] = typer.Option(None, "--api-url", help="API base URL"),
    manual: bool = typer.Option(
        False,
        "--manual",
        help="Device code sign-in (if browser does not open)",
    ),
    no_browser: bool = typer.Option(
        False,
        "--no-browser",
        help="Do not open browser; print URL only",
    ),
) -> None:
    """Browser sign-in (default). Token is stored in ~/.picode/."""
    cfg = load_config()
    if api_url:
        cfg["api_url"] = api_url.rstrip("/")
        save_config(cfg)

    base = api_url or api_base()
    client = ApiClient(base=base, token="")

    if token:
        access = token.strip()
        _save_token(access, client.base)
        me = ApiClient(base=client.base, token=access).me()
        console.print(brand_panel(_login_success_panel(me), title=BRAND_NAME))
        maybe_notify_update(console, force=True)
        run_repl()
        return

    if manual:
        data = client.start_device_login()
        user_code = data["user_code"]
        verify_url = data["verification_url"]
        device_code = data["device_code"]
        console.print(
            brand_panel(
                f"1) Open this URL in your browser:\n\n"
                f"[bold underline]{verify_url}[/bold underline]\n\n"
                f"2) If authorize does not open, enter this code at /app/cli:\n"
                f"[bold]{user_code}[/bold]\n\nWaiting for approval…",
                title=f"{BRAND_NAME} manual sign-in",
            )
        )
        console.print(f"[bold]Authorize URL:[/bold]\n{verify_url}\n")
        access = wait_for_device_token(client, device_code, interval=int(data.get("interval") or 3))
        _save_token(access, client.base)
        me = ApiClient(base=client.base, token=access).me()
        console.print(f"[green]Signed in[/green] · {me.get('phone')}")
        maybe_notify_update(console, force=True)
        run_repl()
        return

    if not _run_browser_login(open_browser=not no_browser, api_url=api_url):
        raise typer.Exit(1)
    run_repl()


@app.command("logout")
def logout_cmd() -> None:
    """Sign out and remove token from ~/.picode/."""
    _clear_token()
    console.print("[green]Signed out.[/green]")


@app.command("status")
def status_cmd() -> None:
    if not get_token():
        console.print(f"[red]Not signed in. {PRODUCT} login[/red]")
        raise typer.Exit(1)
    _print_status()


@app.command("chat")
def chat_cmd(prompt: str = typer.Argument(..., help="Your message")) -> None:
    if not get_token():
        console.print(f"[red]Run {PRODUCT} login first[/red]")
        raise typer.Exit(1)
    session = ReplSession()
    do_chat(session, prompt)


@app.command("read")
def read_cmd(path: str = typer.Argument(...)) -> None:
    do_read(path)


@app.command("edit")
def edit_cmd(
    path: str = typer.Argument(..., help="File path relative to project"),
    instruction: str = typer.Argument(..., help="Edit instruction"),
    yes: bool = typer.Option(False, "--yes", "-y", help="Write without confirmation"),
) -> None:
    """Read local file, get AI suggestion, safe write inside project."""
    if not get_token():
        console.print(f"[red]Run {PRODUCT} login first[/red]")
        raise typer.Exit(1)
    if yes:
        from picode.config_helpers import set_permissions

        set_permissions("auto")
    session = ReplSession()
    do_edit(session, path, instruction)


@app.command("update")
def update_cmd(
    check: bool = typer.Option(False, "--check", help="Show upgrade command only; do not install"),
) -> None:
    """Upgrade PiCode from pigpt.ir (same venv as install script)."""
    notice = update_notice(force=True)
    if not notice:
        console.print(f"[green]{BRAND_NAME} {__version__} is up to date.[/green]")
        raise typer.Exit(0)
    console.print(
        brand_panel(
            f"Latest: {notice['latest_version']}\n"
            f"Installed: {notice['local_version']}",
            title=f"{BRAND_NAME} update",
        )
    )
    if check:
        console.print(notice["upgrade_command"])
        raise typer.Exit(0)
    code = run_self_update(notice["wheel_url"])
    if code != 0:
        console.print("[red]Update failed.[/red]")
        console.print(notice["upgrade_command"])
        raise typer.Exit(code)
    console.print(f"[green]Updated.[/green] Run {PRODUCT} update --check or --version")


if __name__ == "__main__":
    app()
