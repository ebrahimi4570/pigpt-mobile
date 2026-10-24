"""Local file tools for normal PiCode chat.

The API chat endpoint returns text only. The CLI asks the model for a
``picode-tool`` block, then writes inside the project folder itself.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from picode.activity import report as report_activity
from picode.config_helpers import (
    chat_file_writes_allowed,
    get_permissions,
    get_remote_permissions,
    get_web_permissions,
    project_root,
)
from picode.files import read_project_file, write_project_file
from picode.i18n import t
from picode.language import contains_persian, system_instruction
from picode.mentions import expand_mentions

FILE_TOOL_INSTRUCTION = (
    "You run on the user's computer as PiCode, inside the active project folder. "
    "You have local file tools, optional SSH remote tools, and optional web tools. "
    "When the user asks to create, save, write, or edit a file, you MUST use the "
    "file tools. Never say you have no filesystem. "
    "Never tell the user to copy a file onto disk themselves.\n"
    "When the user asks you to connect to a server, run a remote command, or use SSH, "
    "you MUST use the ssh_exec tool with a saved connection profile. "
    "Never say you cannot connect to servers or that you lack SSH.\n"
    "When the user asks to search the web, look something up online, or fetch a URL, "
    "you MUST use web_search or fetch_url. "
    "Never say you have no internet or cannot browse. "
    "If a tool is denied by permissions, say briefly that remote/web access is off "
    "in settings — do not invent browsing or SSH results.\n"
    "Cite that web facts come from the tool results.\n"
    "To write or create a file, reply with only this fenced block:\n"
    "```picode-tool\n"
    "write_file\n"
    "path: relative/path.ext\n"
    "-----\n"
    "full file text\n"
    "```\n"
    "To read a file before editing it, reply with only:\n"
    "```picode-tool\n"
    "read_file\n"
    "path: relative/path.ext\n"
    "```\n"
    "To run a command on a saved SSH connection:\n"
    "```picode-tool\n"
    "ssh_exec\n"
    "connection: profile-name\n"
    "command: remote shell command\n"
    "```\n"
    "(Omit connection to use the user's default SSH profile.)\n"
    "To search the web:\n"
    "```picode-tool\n"
    "web_search\n"
    "query: search terms\n"
    "```\n"
    "To fetch a public http(s) URL:\n"
    "```picode-tool\n"
    "fetch_url\n"
    "url: https://example.com/path\n"
    "```\n"
    "JSON is also accepted inside the same fence, e.g. "
    '{"tool":"write_file","path":"relative/path.ext","content":"full file text"} '
    'or {"tool":"ssh_exec","connection":"prod","command":"uptime"} '
    'or {"tool":"web_search","query":"…"}.\n'
    "Paths must stay inside the project folder. "
    "After the tool runs, continue briefly in the language of the user's message."
)

def writes_off_notice() -> str:
    return t("warn.writes_off")


def no_file_notice() -> str:
    return t("warn.no_file")


def remote_denied_notice() -> str:
    return t("warn.remote_denied")


def web_denied_notice() -> str:
    return t("warn.web_denied")


# Backward-compatible English defaults (tests / imports).
WRITES_OFF_NOTICE = "File writes are turned off in settings. /permissions auto"
NO_FILE_NOTICE = "No file was written. Include the file name and contents, then try again."

_FENCE_RE = re.compile(
    r"```(?:picode-tool|picode-file)[^\n]*\r?\n(.*?)```",
    re.DOTALL | re.IGNORECASE,
)
_CODE_FENCE_RE = re.compile(r"```([^\n`]*)\r?\n(.*?)```", re.DOTALL)
_XML_RE = re.compile(
    r'<picode_write\s+path="([^"]+)">\s*(.*?)\s*</picode_write>',
    re.DOTALL | re.IGNORECASE,
)
_FILENAME_RE = re.compile(
    r"((?:[\w.-]+/)*[\w.-]+\.(?:html?|css|js|jsx|ts|tsx|py|json|md|txt|xml|svg|vue|php|rb|go|rs|java|c|h|cpp|yml|yaml|toml|sh|ps1))",
    re.IGNORECASE,
)
_EN_FILE_REFUSAL_RE = re.compile(
    r"("
    r"i (?:can(?:not|'t)|am unable to|don't|do not) .{0,120}(?:write|save|create|edit|modify)"
    r"|cannot (?:write|save|create|edit|modify)"
    r"|can't (?:write|save|create|edit|modify)"
    r"|unable to (?:write|save|create|edit|modify)"
    r"|no (?:filesystem|file system)"
    r"|do(?:n't| not) have (?:a |the )?(?:filesystem|file system)"
    r"|only (?:provide|give) (?:you )?(?:instructions|the code|a copy)"
    r")",
    re.IGNORECASE | re.DOTALL,
)
_EN_NET_REFUSAL_RE = re.compile(
    r"("
    r"i (?:can(?:not|'t)|am unable to|don't|do not) .{0,140}"
    r"(?:internet|online|browse|search the web|access the (?:web|internet)|"
    r"connect (?:to |a )?(?:server|ssh|remote)|ssh|remote (?:access|server))"
    r"|no (?:internet|web) access"
    r"|do(?:n't| not) have (?:internet|web|network|ssh)"
    r"|cannot (?:browse|search online|connect|ssh)"
    r"|can't (?:browse|search online|connect|ssh)"
    r")",
    re.IGNORECASE | re.DOTALL,
)
_FA_REFUSAL_RE = re.compile(r"نمی\u200c?توانم|نمي\u200c?توانم|امکان (?:ذخیره|نوشتن)")
_FA_NET_REFUSAL_RE = re.compile(
    r"(?:اینترنت|آنلاین|وب|سرور|SSH|اس‌اس‌اچ|اتصال).{0,40}(?:ندارم|نیست)|"
    r"(?:نمی\u200c?توانم|نمي\u200c?توانم).{0,80}(?:اینترنت|آنلاین|جستجو|سرور|SSH|اتصال)",
    re.IGNORECASE,
)
_COMMAND_START_RE = re.compile(
    r"^(?:echo|cat|printf|tee|python|pip|npm|npx|del|rm|mkdir|cd|copy|type)\b",
    re.IGNORECASE,
)
_WRITE_NAMES = {"write_file", "write", "save_file", "create_file"}
_READ_NAMES = {"read_file", "read"}
_SSH_NAMES = {"ssh_exec", "ssh", "remote_exec", "run_ssh"}
_WEB_SEARCH_NAMES = {"web_search", "search_web", "search"}
_FETCH_NAMES = {"fetch_url", "fetch", "browse_url", "http_get"}

ChatFn = Callable[..., dict[str, Any]]
ConfirmFn = Callable[[str], bool]


@dataclass
class ChatTurnResult:
    visible: str = ""
    wrote: list[str] = field(default_factory=list)
    notice: str = ""
    file_intent: bool = False
    success: bool = False
    usage: dict[str, Any] | None = None
    model_id: str = ""
    model_name: str = ""
    outgoing_prompt: str = ""

    def user_facing(self) -> str:
        parts: list[str] = []
        if self.notice:
            parts.append(self.notice)
        for name in self.wrote:
            parts.append(f"Wrote {name}")
        if self.visible:
            parts.append(self.visible)
        return "\n".join(parts).strip()


def build_chat_system(extra: str = "") -> str:
    return system_instruction(FILE_TOOL_INSTRUCTION, extra)


def looks_like_file_refusal(text: str) -> bool:
    raw = text or ""
    if _EN_FILE_REFUSAL_RE.search(raw):
        return True
    if _FA_REFUSAL_RE.search(raw) and re.search(r"فایل|ذخیره|سیستم|بنویس", raw):
        return True
    return False


def looks_like_net_refusal(text: str) -> bool:
    raw = text or ""
    if _EN_NET_REFUSAL_RE.search(raw):
        return True
    if _FA_NET_REFUSAL_RE.search(raw):
        return True
    return False


def user_wants_ssh(text: str) -> bool:
    raw = text or ""
    if re.search(r"\b(ssh|sftp|scp)\b", raw, re.IGNORECASE):
        return True
    if re.search(r"سرور|ریموت|از راه دور|روی سرور|وصل شو به", raw):
        if re.search(r"اجرا|دستور|کانکت|وصل|ssh|SSH|لاگین|ورود", raw, re.IGNORECASE):
            return True
    if re.search(
        r"\b(connect to|remote (?:server|host|command)|run on (?:the )?server)\b",
        raw,
        re.IGNORECASE,
    ):
        return True
    return False


def user_wants_web(text: str) -> bool:
    raw = text or ""
    if re.search(
        r"\b(search (?:the )?(?:web|internet|online)|google|look up online|"
        r"browse|fetch (?:url|the page)|https?://)\b",
        raw,
        re.IGNORECASE,
    ):
        return True
    if re.search(r"جستجو|اینترنت|آنلاین|وب|سایت|آدرس\s*https?", raw):
        return True
    return False


def user_wants_file_write(text: str) -> bool:
    raw = text or ""
    has_name = _FILENAME_RE.search(raw) is not None
    if re.search(r"ذخیره|در مسیر جاری", raw) and (has_name or "فایل" in raw):
        return True
    if re.search(r"به اسم", raw) and has_name:
        return True
    if has_name and re.search(
        r"\b(save|create|write|edit|update|overwrite)\b",
        raw,
        re.IGNORECASE,
    ):
        return True
    if re.search(r"\b(save|create) (this|it|a file|the file)\b", raw, re.IGNORECASE):
        return True
    if has_name and re.search(r"current (directory|folder|path)", raw, re.IGNORECASE):
        return True
    return False


def turn_succeeded(result: ChatTurnResult) -> bool:
    """A file turn is success only when a file was written and the reply is not a refusal."""
    if looks_like_file_refusal(result.visible) or looks_like_file_refusal(result.user_facing()):
        return False
    if not result.file_intent:
        return bool(result.visible.strip())
    return bool(result.wrote) and bool(result.visible.strip())


def parse_tool_calls(text: str) -> list[dict[str, str]]:
    calls: list[dict[str, str]] = []
    for match in _FENCE_RE.finditer(text or ""):
        parsed = _parse_tool_body(match.group(1).strip())
        if parsed:
            calls.append(parsed)
    for path, content in _XML_RE.findall(text or ""):
        calls.append({"tool": "write_file", "path": path.strip(), "content": content})
    if calls:
        return calls
    stripped = (text or "").strip()
    if stripped.startswith("{") and stripped.endswith("}"):
        parsed = _parse_tool_body(stripped)
        if parsed:
            return [parsed]
    return []


def strip_tool_blocks(text: str) -> str:
    cleaned = _FENCE_RE.sub("", text or "")
    cleaned = _XML_RE.sub("", cleaned)
    return cleaned.strip()


def saved_confirmation(names: list[str], user_text: str) -> str:
    shown = ", ".join(names)
    if contains_persian(user_text):
        return f"فایل ذخیره شد: {shown}"
    return f"Saved {shown}."


def _ask_confirm(action: str, confirm_fn: ConfirmFn | None) -> bool:
    if confirm_fn is not None:
        return bool(confirm_fn(action))
    try:
        from picode.slash import confirm_hook

        if confirm_hook is not None:
            return bool(confirm_hook(action))
    except Exception:  # noqa: BLE001
        pass
    try:
        import typer

        return bool(typer.confirm(action, default=False))
    except Exception:  # noqa: BLE001
        return False


def run_tool_loop(
    prompt: str,
    *,
    chat_fn: ChatFn,
    model_id: str | None = None,
    history: list[dict[str, str]] | None = None,
    extra_system: str = "",
    permissions: str | None = None,
    root: Path | None = None,
    confirm_fn: ConfirmFn | None = None,
) -> ChatTurnResult:
    mode = permissions if permissions is not None else get_permissions()
    folder = (root or project_root()).resolve()
    file_intent = user_wants_file_write(prompt)
    ssh_intent = user_wants_ssh(prompt)
    web_intent = user_wants_web(prompt)
    outgoing = expand_mentions(prompt, folder)
    result = ChatTurnResult(file_intent=file_intent, outgoing_prompt=outgoing)
    if file_intent and not chat_file_writes_allowed(mode):
        result.notice = writes_off_notice()
        result.success = False
        return result

    system = build_chat_system(extra_system)
    transcript = list(history or [])
    message = outgoing
    forced = False
    forced_net = False
    fed_back = 0
    last_reply = ""
    last_data: dict[str, Any] = {}

    for _round in range(6):
        report_activity("thinking", t("status.thinking", brand="PiCode"))
        last_data = chat_fn(
            message,
            system=system,
            model_id=model_id,
            history=transcript,
        )
        last_reply = str(last_data.get("reply") or last_data.get("text") or "")
        calls = parse_tool_calls(last_reply)
        if not calls and file_intent:
            salvaged = salvage_write(prompt, last_reply)
            if salvaged:
                calls = [salvaged]
        if not calls and file_intent and not forced and looks_like_file_refusal(last_reply):
            forced = True
            transcript = _extend(transcript, message, "I will use the local write_file tool.")
            message = (
                "The previous reply did not write the file. "
                "Reply with only one picode-tool write_file block for the user's request. "
                "Include the full file contents. Do not claim you cannot write files.\n\n"
                f"User request:\n{prompt[:8000]}"
            )
            continue
        if (
            not calls
            and (ssh_intent or web_intent)
            and not forced_net
            and looks_like_net_refusal(last_reply)
        ):
            forced_net = True
            which = []
            if ssh_intent:
                which.append("ssh_exec")
            if web_intent:
                which.append("web_search or fetch_url")
            transcript = _extend(transcript, message, "I will use the available network tools.")
            message = (
                "The previous reply incorrectly claimed no internet or no server access. "
                f"Reply with only a picode-tool block using {' / '.join(which)}. "
                "Do not refuse.\n\n"
                f"User request:\n{prompt[:8000]}"
            )
            continue
        if not calls:
            break

        wrote, errors, notes, blocked_kind = _execute_calls(
            calls, folder, mode, confirm_fn=confirm_fn
        )
        result.wrote.extend(wrote)
        if blocked_kind == "files" and not wrote and not notes:
            result.notice = writes_off_notice()
            last_reply = ""
            break
        if blocked_kind == "remote" and not notes and not wrote:
            result.notice = remote_denied_notice()
            last_reply = ""
            break
        if blocked_kind == "web" and not notes and not wrote:
            result.notice = web_denied_notice()
            last_reply = ""
            break
        if wrote and not notes and not errors:
            report_activity("thinking", t("status.thinking", brand="PiCode"))
            confirm = _confirm_write(
                chat_fn, system, model_id, transcript, message, result.wrote, prompt
            )
            last_data = confirm.get("data") or last_data
            last_reply = str(confirm.get("reply") or "")
            extra_calls = [
                call for call in parse_tool_calls(last_reply) if call.get("tool") == "write_file"
            ]
            if extra_calls and chat_file_writes_allowed(mode):
                more, _errors, _notes, _blocked = _execute_calls(
                    extra_calls, folder, mode, confirm_fn=confirm_fn
                )
                result.wrote.extend(more)
            break
        if (notes or errors) and fed_back < 3:
            fed_back += 1
            transcript = _extend(transcript, message, "Requested a PiCode tool.")
            chunks = notes + [f"error: {item}" for item in errors]
            for err in errors:
                report_activity("error", t("status.error", detail=err))
            follow = (
                "Tool results:\n"
                + "\n".join(chunks)
                + "\nUse these tool results. Cite web_search/fetch_url as the source when relevant. "
                "If a file still needs writing, reply with only a write_file block. "
                "If more remote/web work is needed, reply with only another picode-tool block. "
                "Otherwise answer the user briefly."
            )
            message = follow
            continue
        if errors and file_intent and not result.wrote:
            result.notice = errors[0]
            report_activity("error", t("status.error", detail=errors[0]))
            last_reply = ""
        break

    _apply_meta(result, last_data)
    result.visible = _visible_text(last_reply, result.wrote, prompt)
    if file_intent and not result.wrote and not result.notice:
        if looks_like_file_refusal(last_reply) or not result.visible:
            result.notice = no_file_notice()
            result.visible = ""
    if result.wrote and (not result.visible or looks_like_file_refusal(result.visible)):
        result.visible = saved_confirmation(result.wrote, prompt)
    result.success = turn_succeeded(result)
    report_activity("done", t("status.done"))
    return result


def salvage_write(user_text: str, reply: str) -> dict[str, str] | None:
    path = extract_rel_path(user_text) or extract_rel_path(reply)
    if not path:
        return None
    for source in (reply, user_text):
        body = _extract_code_body(source)
        if body:
            return {"tool": "write_file", "path": path, "content": body}
    markup = _extract_markup(user_text) or _extract_markup(reply)
    if markup:
        return {"tool": "write_file", "path": path, "content": markup}
    return None


def extract_rel_path(text: str) -> str | None:
    match = _FILENAME_RE.search(text or "")
    if not match:
        return None
    try:
        return _safe_rel(match.group(1))
    except PermissionError:
        return None


def _parse_tool_body(body: str) -> dict[str, str] | None:
    if body.startswith("{"):
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            data = None
        if isinstance(data, dict):
            tool = str(data.get("tool") or data.get("name") or "").strip().lower()
            path = str(data.get("path") or "").strip()
            if tool in _READ_NAMES and path:
                return {"tool": "read_file", "path": path}
            if tool in _WRITE_NAMES and path:
                content = data.get("content")
                return {
                    "tool": "write_file",
                    "path": path,
                    "content": "" if content is None else str(content),
                }
            if tool in _SSH_NAMES:
                return {
                    "tool": "ssh_exec",
                    "connection": str(data.get("connection") or data.get("host") or "").strip(),
                    "command": str(data.get("command") or data.get("cmd") or ""),
                }
            if tool in _WEB_SEARCH_NAMES:
                return {
                    "tool": "web_search",
                    "query": str(data.get("query") or data.get("q") or "").strip(),
                }
            if tool in _FETCH_NAMES:
                return {
                    "tool": "fetch_url",
                    "url": str(data.get("url") or "").strip(),
                }
    lines = body.splitlines()
    if not lines:
        return None
    tool = lines[0].strip().lower()
    fields: dict[str, str] = {}
    path = ""
    content: list[str] = []
    in_content = False
    for line in lines[1:]:
        if not in_content and line.strip() == "-----":
            in_content = True
            continue
        if in_content:
            content.append(line)
            continue
        if ":" in line:
            key, val = line.split(":", 1)
            key_l = key.strip().lower()
            val_s = val.strip()
            if key_l == "path":
                path = val_s
            else:
                fields[key_l] = val_s
    if tool in _READ_NAMES and path:
        return {"tool": "read_file", "path": path}
    if tool in _WRITE_NAMES and path and in_content:
        return {"tool": "write_file", "path": path, "content": "\n".join(content)}
    if tool in _SSH_NAMES:
        cmd = fields.get("command") or fields.get("cmd") or ""
        if in_content and content:
            cmd = "\n".join(content)
        return {
            "tool": "ssh_exec",
            "connection": fields.get("connection") or fields.get("host") or "",
            "command": cmd,
        }
    if tool in _WEB_SEARCH_NAMES:
        return {
            "tool": "web_search",
            "query": fields.get("query") or fields.get("q") or "",
        }
    if tool in _FETCH_NAMES:
        return {"tool": "fetch_url", "url": fields.get("url") or ""}
    return None


def _execute_calls(
    calls: list[dict[str, str]],
    root: Path,
    mode: str,
    *,
    confirm_fn: ConfirmFn | None = None,
) -> tuple[list[str], list[str], list[str], str | None]:
    """Returns wrote, errors, notes, blocked_kind (files|remote|web|None)."""
    wrote: list[str] = []
    errors: list[str] = []
    notes: list[str] = []
    blocked_kind: str | None = None
    for call in calls:
        tool = call.get("tool")
        if tool == "read_file":
            try:
                rel = _safe_rel(call.get("path") or "")
                report_activity("reading", t("status.reading", path=rel))
                text = read_project_file(rel, root=root)
            except Exception as exc:  # noqa: BLE001
                errors.append(str(exc))
                continue
            notes.append(f"read_file {rel} ok\n{text[:12000]}")
            continue
        if tool == "write_file":
            if not chat_file_writes_allowed(mode):
                blocked_kind = "files"
                continue
            try:
                rel = _safe_rel(call.get("path") or "")
                content = call.get("content")
                if content is None:
                    raise ValueError("Missing file contents")
                if len(content) > 500_000:
                    raise ValueError("File is too large")
                old_text = ""
                try:
                    old_text = read_project_file(rel, root=root)
                except Exception:  # noqa: BLE001
                    old_text = ""
                from picode.diff_view import (
                    format_diff_panel,
                    make_unified_diff,
                    write_preview_hook,
                )

                diff = make_unified_diff(rel, old_text, content)
                # Desktop (write_preview_hook): always show Apply/Skip diff dialog.
                # CLI: print a short unified diff; permissions ask|auto still write
                # (ask only gates /apply — see config_helpers.chat_file_writes_allowed).
                if write_preview_hook is not None:
                    try:
                        if not bool(write_preview_hook(rel, old_text, content, diff)):
                            notes.append(f"write_file {rel}: skipped by user")
                            continue
                    except Exception:  # noqa: BLE001
                        notes.append(f"write_file {rel}: skipped by user")
                        continue
                elif diff not in ("(no changes)", "(empty)"):
                    try:
                        from picode.slash import console as slash_console
                        from picode.ui import brand_panel

                        slash_console.print(
                            brand_panel(format_diff_panel(diff, limit=3500), title=f"diff · {rel}")
                        )
                    except Exception:  # noqa: BLE001
                        pass
                report_activity("writing", t("status.writing", path=rel))
                write_project_file(rel, content, root=root)
            except Exception as exc:  # noqa: BLE001
                errors.append(str(exc))
                continue
            wrote.append(rel)
            notes.append(f"write_file {rel}: saved")
            continue
        if tool == "ssh_exec":
            remote_mode = get_remote_permissions()
            if remote_mode == "deny":
                blocked_kind = "remote"
                continue
            conn = (call.get("connection") or "").strip() or None
            cmd = call.get("command") or ""
            label = conn or "(default)"
            if remote_mode == "ask":
                if not _ask_confirm(t("confirm.ssh", connection=label, cmd=cmd[:120]), confirm_fn):
                    notes.append("ssh_exec cancelled by user")
                    continue
            try:
                from picode.ssh_remote import run_ssh_command

                data = run_ssh_command(cmd, connection=conn)
            except Exception as exc:  # noqa: BLE001
                errors.append(str(exc))
                continue
            notes.append(
                f"ssh_exec {data.get('connection')} exit={data.get('exit_status')}\n"
                f"$ {data.get('command')}\n"
                f"{data.get('stdout') or ''}"
                + (f"\nstderr:\n{data.get('stderr')}" if data.get("stderr") else "")
            )
            continue
        if tool == "web_search":
            web_mode = get_web_permissions()
            if web_mode == "deny":
                blocked_kind = "web"
                continue
            query = call.get("query") or ""
            if web_mode == "ask":
                if not _ask_confirm(t("confirm.web_search", query=query[:120]), confirm_fn):
                    notes.append("web_search cancelled by user")
                    continue
            try:
                from picode.web_tools import format_search_note, web_search

                data = web_search(query)
                notes.append(format_search_note(data))
            except Exception as exc:  # noqa: BLE001
                errors.append(str(exc))
            continue
        if tool == "fetch_url":
            web_mode = get_web_permissions()
            if web_mode == "deny":
                blocked_kind = "web"
                continue
            url = call.get("url") or ""
            if web_mode == "ask":
                if not _ask_confirm(t("confirm.web_fetch", url=url[:160]), confirm_fn):
                    notes.append("fetch_url cancelled by user")
                    continue
            try:
                from picode.web_tools import fetch_url, format_fetch_note

                data = fetch_url(url)
                notes.append(format_fetch_note(data))
            except Exception as exc:  # noqa: BLE001
                errors.append(str(exc))
            continue
    return wrote, errors, notes, blocked_kind


def _confirm_write(
    chat_fn: ChatFn,
    system: str,
    model_id: str | None,
    transcript: list[dict[str, str]],
    message: str,
    wrote: list[str],
    prompt: str,
) -> dict[str, Any]:
    follow = _extend(transcript, message, "Wrote the file with the local tool.")
    note = (
        "Tool results:\n"
        + "\n".join(f"write_file {name}: saved" for name in wrote)
        + "\n\nConfirm briefly in the language of the user's message that the file is saved. "
        "Do not repeat the file. Do not claim you lack a filesystem.\n\n"
        f"User request:\n{prompt[:4000]}"
    )
    try:
        data = chat_fn(note, system=system, model_id=model_id, history=follow)
    except Exception:  # noqa: BLE001
        return {"reply": "", "data": {}}
    return {"reply": str(data.get("reply") or data.get("text") or ""), "data": data}


def _visible_text(reply: str, wrote: list[str], prompt: str) -> str:
    cleaned = strip_tool_blocks(reply).strip()
    if wrote and (not cleaned or looks_like_file_refusal(cleaned)):
        return saved_confirmation(wrote, prompt)
    if looks_like_file_refusal(cleaned):
        return ""
    return cleaned


def _extract_code_body(text: str) -> str | None:
    for match in _CODE_FENCE_RE.finditer(text or ""):
        lang = match.group(1).strip().lower()
        if lang in ("picode-tool", "picode-file"):
            continue
        body = match.group(2).strip()
        if not body or _COMMAND_START_RE.match(body):
            continue
        if "\n" not in body and _FILENAME_RE.fullmatch(body):
            continue
        return body
    return None


def _extract_markup(text: str) -> str | None:
    match = re.search(
        r"(<!doctype html\b[\s\S]+|<\s*html\b[\s\S]+</\s*html\s*>)",
        text or "",
        re.IGNORECASE,
    )
    if not match:
        return None
    return match.group(1).strip()


def _safe_rel(path: str) -> str:
    raw = (path or "").strip().strip('"').strip("'").replace("\\", "/")
    if not raw or raw.startswith("/") or re.match(r"^[A-Za-z]:", raw):
        raise PermissionError("Path must stay inside the project folder")
    parts = [part for part in raw.split("/") if part not in ("", ".")]
    if not parts or any(part == ".." for part in parts):
        raise PermissionError("Path must stay inside the project folder")
    return "/".join(parts)


def _extend(history: list[dict[str, str]], user: str, assistant: str) -> list[dict[str, str]]:
    user_text = (user or "").strip() or "(continue)"
    assistant_text = (assistant or "").strip() or "(tool)"
    return [
        *history,
        {"role": "user", "content": user_text[:30000]},
        {"role": "assistant", "content": assistant_text[:30000]},
    ]


def _apply_meta(result: ChatTurnResult, data: dict[str, Any]) -> None:
    usage = data.get("usage")
    if isinstance(usage, dict):
        result.usage = usage
    if data.get("model_id"):
        result.model_id = str(data["model_id"])
    if data.get("model_name"):
        result.model_name = str(data["model_name"])
