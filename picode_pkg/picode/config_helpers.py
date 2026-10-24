"""Persistent CLI config: model, permissions, project root, multi-project workspaces."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Any

from picode.api_client import load_config, save_config

PERMISSION_MODES = ("ask", "auto", "deny")
SHELL_PERMISSION_MODES = ("ask", "auto", "deny")
REMOTE_PERMISSION_MODES = ("ask", "auto", "deny")
WEB_PERMISSION_MODES = ("ask", "auto", "deny")
# Chat file writes are on unless the user sets deny. Missing config uses auto.
# A stored "ask" still grants chat writes (only /apply asks first).
DEFAULT_PERMISSIONS = "auto"
DEFAULT_SHELL_PERMISSIONS = "ask"
DEFAULT_REMOTE_PERMISSIONS = "ask"
DEFAULT_WEB_PERMISSIONS = "ask"

# Per-project PiCode scratch tree (never mix with user source).
PROJECT_PICODE_DIRNAME = ".picode"
PROJECT_TMP_SUBDIR = "tmp"
PROJECT_SCRATCH_SUBDIR = "scratch"


def get_permissions() -> str:
    mode = str(load_config().get("permissions") or DEFAULT_PERMISSIONS).lower()
    return mode if mode in PERMISSION_MODES else DEFAULT_PERMISSIONS


def chat_file_writes_allowed(mode: str | None = None) -> bool:
    """Deny is the only mode that blocks writing files from chat."""
    current = get_permissions() if mode is None else str(mode).lower()
    if current not in PERMISSION_MODES:
        current = DEFAULT_PERMISSIONS
    return current != "deny"


def set_permissions(mode: str) -> str:
    m = mode.lower().strip()
    if m not in PERMISSION_MODES:
        raise ValueError(f"Invalid mode; use one of: {', '.join(PERMISSION_MODES)}")
    cfg = load_config()
    cfg["permissions"] = m
    save_config(cfg)
    return m


def get_shell_permissions() -> str:
    mode = str(load_config().get("shell_permissions") or DEFAULT_SHELL_PERMISSIONS).lower()
    return mode if mode in SHELL_PERMISSION_MODES else DEFAULT_SHELL_PERMISSIONS


def set_shell_permissions(mode: str) -> str:
    m = mode.lower().strip()
    if m not in SHELL_PERMISSION_MODES:
        raise ValueError(f"Invalid shell mode; use one of: {', '.join(SHELL_PERMISSION_MODES)}")
    cfg = load_config()
    cfg["shell_permissions"] = m
    save_config(cfg)
    return m


def get_remote_permissions() -> str:
    mode = str(load_config().get("remote_permissions") or DEFAULT_REMOTE_PERMISSIONS).lower()
    return mode if mode in REMOTE_PERMISSION_MODES else DEFAULT_REMOTE_PERMISSIONS


def set_remote_permissions(mode: str) -> str:
    m = mode.lower().strip()
    if m not in REMOTE_PERMISSION_MODES:
        raise ValueError(f"Invalid remote mode; use one of: {', '.join(REMOTE_PERMISSION_MODES)}")
    cfg = load_config()
    cfg["remote_permissions"] = m
    save_config(cfg)
    return m


def get_web_permissions() -> str:
    mode = str(load_config().get("web_permissions") or DEFAULT_WEB_PERMISSIONS).lower()
    return mode if mode in WEB_PERMISSION_MODES else DEFAULT_WEB_PERMISSIONS


def set_web_permissions(mode: str) -> str:
    m = mode.lower().strip()
    if m not in WEB_PERMISSION_MODES:
        raise ValueError(f"Invalid web mode; use one of: {', '.join(WEB_PERMISSION_MODES)}")
    cfg = load_config()
    cfg["web_permissions"] = m
    save_config(cfg)
    return m


def _normalize_workspaces(raw: Any) -> list[dict]:
    if not isinstance(raw, list):
        return []
    out: list[dict] = []
    seen_names: set[str] = set()
    for item in raw:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        path = item.get("path")
        if not name or not path or name in seen_names:
            continue
        try:
            resolved = str(Path(str(path)).expanduser().resolve())
        except OSError:
            continue
        out.append({"name": name, "path": resolved})
        seen_names.add(name)
    return out


def _unique_workspace_name(base: str, existing: set[str]) -> str:
    name = (base or "default").strip() or "default"
    if name not in existing:
        return name
    i = 2
    while f"{name}-{i}" in existing:
        i += 1
    return f"{name}-{i}"


def list_workspaces() -> list[dict]:
    """Return saved projects; migrate legacy single project_dir into the list once."""
    cfg = load_config()
    workspaces = _normalize_workspaces(cfg.get("workspaces"))
    if workspaces:
        return workspaces
    primary = cfg.get("project_dir")
    if primary:
        try:
            p = Path(str(primary)).expanduser().resolve()
        except OSError:
            return []
        name = p.name or "default"
        workspaces = [{"name": name, "path": str(p)}]
        cfg["workspaces"] = workspaces
        save_config(cfg)
        return workspaces
    return []


def add_workspace(name: str, path: str) -> list[dict]:
    set_project_dir(path, name=str(name).strip())
    return list_workspaces()


def remove_workspace(name: str) -> list[dict]:
    target = str(name).strip()
    cfg = load_config()
    workspaces = [w for w in list_workspaces() if w.get("name") != target]
    cfg["workspaces"] = workspaces
    current = cfg.get("project_dir")
    if current:
        try:
            cur = Path(str(current)).expanduser().resolve()
        except OSError:
            cur = None
        still = False
        if cur is not None:
            for w in workspaces:
                try:
                    if Path(str(w["path"])).resolve() == cur:
                        still = True
                        break
                except OSError:
                    continue
        if not still:
            if workspaces:
                cfg["project_dir"] = workspaces[0]["path"]
            else:
                cfg.pop("project_dir", None)
    save_config(cfg)
    return workspaces


def switch_workspace(name: str) -> Path:
    for w in list_workspaces():
        if w.get("name") == name:
            return set_project_dir(w["path"], name=str(w.get("name") or name))
    raise ValueError(f"Workspace not found: {name!r}")


def current_workspace_name() -> str | None:
    root = str(project_root())
    for w in list_workspaces():
        if str(w.get("path")) == root:
            return str(w.get("name"))
    return None


def get_model_id() -> str | None:
    raw = load_config().get("model_id")
    return str(raw).strip() if raw else None


def set_model_id(model_id: str) -> None:
    cfg = load_config()
    cfg["model_id"] = model_id.strip()
    save_config(cfg)


def clear_model_id() -> None:
    cfg = load_config()
    cfg.pop("model_id", None)
    save_config(cfg)


def get_project_dir() -> Path | None:
    raw = load_config().get("project_dir")
    if raw:
        return Path(str(raw)).expanduser().resolve()
    env = os.environ.get("PICODE_PROJECT")
    if env:
        return Path(env).expanduser().resolve()
    return None


def set_project_dir(path: str, *, name: str | None = None) -> Path:
    """Set active project root, upsert into workspaces list, ensure `.picode/` layout."""
    p = Path(path).expanduser().resolve()
    if not p.is_dir():
        raise ValueError(f"Directory does not exist: {p}")
    cfg = load_config()
    cfg["project_dir"] = str(p)
    workspaces = _normalize_workspaces(cfg.get("workspaces"))
    matched = False
    for w in workspaces:
        try:
            if Path(str(w["path"])).resolve() == p:
                if name:
                    w["name"] = str(name).strip() or w["name"]
                matched = True
                break
        except OSError:
            continue
    if not matched:
        existing = {str(w.get("name")) for w in workspaces}
        ws_name = _unique_workspace_name(name or p.name or "default", existing)
        workspaces.append({"name": ws_name, "path": str(p)})
    cfg["workspaces"] = workspaces
    save_config(cfg)
    project_picode_dir(p)
    return p


def project_root() -> Path:
    return get_project_dir() or Path.cwd().resolve()


def project_picode_dir(root: Path | None = None) -> Path:
    """Dedicated PiCode folder inside the project (scratch/temp/index). Not user source."""
    base = (root or project_root()).resolve()
    d = base / PROJECT_PICODE_DIRNAME
    d.mkdir(parents=True, exist_ok=True)
    (d / PROJECT_TMP_SUBDIR).mkdir(exist_ok=True)
    (d / PROJECT_SCRATCH_SUBDIR).mkdir(exist_ok=True)
    gitignore = d / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text(
            "# PiCode scratch — do not mix with source\n*\n!.gitignore\n",
            encoding="utf-8",
        )
    readme = d / "README.txt"
    if not readme.exists():
        readme.write_text(
            "PiCode project data (temp, scratch, local index).\n"
            "Safe to delete contents; PiCode recreates as needed.\n"
            "Do not put your application source here.\n",
            encoding="utf-8",
        )
    return d


def project_temp_dir(root: Path | None = None) -> Path:
    d = project_picode_dir(root) / PROJECT_TMP_SUBDIR
    d.mkdir(parents=True, exist_ok=True)
    return d


def project_scratch_dir(root: Path | None = None) -> Path:
    d = project_picode_dir(root) / PROJECT_SCRATCH_SUBDIR
    d.mkdir(parents=True, exist_ok=True)
    return d


def make_project_temp_file(
    *,
    prefix: str = "picode-",
    suffix: str = "",
    root: Path | None = None,
) -> Path:
    """Create an empty temp file under `<project>/.picode/tmp/`."""
    fd, name = tempfile.mkstemp(prefix=prefix, suffix=suffix, dir=str(project_temp_dir(root)))
    os.close(fd)
    return Path(name)


def get_ui_language() -> str:
    from picode.i18n import get_ui_lang

    return get_ui_lang()


def set_ui_language(lang: str) -> str:
    from picode.i18n import set_ui_lang

    return set_ui_lang(lang)


def config_summary() -> dict[str, Any]:
    cfg = load_config()
    token = cfg.get("token")
    masked = None
    if token and isinstance(token, str):
        masked = f"{token[:8]}…{token[-4:]}" if len(token) > 16 else "••••"
    try:
        from picode.ssh_remote import get_ssh_default, list_ssh_profiles

        ssh_n = len(list_ssh_profiles())
        ssh_default = get_ssh_default()
    except Exception:  # noqa: BLE001
        ssh_n = 0
        ssh_default = None
    root = project_root()
    return {
        "api_url": cfg.get("api_url"),
        "model_id": get_model_id(),
        "permissions": get_permissions(),
        "shell_permissions": get_shell_permissions(),
        "remote_permissions": get_remote_permissions(),
        "web_permissions": get_web_permissions(),
        "ssh_connections": ssh_n,
        "ssh_default": ssh_default,
        "ui_language": get_ui_language(),
        "workspaces": len(list_workspaces()),
        "project_dir": str(root),
        "project_picode_dir": str(project_picode_dir(root)),
        "token": masked,
    }
