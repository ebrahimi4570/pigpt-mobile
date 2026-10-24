"""Pre-check before CLI calls that consume AI tokens (auth is separate)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from picode.api_client import ApiClient, ApiHttpError

if TYPE_CHECKING:
    pass

CREDIT_EXHAUSTED = (
    "AI usage credit exhausted (daily limit or spendable balance for today). "
    "Try again tomorrow (Tehran) or upgrade / add tokens in the app."
)
NOT_LOGGED_IN = "Not signed in. /login or picode login"
SESSION_EXPIRED = "API session expired — /login"


def ai_usage_blocked(client: ApiClient) -> str | None:
    """Return a user message if AI must not run; None if the API call may proceed."""
    if not client.token:
        return NOT_LOGGED_IN
    try:
        me = client.me()
    except ApiHttpError as exc:
        if exc.status_code == 401:
            return SESSION_EXPIRED
        return None
    except Exception:  # noqa: BLE001
        return None

    plan = me.get("plan") or {}
    if not plan:
        return "No active plan — https://pigpt.ir/app/plans"

    uses_tokens = bool(plan.get("uses_tokens"))
    if not uses_tokens:
        return "PiCode is not available on the free plan — https://pigpt.ir/app/plans"

    usage = me.get("usage") or {}
    wallet = me.get("wallet") or {}

    if wallet.get("can_generate") is False:
        return _credit_message(usage, wallet)

    spendable = usage.get("spendable_today")
    if spendable is not None and int(spendable) <= 0:
        return _credit_message(usage, wallet)

    return None


def _credit_message(usage: dict, wallet: dict) -> str:
    bal = usage.get("wallet_balance")
    if bal is None:
        bal = wallet.get("balance")
    extra = ""
    if bal is not None and int(bal) > 0:
        extra = f" Wallet balance: {int(bal):,} tokens — today's plan cap is used up."
    return CREDIT_EXHAUSTED + extra


def require_ai_credit(client: ApiClient, console) -> bool:
    """Print block reason and return False when AI must not run."""
    msg = ai_usage_blocked(client)
    if not msg:
        return True
    console.print(f"[red]{msg}[/red]")
    console.print("[dim]Still signed in — /status · /cost[/dim]")
    return False
