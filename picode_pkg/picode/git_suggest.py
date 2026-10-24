"""Git helpers for /commit and /pr suggestions."""

from __future__ import annotations

import subprocess
from pathlib import Path

from picode.config_helpers import project_root
from picode.language import system_instruction


def _run(args: list[str], cwd: Path) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=60,
            encoding="utf-8",
            errors="replace",
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, str(exc)
    out = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, out.strip()


def git_snapshot(root: Path | None = None) -> dict[str, str]:
    root = root or project_root()
    status_code, status = _run(["git", "status", "--short"], root)
    diff_code, diff = _run(["git", "diff", "HEAD"], root)
    if not diff:
        _, diff = _run(["git", "diff", "--cached"], root)
    branch_code, branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], root)
    log_code, log = _run(["git", "log", "-8", "--oneline"], root)
    return {
        "ok": str(status_code == 0 and branch_code == 0),
        "branch": branch if branch_code == 0 else "",
        "status": status if status_code == 0 else status,
        "diff": (diff if diff_code == 0 else "")[:14000],
        "log": log if log_code == 0 else "",
    }


COMMIT_SYSTEM = system_instruction(
    "Propose ONE conventional commit message (type(scope): summary) "
    "and a short body. Write SUBJECT and BODY in English. No code fences. "
    "Output exactly:\nSUBJECT: ...\nBODY: ..."
)

PR_SYSTEM = system_instruction(
    "From the git status/diff/log, draft a GitHub PR in English. "
    "Output exactly:\nTITLE: ...\nSUMMARY:\n- ...\nTEST PLAN:\n- ...\n"
)
