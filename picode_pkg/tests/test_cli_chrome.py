"""PiCode UI language (default fa) and `/` opens a command list before Enter."""

from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from rich.console import Console

from picode.api_client import english_api_detail, plan_display_name
from picode.git_suggest import COMMIT_SYSTEM, PR_SYSTEM
from picode.i18n import DEFAULT_UI_LANG, get_ui_lang, set_ui_lang, slash_help_text, t
from picode.language import LANGUAGE_RULE, contains_persian, system_instruction
from picode.repl_input import SLASH_COMMANDS
from picode.ui import LineState, apply_key, matching_commands, read_repl_line


class CliChromeTests(unittest.TestCase):
    def test_language_rule_follows_the_user_message(self) -> None:
        system = system_instruction("Use the repo index when it is relevant.")
        self.assertIn(LANGUAGE_RULE, system)
        self.assertIn("language of the user's message", system)
        self.assertFalse(contains_persian(system))
        self.assertFalse(contains_persian(COMMIT_SYSTEM))
        self.assertFalse(contains_persian(PR_SYSTEM))
        self.assertIn(LANGUAGE_RULE, COMMIT_SYSTEM)
        self.assertNotIn("Persian body", COMMIT_SYSTEM)
        self.assertNotIn("Persian bullets", PR_SYSTEM)

    def test_default_ui_language_is_persian(self) -> None:
        self.assertEqual(DEFAULT_UI_LANG, "fa")
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = str(home)
            try:
                Path(home, "config.json").write_text("{}", encoding="utf-8")
                self.assertEqual(get_ui_lang(), "fa")
                self.assertTrue(contains_persian(t("status.thinking", brand="PiCode")))
                self.assertTrue(contains_persian(slash_help_text()))
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def test_ui_language_switches_chrome(self) -> None:
        from picode.i18n import UI_LANGS, is_rtl, language_choices

        self.assertEqual(UI_LANGS, ("fa", "en", "tr", "ar"))
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = str(home)
            try:
                Path(home, "config.json").write_text("{}", encoding="utf-8")
                set_ui_lang("en")
                self.assertEqual(get_ui_lang(), "en")
                self.assertFalse(is_rtl())
                self.assertFalse(contains_persian(t("status.thinking", brand="PiCode")))
                self.assertIn("thinking", t("status.thinking", brand="PiCode"))
                self.assertFalse(contains_persian(slash_help_text()))
                cfg = json.loads(Path(home, "config.json").read_text(encoding="utf-8"))
                self.assertEqual(cfg.get("ui_language"), "en")
                set_ui_lang("tr")
                self.assertEqual(get_ui_lang(), "tr")
                self.assertFalse(is_rtl())
                self.assertIn("düşünüyor", t("status.thinking", brand="PiCode"))
                set_ui_lang("ar")
                self.assertEqual(get_ui_lang(), "ar")
                self.assertTrue(is_rtl())
                self.assertIn("يفكر", t("status.thinking", brand="PiCode"))
                codes = [c for c, _ in language_choices()]
                self.assertEqual(codes, ["fa", "en", "tr", "ar"])
                set_ui_lang("fa")
                self.assertEqual(get_ui_lang(), "fa")
                self.assertTrue(is_rtl())
                self.assertTrue(contains_persian(t("warn.cancelled")))
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def test_command_names_stay_latin(self) -> None:
        for name, desc in SLASH_COMMANDS:
            self.assertTrue(name.startswith("/"))
            self.assertFalse(contains_persian(name))
            self.assertFalse(contains_persian(desc))
        self.assertTrue(any(name == "/language" for name, _ in SLASH_COMMANDS))

    def test_api_errors_and_plan_names_stay_english_when_ui_en(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = str(home)
            try:
                Path(home, "config.json").write_text(
                    json.dumps({"ui_language": "en"}), encoding="utf-8"
                )
                exact = english_api_detail("کد نامعتبر یا منقضی است")
                self.assertEqual(exact, "Invalid or expired code.")
                self.assertFalse(contains_persian(exact))
                unknown = english_api_detail("خطای ناشناخته از سرور")
                self.assertEqual(unknown, "Request failed.")
                self.assertFalse(contains_persian(unknown))
                self.assertEqual(
                    plan_display_name({"name": "حرفه‌ای", "name_en": "", "code": "pro"}),
                    "pro",
                )
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def test_slash_shows_list_before_enter(self) -> None:
        state = LineState()
        state, _line, kind = apply_key(state, "/")
        self.assertEqual(kind, "continue")
        rows = matching_commands(state)
        self.assertTrue(rows)
        self.assertEqual(rows[0][0], "/help")
        self.assertTrue(any(name == "/status" for name, _desc in rows))

    def test_typing_filters_and_enter_runs_highlight(self) -> None:
        state = LineState()
        for ch in "/sta":
            state, _line, kind = apply_key(state, ch)
            self.assertEqual(kind, "continue")
        rows = matching_commands(state)
        self.assertEqual([name for name, _desc in rows], ["/status"])
        _state, line, kind = apply_key(state, "enter")
        self.assertEqual(kind, "submit")
        self.assertEqual(line, "/status")

    def test_arrows_move_selection(self) -> None:
        state = LineState()
        state, _line, _kind = apply_key(state, "/")
        state, _line, _kind = apply_key(state, "down")
        _state, line, kind = apply_key(state, "enter")
        self.assertEqual(kind, "submit")
        self.assertEqual(line, "/status")

    def test_enter_on_chat_sends_the_message(self) -> None:
        state = LineState()
        for ch in "hello":
            state, _line, kind = apply_key(state, ch)
            self.assertEqual(kind, "continue")
        self.assertEqual(matching_commands(state), [])
        _state, line, kind = apply_key(state, "enter")
        self.assertEqual(kind, "submit")
        self.assertEqual(line, "hello")

    def test_command_that_needs_args_stays_on_the_line(self) -> None:
        state = LineState()
        for ch in "/read":
            state, _line, kind = apply_key(state, ch)
            self.assertEqual(kind, "continue")
        state, line, kind = apply_key(state, "enter")
        self.assertEqual(kind, "continue")
        self.assertIsNone(line)
        self.assertEqual(state.text(), "/read ")
        self.assertEqual(matching_commands(state), [])

    def test_read_repl_line_draws_menu_without_enter(self) -> None:
        keys = iter(["/", "enter"])

        def fake_key() -> str:
            return next(keys)

        import picode.ui as ui

        original = ui._read_key
        ui._read_key = fake_key  # type: ignore[method-assign]
        buf = io.StringIO()
        console = Console(file=buf, force_terminal=True, width=80, color_system=None)
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = str(home)
            try:
                Path(home, "config.json").write_text(
                    json.dumps({"ui_language": "en"}), encoding="utf-8"
                )
                try:
                    line = read_repl_line(console)
                finally:
                    ui._read_key = original
                text = buf.getvalue()
                self.assertEqual(line, "/help")
                self.assertIn("Enter run", text)
                self.assertIn("/help", text)
                self.assertFalse(contains_persian(text))
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def test_activity_hook_receives_events(self) -> None:
        from picode.activity import busy, report
        import picode.activity as activity

        events: list[tuple[str, str]] = []

        def hook(kind: str, message: str) -> None:
            events.append((kind, message))

        prev = activity.activity_hook
        activity.activity_hook = hook
        try:
            report("thinking", "hello")
            buf = io.StringIO()
            console = Console(file=buf, force_terminal=False, color_system=None)
            with busy(console, "working", kind="thinking"):
                pass
            self.assertTrue(any(k == "thinking" for k, _ in events))
            self.assertTrue(any(k == "done" for k, _ in events))
        finally:
            activity.activity_hook = prev


if __name__ == "__main__":
    unittest.main()
