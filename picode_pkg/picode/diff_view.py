"""Unified diffs for pending edits / write_file preview."""

from __future__ import annotations

import difflib
from collections.abc import Callable
from typing import Any

# Desktop / CLI hook: (rel_path, old_text, new_text, unified_diff) -> allow write
write_preview_hook: Callable[[str, str, str, str], bool] | None = None


def make_unified_diff(path: str, old: str, new: str) -> str:
    old_lines = (old or "").splitlines(keepends=True)
    new_lines = (new or "").splitlines(keepends=True)
    if not old_lines and not new_lines:
        return "(empty)"
    if old == new:
        return "(no changes)"
    from_label = f"a/{path}" if old else "/dev/null"
    to_label = f"b/{path}"
    diff = "".join(
        difflib.unified_diff(
            old_lines,
            new_lines,
            fromfile=from_label,
            tofile=to_label,
        )
    )
    return diff or "(no changes)"


def preview_write_allowed(
    path: str,
    old: str,
    new: str,
    *,
    mode: str,
    confirm_fn: Callable[[str], bool] | None = None,
) -> tuple[bool, str]:
    """Return (allowed, unified_diff). Uses write_preview_hook when set."""
    from picode.i18n import t

    diff = make_unified_diff(path, old, new)
    if write_preview_hook is not None:
        try:
            ok = bool(write_preview_hook(path, old or "", new or "", diff))
        except Exception:  # noqa: BLE001
            ok = False
        return ok, diff
    if mode == "ask":
        action = t("confirm.apply_patch") + f"\n{path}"
        if confirm_fn is not None:
            return bool(confirm_fn(action)), diff
        try:
            from picode.slash import confirm_hook

            if confirm_hook is not None:
                return bool(confirm_hook(action)), diff
        except Exception:  # noqa: BLE001
            pass
        try:
            import typer

            return bool(typer.confirm(action, default=False)), diff
        except Exception:  # noqa: BLE001
            return False, diff
    return True, diff


def format_diff_panel(diff: str, *, limit: int = 6000) -> str:
    body = diff or "(no changes)"
    if len(body) > limit:
        return body[:limit] + "\n…"
    return body


def usage_lines_from_me(me: dict[str, Any]) -> list[str]:
    """Flatten useful /me fields for Settings → Usage (no invented billing)."""
    from picode.api_client import plan_display_name
    from picode.i18n import t
    from picode.language import terminal_text

    lines: list[str] = []
    plan = me.get("plan") or {}
    usage = me.get("usage") or {}
    wallet = me.get("wallet") if isinstance(me.get("wallet"), dict) else None
    lines.append(f"{t('desk.usage_plan')}: {plan_display_name(plan)} ({plan.get('code')})")
    if me.get("display_name"):
        lines.append(f"display_name: {terminal_text(me.get('display_name'))}")
    if me.get("email"):
        lines.append(f"email: {terminal_text(me.get('email'))}")
    if me.get("phone"):
        lines.append(f"phone: {terminal_text(me.get('phone'))}")
    lines.append(
        f"{t('desk.usage_messages')}: {usage.get('messages_used', '—')} / "
        f"{usage.get('daily_limit') if usage.get('daily_limit') is not None else '∞'}"
    )
    lines.append(
        f"{t('desk.usage_remaining')}: "
        f"{usage.get('remaining') if usage.get('remaining') is not None else '—'}"
    )
    for key in (
        "daily_tokens_used",
        "daily_token_limit",
        "daily_tokens_remaining",
        "spendable_today",
        "daily_unlimited",
        "wallet_balance",
        "daily_timezone",
    ):
        if key in usage and usage.get(key) is not None:
            lines.append(f"{key}: {usage.get(key)}")
    for key, val in usage.items():
        if key in (
            "messages_used",
            "daily_limit",
            "remaining",
            "daily_tokens_used",
            "daily_token_limit",
            "daily_tokens_remaining",
            "spendable_today",
            "daily_unlimited",
            "wallet_balance",
            "daily_timezone",
        ):
            continue
        lines.append(f"{key}: {terminal_text(val)}")
    if wallet:
        lines.append("")
        lines.append(t("desk.usage_wallet_title"))
        for key, val in wallet.items():
            lines.append(f"{key}: {terminal_text(val)}")
    sub = me.get("subscription")
    if isinstance(sub, dict) and sub:
        lines.append("")
        lines.append(t("desk.usage_subscription_title"))
        for key, val in sub.items():
            lines.append(f"{key}: {terminal_text(val)}")
    return lines
