"""Check published PiCode version vs local install."""

from __future__ import annotations

import re
import subprocess
import sys
import time
from typing import Any

from picode import BRAND_NAME, PRODUCT, __version__
from picode.api_client import ApiClient, api_base, load_config, save_config

_CHECK_INTERVAL_SEC = 12 * 3600


def parse_version(version: str) -> tuple[int, ...]:
    parts: list[int] = []
    for piece in re.split(r"[.\-+]", (version or "0").strip()):
        if not piece:
            continue
        m = re.match(r"^(\d+)", piece)
        parts.append(int(m.group(1)) if m else 0)
    return tuple(parts) if parts else (0,)


def is_older(local: str, remote: str) -> bool:
    return parse_version(local) < parse_version(remote)


def _should_check(*, force: bool) -> bool:
    if force:
        return True
    cfg = load_config()
    last = float(cfg.get("update_check_at") or 0)
    return (time.time() - last) >= _CHECK_INTERVAL_SEC


def _mark_checked() -> None:
    cfg = load_config()
    cfg["update_check_at"] = time.time()
    save_config(cfg)


def fetch_release_info() -> dict[str, Any] | None:
    try:
        data = ApiClient(base=api_base(), token="").get("/api/v1/cli/info")
        return data if isinstance(data, dict) else None
    except Exception:  # noqa: BLE001
        return None


def upgrade_pip_command(wheel_url: str) -> str:
    import os
    from pathlib import Path

    if os.name == "nt":
        pip = Path.home() / ".picode-venv" / "Scripts" / "pip.exe"
        if pip.is_file():
            return f'& "{pip}" install -U {wheel_url}'
        return f'python -m pip install -U {wheel_url}'
    pip = Path.home() / ".picode-venv" / "bin" / "pip"
    if pip.is_file():
        return f'"{pip}" install -U {wheel_url}'
    return f'python3 -m pip install -U {wheel_url}'


def run_self_update(wheel_url: str) -> int:
    import os
    from pathlib import Path

    if os.name == "nt":
        pip = Path.home() / ".picode-venv" / "Scripts" / "pip.exe"
        if not pip.is_file():
            pip = Path(sys.executable).parent / "pip.exe"
    else:
        pip = Path.home() / ".picode-venv" / "bin" / "pip"
        if not pip.is_file():
            pip = Path(sys.executable).parent / "pip"
    if not pip.is_file():
        raise RuntimeError("pip not found — re-run install-picode script")
    proc = subprocess.run(
        [str(pip), "install", "-U", wheel_url],
        check=False,
    )
    return int(proc.returncode)


def update_notice(*, force: bool = False) -> dict[str, Any] | None:
    """Return release info when a newer version exists; None if up to date or check skipped."""
    if not _should_check(force=force):
        return None
    info = fetch_release_info()
    _mark_checked()
    if not info:
        return None
    latest = str(info.get("latest_version") or "")
    install = info.get("install") or {}
    wheel = str(install.get("wheel") or "")
    windows_exe = str(install.get("windows_exe") or "")
    if not latest or latest == "0.0.0":
        return None
    if not wheel and not windows_exe:
        return None
    if not is_older(__version__, latest):
        return None
    import os

    frozen = bool(getattr(sys, "frozen", False))
    if frozen and windows_exe:
        cmd = str(
            install.get("upgrade_windows_exe")
            or f"Download {windows_exe}"
        )
    elif os.name == "nt":
        cmd = str(install.get("upgrade_windows") or upgrade_pip_command(wheel or ""))
    else:
        cmd = str(install.get("upgrade_unix") or upgrade_pip_command(wheel or ""))
    return {
        "local_version": __version__,
        "latest_version": latest,
        "wheel_url": wheel,
        "windows_exe_url": windows_exe,
        "upgrade_command": cmd,
        "hub": str(install.get("hub") or "https://pigpt.ir/app/cli"),
        "frozen": frozen,
    }


def maybe_notify_update(console, *, force: bool = False) -> None:
    from picode.ui import brand_panel

    notice = update_notice(force=force)
    if not notice:
        return
    console.print(
        brand_panel(
            format_update_panel(notice),
            title=f"{BRAND_NAME} update",
        )
    )


def format_update_panel(notice: dict[str, Any]) -> str:
    lines = [
        f"Installed: {notice['local_version']}",
        f"Latest: {notice['latest_version']}",
    ]
    lines.append("")
    if notice.get("frozen") and notice.get("windows_exe_url"):
        lines.append("Windows app download:")
        lines.append(str(notice["windows_exe_url"]))
    else:
        lines.append("Upgrade:")
        lines.append(notice["upgrade_command"])
        lines.append("")
        lines.append(f"Or: {PRODUCT} update")
    lines.append("")
    lines.append(f"Hub: {notice.get('hub')}")
    return "\n".join(lines)
