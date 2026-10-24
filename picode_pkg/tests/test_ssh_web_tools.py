"""SSH + web tools: parse, permissions deny, system prompt."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from picode import __version__
from picode.config_helpers import (
    get_remote_permissions,
    get_web_permissions,
    set_remote_permissions,
    set_web_permissions,
)
from picode.file_tools import (
    build_chat_system,
    parse_tool_calls,
    run_tool_loop,
    user_wants_ssh,
    user_wants_web,
)
from picode.ssh_remote import SshProfile, get_ssh_profile, list_ssh_profiles, upsert_ssh_profile
from picode.web_tools import validate_public_url


class SshWebToolTests(unittest.TestCase):
    def test_version(self) -> None:
        self.assertEqual(__version__, "0.2.15")

    def test_system_mentions_ssh_and_web(self) -> None:
        system = build_chat_system()
        self.assertIn("ssh_exec", system)
        self.assertIn("web_search", system)
        self.assertIn("fetch_url", system)
        self.assertIn("Never say you have no internet", system)
        self.assertIn("Never say you cannot connect to servers", system)

    def test_intent_helpers(self) -> None:
        self.assertTrue(user_wants_ssh("ssh to my server and run uptime"))
        self.assertTrue(user_wants_ssh("به سرور وصل شو و دستور بزن"))
        self.assertTrue(user_wants_web("search the web for python 3.13"))
        self.assertTrue(user_wants_web("تو اینترنت جستجو کن"))

    def test_parse_ssh_and_web_blocks(self) -> None:
        text = (
            "```picode-tool\n"
            "ssh_exec\n"
            "connection: prod\n"
            "command: uptime\n"
            "```\n"
            "```picode-tool\n"
            '{"tool":"web_search","query":"PiGPT"}\n'
            "```\n"
            "```picode-tool\n"
            "fetch_url\n"
            "url: https://example.com\n"
            "```"
        )
        calls = parse_tool_calls(text)
        self.assertEqual(len(calls), 3)
        self.assertEqual(calls[0]["tool"], "ssh_exec")
        self.assertEqual(calls[0]["connection"], "prod")
        self.assertEqual(calls[0]["command"], "uptime")
        self.assertEqual(calls[1]["tool"], "web_search")
        self.assertEqual(calls[1]["query"], "PiGPT")
        self.assertEqual(calls[2]["tool"], "fetch_url")
        self.assertEqual(calls[2]["url"], "https://example.com")

    def test_web_url_allowlist(self) -> None:
        validate_public_url("https://example.com/a")
        with self.assertRaises(ValueError):
            validate_public_url("http://127.0.0.1/")
        with self.assertRaises(ValueError):
            validate_public_url("http://192.168.1.1/")
        with self.assertRaises(ValueError):
            validate_public_url("file:///etc/passwd")

    def test_remote_deny_blocks_with_notice(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "config.json"
            cfg.write_text("{}", encoding="utf-8")
            with patch("picode.api_client.config_path", return_value=cfg), patch(
                "picode.config_helpers.load_config",
                side_effect=lambda: json.loads(cfg.read_text(encoding="utf-8") or "{}"),
            ), patch(
                "picode.config_helpers.save_config",
                side_effect=lambda data: cfg.write_text(
                    json.dumps(data), encoding="utf-8"
                ),
            ), patch(
                "picode.ssh_remote.load_config",
                side_effect=lambda: json.loads(cfg.read_text(encoding="utf-8") or "{}"),
            ), patch(
                "picode.ssh_remote.save_config",
                side_effect=lambda data: cfg.write_text(
                    json.dumps(data), encoding="utf-8"
                ),
            ):
                set_remote_permissions("deny")
                self.assertEqual(get_remote_permissions(), "deny")

                def chat(message, *, system, model_id, history):
                    return {
                        "reply": (
                            "```picode-tool\n"
                            "ssh_exec\n"
                            "connection: x\n"
                            "command: id\n"
                            "```"
                        )
                    }

                result = run_tool_loop(
                    "ssh to server and run id",
                    chat_fn=chat,
                    confirm_fn=lambda _a: True,
                    root=Path(tmp),
                )
                self.assertIn("SSH", result.notice or result.user_facing())
                self.assertTrue(
                    "deny" in (result.notice or "").lower()
                    or "خاموش" in (result.notice or "")
                    or "off" in (result.notice or "").lower()
                    or "مسدود" in (result.notice or "")
                    or "SSH" in (result.notice or "")
                )

    def test_web_deny_blocks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "config.json"
            cfg.write_text("{}", encoding="utf-8")

            def load():
                return json.loads(cfg.read_text(encoding="utf-8") or "{}")

            def save(data):
                cfg.write_text(json.dumps(data), encoding="utf-8")

            with patch("picode.api_client.config_path", return_value=cfg), patch(
                "picode.config_helpers.load_config", side_effect=load
            ), patch("picode.config_helpers.save_config", side_effect=save):
                set_web_permissions("deny")
                self.assertEqual(get_web_permissions(), "deny")

                def chat(message, *, system, model_id, history):
                    return {
                        "reply": '```picode-tool\n{"tool":"web_search","query":"x"}\n```'
                    }

                result = run_tool_loop(
                    "search the web for x",
                    chat_fn=chat,
                    confirm_fn=lambda _a: True,
                    root=Path(tmp),
                )
                notice = (result.notice or "").lower()
                self.assertTrue(result.notice)
                self.assertTrue("web" in notice or "وب" in (result.notice or ""))

    def test_ssh_profile_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "config.json"
            cfg.write_text("{}", encoding="utf-8")

            def load():
                return json.loads(cfg.read_text(encoding="utf-8") or "{}")

            def save(data):
                cfg.write_text(json.dumps(data), encoding="utf-8")

            with patch("picode.ssh_remote.load_config", side_effect=load), patch(
                "picode.ssh_remote.save_config", side_effect=save
            ):
                upsert_ssh_profile(
                    SshProfile(
                        name="lab",
                        host="10.0.0.5",
                        port=22,
                        username="root",
                        auth="key",
                        private_key="C:/keys/id_ed25519",
                    )
                )
                self.assertEqual(len(list_ssh_profiles()), 1)
                p = get_ssh_profile("lab")
                assert p is not None
                self.assertEqual(p.host, "10.0.0.5")
                self.assertEqual(p.auth, "key")
                raw = load()
                self.assertNotIn("password", json.dumps(raw["ssh_connections"][0]))


if __name__ == "__main__":
    unittest.main()
