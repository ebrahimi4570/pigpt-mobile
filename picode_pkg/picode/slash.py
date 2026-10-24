"""Slash command handlers for picode REPL."""

from __future__ import annotations

import difflib
import shlex
from collections.abc import Callable
from typing import TYPE_CHECKING

import typer
from rich.console import Console
from rich.markdown import Markdown
from picode.ui import brand_panel
from rich.table import Table

from picode import BRAND_NAME
from picode.activity import busy
from picode.i18n import get_ui_lang, set_ui_lang, slash_help_text, t
from picode.language import system_instruction, terminal_text
from picode.api_client import (
    ApiClient,
    api_base,
    get_token,
    load_config,
    model_display_name,
    plan_display_name,
    print_api_error,
    save_config,
)
from picode.billing_guard import require_ai_credit
from picode.config_helpers import (
    PERMISSION_MODES,
    add_workspace,
    config_summary,
    get_model_id,
    get_permissions,
    get_remote_permissions,
    get_shell_permissions,
    get_web_permissions,
    list_workspaces,
    project_picode_dir,
    project_root,
    remove_workspace,
    set_model_id,
    set_permissions,
    set_project_dir,
    set_remote_permissions,
    set_shell_permissions,
    set_web_permissions,
    switch_workspace,
)
from picode.file_tools import run_tool_loop, writes_off_notice
from picode.files import read_project_file, write_project_file
from picode.repl_input import SLASH_COMMANDS, print_command_menu
from picode.session import ReplSession

if TYPE_CHECKING:
    from collections.abc import Callable

console = Console()
confirm_hook: Callable[[str], bool] | None = None
# Desktop: (models, current_id) -> selected real model id or None
models_picker_hook: Callable[[list[dict], str | None], str | None] | None = None
# Desktop: open Connections dialog instead of console prompts
ssh_editor_hook: Callable[[], None] | None = None


def _confirm(action: str) -> bool:
    if confirm_hook is not None:
        return bool(confirm_hook(action))
    return typer.confirm(action, default=False)

def _slash_help() -> str:
    return slash_help_text()


# Compatibility for imports/tests; prefer slash_help_text() / _slash_help().
SLASH_HELP = slash_help_text()


def _confirm_shell(action: str) -> bool:
    mode = get_shell_permissions()
    if mode == "deny":
        console.print(f"[red]{t('warn.shell_denied')}[/red]")
        return False
    if mode == "auto":
        return True
    return _confirm(action)


def do_run(cmd: str) -> None:
    import subprocess

    from picode.activity import report as report_activity

    if not _confirm_shell(t("confirm.run_shell", cmd=cmd)):
        console.print(f"[dim]{t('warn.cancelled')}[/dim]")
        return
    root = project_root()
    report_activity("running", t("status.running", cmd=cmd))
    try:
        proc = subprocess.run(
            cmd,
            shell=True,
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired:
        console.print("[red]timeout (120s)[/red]")
        return
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        return
    out = (proc.stdout or "") + (proc.stderr or "")
    console.print(brand_panel(out[:8000] + ("…" if len(out) > 8000 else ""), title=f"exit {proc.returncode}"))


def _print_ssh_list() -> None:
    from picode.ssh_remote import get_ssh_default, list_ssh_profiles

    profiles = list_ssh_profiles()
    if not profiles:
        console.print(f"[yellow]{t('warn.ssh_none')}[/yellow]")
        return
    default = get_ssh_default()
    table = Table(title="SSH connections", show_header=True)
    table.add_column("name")
    table.add_column("host")
    table.add_column("user")
    table.add_column("auth")
    for p in profiles:
        mark = " ✓" if p.name == default else ""
        table.add_row(
            p.name + mark,
            f"{p.host}:{p.port}",
            p.username or "—",
            p.auth,
        )
    console.print(table)
    console.print(
        "[dim]/ssh add · /ssh test [name] · /ssh default <name> · /ssh delete <name>[/dim]"
    )


def do_ssh(args: list[str]) -> None:
    from picode.ssh_remote import (
        AUTH_KEY,
        AUTH_PASSWORD,
        SshProfile,
        delete_ssh_profile,
        get_ssh_default,
        set_ssh_default,
        test_ssh_connection,
        upsert_ssh_profile,
    )

    if not args or args[0].lower() in ("list", "ls"):
        _print_ssh_list()
        return
    sub = args[0].lower()
    if sub == "default":
        if len(args) < 2:
            console.print(f"[dim]default:[/dim] {get_ssh_default() or '—'}")
            return
        try:
            name = set_ssh_default(args[1])
        except ValueError as exc:
            console.print(f"[red]{exc}[/red]")
            return
        console.print(f"[green]{t('ok.ssh_default', name=name)}[/green]")
        return
    if sub == "delete":
        if len(args) < 2:
            console.print("[yellow]/ssh delete <name>[/yellow]")
            return
        delete_ssh_profile(args[1])
        console.print(f"[green]{t('ok.ssh_deleted', name=args[1])}[/green]")
        return
    if sub == "test":
        name = args[1] if len(args) >= 2 else None
        try:
            with busy(console, t("status.ssh", host=name or "default", cmd="test"), kind="running"):
                data = test_ssh_connection(name)
        except Exception as exc:  # noqa: BLE001
            console.print(f"[red]{exc}[/red]")
            return
        console.print(
            f"[green]{t('ok.ssh_test', name=data.get('connection'), code=data.get('exit_status'))}[/green]"
        )
        out = (data.get("stdout") or "") + (data.get("stderr") or "")
        if out.strip():
            console.print(brand_panel(out[:4000], title=str(data.get("host"))))
        return
    if sub != "add":
        console.print(
            "[yellow]Usage: /ssh [list|add|test [name]|default <name>|delete <name>][/yellow]"
        )
        return

    # Interactive add/edit (CLI). Desktop opens a dialog instead when hooked.
    if ssh_editor_hook is not None:
        ssh_editor_hook()
        return
    import getpass

    name = console.input("Name: ").strip()
    host = console.input("Host: ").strip()
    port_raw = console.input("Port [22]: ").strip() or "22"
    user = console.input("Username: ").strip()
    auth = console.input("Auth password|key [key]: ").strip().lower() or AUTH_KEY
    password = ""
    private_key = ""
    passphrase = ""
    if auth == AUTH_PASSWORD:
        password = getpass.getpass("Password: ").strip()
    else:
        auth = AUTH_KEY
        private_key = console.input("Private key path: ").strip()
        passphrase = getpass.getpass("Key passphrase (optional): ").strip()
    try:
        port = int(port_raw)
    except ValueError:
        port = 22
    try:
        profile = SshProfile(
            name=name,
            host=host,
            port=port,
            username=user,
            auth=auth,
            password=password,
            private_key=private_key,
            passphrase=passphrase,
        )
        upsert_ssh_profile(profile)
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        return
    console.print(f"[green]{t('ok.ssh_saved', name=name)}[/green]")


def apply_pending_edit(session: ReplSession) -> None:
    if not session.pending_edit_path or session.pending_edit_content is None:
        console.print(f"[yellow]{t('warn.nothing_to_apply')}[/yellow]")
        return
    root = project_root()
    path = session.pending_edit_path
    new_content = session.pending_edit_content
    old_text = ""
    try:
        from picode.files import read_project_file

        old_text = read_project_file(path, root=root)
    except Exception:  # noqa: BLE001
        old_text = ""
    from picode.diff_view import format_diff_panel, make_unified_diff, preview_write_allowed
    from picode.ui import brand_panel

    diff = session.last_diff or make_unified_diff(path, old_text, new_content)
    session.last_diff = diff
    console.print(brand_panel(format_diff_panel(diff), title=f"diff · {path}"))
    mode = get_permissions()
    allowed, _ = preview_write_allowed(path, old_text, new_content, mode=mode)
    if not allowed:
        return
    # When no GUI hook, ask-mode already confirmed inside preview; auto needs nothing.
    # If hook handled it, allowed is enough. Extra confirm only when ask + no hook leftover.
    try:
        out = write_project_file(path, new_content, root=root)
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        return
    console.print(f"[green]{t('ok.applied', path=out)}[/green]")
    session.pending_edit_path = None
    session.pending_edit_content = None
    session.last_diff = None


def discard_pending_edit(session: ReplSession) -> None:
    session.pending_edit_path = None
    session.pending_edit_content = None
    session.last_diff = None
    console.print(f"[dim]{t('ok.discarded')}[/dim]")


def _confirm_write(action: str) -> bool:
    mode = get_permissions()
    if mode == "deny":
        console.print(f"[red]{writes_off_notice()}[/red]")
        return False
    if mode == "auto":
        return True
    return _confirm(action)


def _resolve_model_arg(client: ApiClient, arg: str, models: list[dict]) -> dict | None:
    arg = arg.strip()
    if not arg:
        return None
    low = arg.lower()
    for m in models:
        if str(m.get("id", "")).lower() == low:
            return m
        if str(m.get("slug", "")).lower() == low:
            return m
    for m in models:
        mid = str(m.get("id", "")).lower()
        slug = str(m.get("slug", "")).lower()
        if mid.startswith(low) or slug.startswith(low):
            return m
    return None


def _fetch_models(client: ApiClient) -> list[dict]:
    try:
        data = client.list_models()
        return data if isinstance(data, list) else []
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]Failed to load models: {exc}[/red]")
        return []


def _pick_and_set_model(models: list[dict], *, current_id: str | None) -> None:
    """Filterable name-only picker (CLI). Display strips arvan_; API keeps real id."""
    from picode.model_picker import model_label, pick_model_cli

    if not models:
        console.print(f"[yellow]{t('warn.no_models')}[/yellow]")
        return
    if current_id:
        name = next(
            (model_label(m) for m in models if str(m.get("id")) == current_id),
            current_id,
        )
        console.print(t("info.current_model", name=name))
    else:
        console.print(t("info.default_model"))
    picked = pick_model_cli(console, models, current_id=current_id)
    if not picked:
        console.print(f"[dim]{t('warn.cancelled')}[/dim]")
        return
    set_model_id(str(picked["id"]))
    console.print(f"[green]{t('ok.model_set', name=model_label(picked))}[/green]")


def _print_status(client: ApiClient) -> None:
    if not client.token:
        console.print("[red]Not signed in.[/red]")
        return
    try:
        me = client.me()
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]Failed to load status: {exc}[/red]")
        return
    plan = me.get("plan") or {}
    usage = me.get("usage") or {}
    console.print(
        brand_panel(
            f"API: {client.base}\n"
            f"Project: {project_root()}\n"
            f"User: {me.get('display_name') or me.get('phone')}\n"
            f"Plan: {plan_display_name(plan)} ({plan.get('code')})\n"
            f"Messages today: {usage.get('messages_used')} / "
            f"{usage.get('daily_limit') if usage.get('daily_limit') is not None else '∞'}\n"
            f"Remaining: {usage.get('remaining') if usage.get('remaining') is not None else '—'}\n"
            f"Session model: {get_model_id() or '(API default)'}\n"
            f"Permissions: {get_permissions()}\n"
            f"Launch mode: {(me.get('launch_mode') or {}).get('enabled')}",
            title=f"{BRAND_NAME} status",
        )
    )


def _print_usage(client: ApiClient, session: ReplSession | None = None) -> None:
    if not client.token:
        console.print("[red]Not signed in.[/red]")
        return
    try:
        bundle = client.usage_bundle()
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]Error: {exc}[/red]")
        return
    from picode.diff_view import usage_lines_from_me

    me = bundle.get("me") or {}
    console.print(brand_panel("\n".join(usage_lines_from_me(me)), title="Account usage (/me)"))
    wallet = bundle.get("wallet")
    if isinstance(wallet, dict) and wallet:
        rows = [(str(k), terminal_text(v)) for k, v in wallet.items()]
        table = Table(title="Wallet (/billing/wallet)", show_header=True)
        table.add_column("Item")
        table.add_column("Value")
        for k, v in rows:
            table.add_row(k, v)
        console.print(table)
    report = bundle.get("token_report")
    if isinstance(report, dict) and report:
        # Keep raw keys from API — do not invent billing fields.
        flat: list[str] = []
        for key, val in report.items():
            if isinstance(val, (dict, list)):
                flat.append(f"{key}: {terminal_text(val)[:500]}")
            else:
                flat.append(f"{key}: {terminal_text(val)}")
        console.print(brand_panel("\n".join(flat[:40]), title="Token report (/me/token-report)"))
    if session is not None:
        totals = session.usage_totals or {}
        lines = [
            f"Session messages: {len(session.history)}",
            f"Estimated context tokens: ~{session.approx_tokens()}",
            f"Session turns (API): {totals.get('turns', 0)}",
            f"Session total prompt tokens: {totals.get('prompt_tokens', 0)}",
            f"Session total completion tokens: {totals.get('completion_tokens', 0)}",
            f"Session total tokens: {totals.get('total_tokens', 0)}",
        ]
        if session.last_usage:
            u = session.last_usage
            lines.append(
                f"Last reply — prompt: {u.get('prompt_tokens', 0)}, "
                f"completion: {u.get('completion_tokens', 0)}"
            )
            for key, val in u.items():
                if key not in ("prompt_tokens", "completion_tokens"):
                    lines.append(f"Last reply · {key}: {terminal_text(val)}")
        else:
            lines.append("Per-reply token detail appears after the first chat in this session.")
        console.print(brand_panel("\n".join(lines), title="This conversation"))


def _print_compact(session: ReplSession) -> None:
    turns = len(session.history) // 2
    approx = session.approx_tokens()
    lines = [
        f"Session messages: {len(session.history)} ({turns} turns)",
        f"Estimated context tokens: ~{approx}",
    ]
    if session.last_model_name or session.last_model_id:
        lines.append(
            f"Last model: {session.last_model_name or session.last_model_id}"
        )
    if session.last_usage:
        u = session.last_usage
        lines.append(
            f"Last API request — prompt: {u.get('prompt_tokens', 0)}, "
            f"completion: {u.get('completion_tokens', 0)}"
        )
    else:
        lines.append(
            "[dim]Usage details appear after the first chat in this session.[/dim]"
        )
    console.print(brand_panel("\n".join(lines), title="Context / compact"))


def _print_config() -> None:
    summary = config_summary()
    table = Table(title="PiCode configuration", show_header=True)
    table.add_column("Key")
    table.add_column("Value")
    for k, v in summary.items():
        table.add_row(k, str(v) if v is not None else "—")
    console.print(table)
    console.print("[dim]Path: ~/.picode/config.json[/dim]")


def do_chat(session: ReplSession, prompt: str) -> None:
    client = ApiClient()
    if not require_ai_credit(client, console):
        return
    model_id = get_model_id()
    extra = ""
    try:
        from picode.repo_index import format_context_block, query_repo_index

        hits = query_repo_index(prompt, limit=6)
        ctx = format_context_block(hits)
        if ctx:
            extra = "Use the repo index context when it is relevant.\n\n" + ctx
    except Exception:  # noqa: BLE001
        extra = ""

    def chat_fn(message: str, *, system: str, model_id: str | None, history: list) -> dict:
        return client.chat(message, system=system, model_id=model_id, history=history)

    try:
        with busy(console, t("status.thinking", brand=BRAND_NAME), kind="thinking"):
            result = run_tool_loop(
                prompt,
                chat_fn=chat_fn,
                model_id=model_id,
                history=session.history_for_api(),
                extra_system=extra,
            )
    except Exception as exc:  # noqa: BLE001
        print_api_error(console, exc)
        return
    stored = result.visible or (", ".join(t("ok.wrote", name=name) for name in result.wrote))
    session.add_turn(result.outgoing_prompt or prompt, stored or result.notice or "")
    if result.usage:
        session.record_usage(result.usage)
    if result.model_id:
        session.last_model_id = result.model_id
    if result.model_name or result.model_id:
        session.last_model_name = terminal_text(result.model_name, result.model_id)
    try:
        from picode.chat_store import save_chat

        if session.chat_id:
            save_chat(session)
    except Exception:  # noqa: BLE001
        pass
    console.print()
    if result.notice:
        console.print(f"[red]{result.notice}[/red]")
    for name in result.wrote:
        console.print(f"[green]{t('ok.wrote', name=name)}[/green]")
    if result.visible:
        console.print(Markdown(result.visible))
    elif not result.notice:
        console.print(f"[dim]{t('warn.empty_reply')}[/dim]")
    console.print()


def do_commit_suggest(session: ReplSession) -> None:
    client = ApiClient()
    if not require_ai_credit(client, console):
        return
    from picode.git_suggest import COMMIT_SYSTEM, git_snapshot

    snap = git_snapshot()
    if snap.get("ok") != "True":
        console.print(f"[red]git unavailable:[/red] {snap.get('status')}")
        return
    if not (snap.get("status") or snap.get("diff")):
        console.print("[yellow]No changes detected for commit.[/yellow]")
        return
    prompt = (
        f"Branch: {snap.get('branch')}\n\nSTATUS:\n{snap.get('status')}\n\n"
        f"DIFF:\n{snap.get('diff')}\n\nLOG:\n{snap.get('log')}"
    )
    try:
        with busy(console, t("status.suggest_commit"), kind="thinking"):
            data = client.chat(prompt, system=COMMIT_SYSTEM, model_id=get_model_id())
    except Exception as exc:  # noqa: BLE001
        print_api_error(console, exc)
        return
    reply = str(data.get("reply") or "")
    console.print(brand_panel(reply or "(empty)", title="Commit suggestion"))
    console.print("[dim]Copy the message and use git commit — the CLI does not commit for you.[/dim]")


def do_pr_suggest(session: ReplSession) -> None:
    client = ApiClient()
    if not require_ai_credit(client, console):
        return
    from picode.git_suggest import PR_SYSTEM, git_snapshot

    snap = git_snapshot()
    if snap.get("ok") != "True":
        console.print(f"[red]git unavailable:[/red] {snap.get('status')}")
        return
    prompt = (
        f"Branch: {snap.get('branch')}\n\nSTATUS:\n{snap.get('status')}\n\n"
        f"DIFF:\n{snap.get('diff')}\n\nLOG:\n{snap.get('log')}"
    )
    try:
        with busy(console, t("status.suggest_pr"), kind="thinking"):
            data = client.chat(prompt, system=PR_SYSTEM, model_id=get_model_id())
    except Exception as exc:  # noqa: BLE001
        print_api_error(console, exc)
        return
    reply = str(data.get("reply") or "")
    console.print(brand_panel(reply or "(empty)", title="PR suggestion"))
    console.print("[dim]Create the PR with gh pr create.[/dim]")


def do_read(path: str) -> None:
    root = project_root()
    try:
        text = read_project_file(path, root=root)
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        return
    console.print(brand_panel(text, title=path))


def do_edit(session: ReplSession, path: str, instruction: str) -> None:
    client = ApiClient()
    if not require_ai_credit(client, console):
        return
    root = project_root()
    try:
        original = read_project_file(path, root=root)
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]{exc}[/red]")
        return
    system = system_instruction(
        "Return ONLY the full updated file contents, no markdown fences and no commentary."
    )
    prompt = (
        f"File: {path}\nInstruction: {instruction}\n\n"
        f"Current contents:\n```\n{original}\n```\n\n"
        "Return the complete new file contents only."
    )
    model_id = get_model_id()
    try:
        with busy(console, t("status.suggest_edit"), kind="thinking"):
            data = client.chat(prompt, system=system, model_id=model_id)
    except Exception as exc:  # noqa: BLE001
        print_api_error(console, exc)
        return
    updated = str(data.get("reply") or data.get("text") or "").strip()
    if updated.startswith("```"):
        lines = updated.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        updated = "\n".join(lines)
    diff = "".join(
        difflib.unified_diff(
            original.splitlines(keepends=True),
            updated.splitlines(keepends=True),
            fromfile=f"a/{path}",
            tofile=f"b/{path}",
        )
    )
    session.last_diff = diff or "(no changes)"
    session.pending_edit_path = path
    session.pending_edit_content = updated
    preview = updated[:2000] + ("…" if len(updated) > 2000 else "")
    console.print(brand_panel(preview, title="Suggestion"))
    if diff:
        console.print(brand_panel(diff[:4000] + ("…" if len(diff) > 4000 else ""), title="diff"))
    console.print("[dim]/apply to apply · /discard to cancel · /diff[/dim]")


def handle_slash(
    line: str,
    session: ReplSession,
    *,
    on_login: Callable[[], bool],
    on_logout: Callable[[], None],
) -> bool:
    """Handle slash command. Returns False to exit REPL."""
    raw = line.strip()
    if not raw.startswith("/"):
        return True
    if raw == "/":
        print_command_menu(console)
        return True
    try:
        parts = shlex.split(raw)
    except ValueError as exc:
        console.print(f"[red]Invalid command: {exc}[/red]")
        return True
    if not parts:
        return True
    cmd = parts[0].lower()
    args = parts[1:]
    client = ApiClient()

    if cmd in ("/exit", "/quit", "/q"):
        return False
    if cmd in ("/help", "/h", "/?"):
        console.print(_slash_help())
        return True
    if cmd == "/language":
        if not args:
            console.print(t("help.language_usage", lang=get_ui_lang()))
            return True
        try:
            lang = set_ui_lang(args[0])
        except ValueError as exc:
            console.print(f"[red]{exc}[/red]")
            return True
        console.print(f"[green]{t('ok.language_set', lang=lang)}[/green]")
        return True
    if cmd == "/clear":
        console.clear()
        console.print(f"[dim]{t('ok.cleared')}[/dim]")
        return True
    if cmd == "/clean":
        session.reset()
        console.clear()
        console.print(f"[dim]{t('ok.cleaned')}[/dim]")
        return True
    if cmd == "/index":
        from picode.repo_index import build_repo_index, query_repo_index

        if not args:
            with busy(console, t("status.indexing"), kind="thinking"):
                idx = build_repo_index()
            console.print(
                f"[green]Indexed:[/green] {idx.get('file_count')} files · {idx.get('root')}"
            )
            return True
        hits = query_repo_index(" ".join(args), limit=12)
        if not hits:
            console.print(f"[yellow]{t('warn.no_hits')}[/yellow]")
            return True
        table = Table(title="repo index", show_header=True)
        table.add_column("path")
        table.add_column("symbols")
        for h in hits:
            table.add_row(str(h.get("path")), ", ".join((h.get("symbols") or [])[:6]))
        console.print(table)
        return True
    if cmd == "/commit":
        do_commit_suggest(session)
        return True
    if cmd == "/pr":
        do_pr_suggest(session)
        return True
    if cmd == "/login":
        on_login()
        return True
    if cmd == "/update":
        from picode import __version__
        from picode.updates import format_update_panel, run_self_update, update_notice

        notice = update_notice(force=True)
        if args and args[0].lower() == "install":
            if not notice:
                console.print(
                    f"[green]{t('ok.up_to_date', brand=BRAND_NAME, version=__version__)}[/green]"
                )
                return True
            code = run_self_update(notice["wheel_url"])
            if code == 0:
                console.print(f"[green]{t('ok.update_installed')}[/green]")
            else:
                console.print(f"[red]Error {code}[/red]\n{notice['upgrade_command']}")
            return True
        if notice:
            console.print(
                brand_panel(
                    format_update_panel(notice),
                    title=f"{BRAND_NAME} update",
                )
            )
        else:
            console.print(
                f"[green]{t('ok.up_to_date', brand=BRAND_NAME, version=__version__)}[/green]"
            )
        return True
    if cmd == "/logout":
        on_logout()
        console.print(f"[green]{t('ok.signed_out')}[/green]")
        return True
    if cmd == "/status":
        _print_status(client)
        return True
    if cmd in ("/cost", "/usage"):
        _print_usage(client, session)
        return True
    if cmd in ("/compact", "/context"):
        _print_compact(session)
        return True
    if cmd == "/config":
        _print_config()
        return True
    if cmd == "/reset":
        session.reset()
        console.print(f"[green]{t('ok.history_cleared')}[/green]")
        return True
    if cmd == "/diff":
        if session.last_diff:
            console.print(brand_panel(session.last_diff, title="Last diff"))
        else:
            console.print(f"[yellow]{t('warn.no_diff')}[/yellow]")
        return True
    if cmd == "/project":
        if not args:
            root = project_root()
            console.print(f"Project root: [bold]{root}[/bold]")
            console.print(f"PiCode temp: [dim]{project_picode_dir(root)}[/dim]")
            console.print(
                "[dim]Set: /project <path> · /project add <name> <path> · "
                "/project remove <name>[/dim]"
            )
            return True
        if args[0].lower() == "add" and len(args) >= 3:
            try:
                workspaces = add_workspace(args[1], " ".join(args[2:]).strip("\"'"))
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]Workspace added[/green] ({len(workspaces)} total)")
            return True
        if args[0].lower() in ("remove", "rm", "delete") and len(args) >= 2:
            try:
                workspaces = remove_workspace(args[1])
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]Workspace removed[/green] ({len(workspaces)} left)")
            return True
        try:
            p = set_project_dir(" ".join(args).strip("\"'"))
        except ValueError as exc:
            console.print(f"[red]{exc}[/red]")
            return True
        console.print(f"[green]Project set:[/green] {p}")
        console.print(f"[dim]PiCode temp: {project_picode_dir(p)}[/dim]")
        return True
    if cmd in ("/workspaces", "/ws"):
        switch_name = None
        if cmd == "/ws" and args:
            switch_name = args[0]
        elif cmd == "/workspaces" and args and args[0].lower() not in ("list", "ls"):
            switch_name = args[0]
        if switch_name:
            try:
                p = switch_workspace(switch_name)
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]workspace:[/green] {switch_name} → {p}")
            return True
        table = Table(title="Projects / workspaces", show_header=True)
        table.add_column("name")
        table.add_column("path")
        root = str(project_root())
        for w in list_workspaces():
            mark = " ✓" if w.get("path") == root else ""
            table.add_row(str(w.get("name", "?")) + mark, str(w.get("path", "")))
        console.print(table)
        console.print(
            "[dim]/ws <name> · /project add <name> <path> · /project remove <name>[/dim]"
        )
        return True
    if cmd == "/run":
        if not args:
            console.print("[yellow]/run <command…>[/yellow]")
            return True
        do_run(" ".join(args))
        return True
    if cmd == "/apply":
        apply_pending_edit(session)
        return True
    if cmd == "/discard":
        discard_pending_edit(session)
        return True
    if cmd in ("/permissions", "/perm"):
        if not args:
            mode = get_permissions()
            shell = get_shell_permissions()
            remote = get_remote_permissions()
            web = get_web_permissions()
            console.print(
                brand_panel(
                    f"Files: [bold]{mode}[/bold] · Shell: [bold]{shell}[/bold]\n"
                    f"SSH: [bold]{remote}[/bold] · Web: [bold]{web}[/bold]\n\n"
                    "  ask  — confirm before action (SSH/web default)\n"
                    "  auto — run without confirmation (files default)\n"
                    "  deny — block that capability\n\n"
                    "Set: /permissions ask|auto|deny\n"
                    "     /permissions shell|remote|web ask|auto|deny",
                    title="Permissions",
                )
            )
            return True
        kind = args[0].lower()
        if kind == "shell" and len(args) >= 2:
            try:
                mode = set_shell_permissions(args[1])
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]shell_permissions:[/green] {mode}")
            return True
        if kind == "remote" and len(args) >= 2:
            try:
                mode = set_remote_permissions(args[1])
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]remote_permissions:[/green] {mode}")
            return True
        if kind == "web" and len(args) >= 2:
            try:
                mode = set_web_permissions(args[1])
            except ValueError as exc:
                console.print(f"[red]{exc}[/red]")
                return True
            console.print(f"[green]web_permissions:[/green] {mode}")
            return True
        try:
            mode = set_permissions(args[0])
        except ValueError as exc:
            console.print(f"[red]{exc}[/red]")
            return True
        console.print(f"[green]permissions:[/green] {mode}")
        return True
    if cmd == "/ssh":
        do_ssh(args)
        return True
    if cmd in ("/model", "/models"):
        if not client.token:
            console.print(f"[red]{t('warn.not_signed_in')}[/red]")
            return True
        models = _fetch_models(client)
        current = get_model_id()
        if cmd == "/models" or (cmd == "/model" and not args):
            # Desktop sets models_picker_hook to open a Qt dropdown instead.
            if models_picker_hook is not None:
                chosen_id = models_picker_hook(models, current)
                if chosen_id:
                    set_model_id(str(chosen_id))
                    picked = next(
                        (m for m in models if str(m.get("id")) == str(chosen_id)),
                        None,
                    )
                    label = model_display_name(picked) if picked else str(chosen_id)
                    console.print(f"[green]{t('ok.model_set', name=label)}[/green]")
                return True
            _pick_and_set_model(models, current_id=current)
            return True
        picked = _resolve_model_arg(client, args[0], models)
        if not picked:
            console.print(f"[red]Model not found: {args[0]!r}. /models[/red]")
            return True
        set_model_id(str(picked["id"]))
        console.print(f"[green]{t('ok.model_set', name=model_display_name(picked))}[/green]")
        return True
    if cmd == "/read":
        if not args:
            console.print("[yellow]Usage: /read <path>[/yellow]")
            return True
        do_read(args[0])
        return True
    if cmd == "/edit":
        if len(args) < 2:
            console.print("[yellow]Usage: /edit <path> <instruction…>[/yellow]")
            return True
        do_edit(session, args[0], " ".join(args[1:]))
        return True

    known = ", ".join(n for n, _ in SLASH_COMMANDS[:8])
    console.print(
        f"[yellow]{t('warn.unknown_cmd', cmd=cmd)}[/yellow]\n"
        f"[dim]Commands: {known}… — /help[/dim]"
    )
    return True
