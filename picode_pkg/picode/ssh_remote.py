"""SSH connection profiles and remote command execution for PiCode tools."""

from __future__ import annotations

import io
import socket
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from picode.activity import report as report_activity
from picode.api_client import load_config, save_config
from picode.i18n import t

AUTH_PASSWORD = "password"
AUTH_KEY = "key"
AUTH_MODES = (AUTH_PASSWORD, AUTH_KEY)


@dataclass
class SshProfile:
    name: str
    host: str
    port: int = 22
    username: str = ""
    auth: str = AUTH_KEY
    password: str = ""
    private_key: str = ""
    passphrase: str = ""

    def to_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {
            "name": self.name,
            "host": self.host,
            "port": int(self.port or 22),
            "username": self.username,
            "auth": self.auth if self.auth in AUTH_MODES else AUTH_KEY,
        }
        if data["auth"] == AUTH_PASSWORD:
            data["password"] = self.password
        else:
            data["private_key"] = self.private_key
            if self.passphrase:
                data["passphrase"] = self.passphrase
        return data

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> SshProfile:
        name = str(raw.get("name") or "").strip()
        host = str(raw.get("host") or "").strip()
        if not name or not host:
            raise ValueError("SSH profile needs name and host")
        auth = str(raw.get("auth") or AUTH_KEY).strip().lower()
        if auth not in AUTH_MODES:
            auth = AUTH_KEY
        try:
            port = int(raw.get("port") or 22)
        except (TypeError, ValueError):
            port = 22
        return cls(
            name=name,
            host=host,
            port=port if 1 <= port <= 65535 else 22,
            username=str(raw.get("username") or "").strip(),
            auth=auth,
            password=str(raw.get("password") or ""),
            private_key=str(raw.get("private_key") or "").strip(),
            passphrase=str(raw.get("passphrase") or ""),
        )


def list_ssh_profiles() -> list[SshProfile]:
    raw = load_config().get("ssh_connections")
    if not isinstance(raw, list):
        return []
    out: list[SshProfile] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            out.append(SshProfile.from_dict(item))
        except ValueError:
            continue
    return out


def get_ssh_default() -> str | None:
    name = str(load_config().get("ssh_default") or "").strip()
    return name or None


def set_ssh_default(name: str | None) -> str | None:
    cfg = load_config()
    if not name:
        cfg.pop("ssh_default", None)
        save_config(cfg)
        return None
    if not get_ssh_profile(name):
        raise ValueError(f"SSH connection not found: {name!r}")
    cfg["ssh_default"] = name
    save_config(cfg)
    return name


def get_ssh_profile(name: str | None = None) -> SshProfile | None:
    wanted = (name or get_ssh_default() or "").strip()
    profiles = list_ssh_profiles()
    if wanted:
        for p in profiles:
            if p.name == wanted:
                return p
        return None
    if len(profiles) == 1:
        return profiles[0]
    return None


def upsert_ssh_profile(profile: SshProfile) -> list[SshProfile]:
    cfg = load_config()
    profiles = [p for p in list_ssh_profiles() if p.name != profile.name]
    profiles.append(profile)
    cfg["ssh_connections"] = [p.to_dict() for p in profiles]
    if not get_ssh_default():
        cfg["ssh_default"] = profile.name
    save_config(cfg)
    return profiles


def delete_ssh_profile(name: str) -> list[SshProfile]:
    cfg = load_config()
    profiles = [p for p in list_ssh_profiles() if p.name != name]
    cfg["ssh_connections"] = [p.to_dict() for p in profiles]
    if cfg.get("ssh_default") == name:
        cfg["ssh_default"] = profiles[0].name if profiles else None
        if not cfg["ssh_default"]:
            cfg.pop("ssh_default", None)
    save_config(cfg)
    return profiles


def _load_pkey(path: str, passphrase: str):
    import paramiko

    key_path = Path(path).expanduser()
    if not key_path.is_file():
        raise FileNotFoundError(f"Private key not found: {key_path}")
    data = key_path.read_bytes()
    pwd = passphrase.encode("utf-8") if passphrase else None
    last_exc: Exception | None = None
    for loader in (
        paramiko.Ed25519Key,
        paramiko.ECDSAKey,
        paramiko.RSAKey,
        paramiko.DSSKey,
    ):
        try:
            return loader.from_private_key(io.BytesIO(data), password=pwd)
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
            continue
    raise ValueError(f"Could not load private key: {last_exc}")


def run_ssh_command(
    command: str,
    *,
    connection: str | None = None,
    timeout: float = 60.0,
) -> dict[str, Any]:
    """Run ``command`` on a saved SSH profile. Returns status/stdout/stderr."""
    import paramiko

    cmd = (command or "").strip()
    if not cmd:
        raise ValueError("Missing remote command")
    if len(cmd) > 20_000:
        raise ValueError("Remote command too long")

    profile = get_ssh_profile(connection)
    if profile is None:
        names = ", ".join(p.name for p in list_ssh_profiles()) or "(none)"
        raise ValueError(
            f"No SSH connection selected. Add one with /ssh or Settings → Connections. "
            f"Known: {names}"
        )
    if not profile.username:
        raise ValueError(f"SSH profile {profile.name!r} has no username")
    if profile.auth == AUTH_PASSWORD and not profile.password:
        raise ValueError(f"SSH profile {profile.name!r} has no password")
    if profile.auth == AUTH_KEY and not profile.private_key:
        raise ValueError(f"SSH profile {profile.name!r} has no private key path")

    label = f"{profile.username}@{profile.host}:{profile.port}"
    report_activity("running", t("status.ssh", host=label, cmd=cmd[:80]))

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    connect_kwargs: dict[str, Any] = {
        "hostname": profile.host,
        "port": profile.port,
        "username": profile.username,
        "timeout": min(timeout, 30.0),
        "allow_agent": False,
        "look_for_keys": False,
    }
    if profile.auth == AUTH_PASSWORD:
        connect_kwargs["password"] = profile.password
    else:
        connect_kwargs["pkey"] = _load_pkey(profile.private_key, profile.passphrase)

    try:
        client.connect(**connect_kwargs)
        _stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        exit_status = stdout.channel.recv_exit_status()
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
    except (paramiko.SSHException, socket.error, OSError, ValueError, FileNotFoundError) as exc:
        raise RuntimeError(str(exc)) from exc
    finally:
        try:
            client.close()
        except Exception:  # noqa: BLE001
            pass

    max_len = 12_000
    if len(out) > max_len:
        out = out[:max_len] + "\n…(truncated)"
    if len(err) > max_len:
        err = err[:max_len] + "\n…(truncated)"
    return {
        "connection": profile.name,
        "host": label,
        "exit_status": int(exit_status),
        "stdout": out,
        "stderr": err,
        "command": cmd,
    }


def test_ssh_connection(name: str | None = None) -> dict[str, Any]:
    return run_ssh_command("echo picode-ssh-ok && uname -a || ver", connection=name, timeout=25.0)
