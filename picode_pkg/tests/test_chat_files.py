"""Normal chat creates and edits project files; a refusal paragraph is not success."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from picode import __version__
from picode.config_helpers import chat_file_writes_allowed, get_permissions
from picode.file_tools import (
    ChatTurnResult,
    build_chat_system,
    looks_like_file_refusal,
    no_file_notice,
    run_tool_loop,
    turn_succeeded,
    user_wants_file_write,
    writes_off_notice,
)
from picode.files import write_project_file
from picode.language import contains_persian
from picode.mentions import expand_mentions
from picode.session import ReplSession
from picode.ui import LineState, active_menu, apply_key

WRITE_BLOCK = (
    "```picode-tool\n"
    "write_file\n"
    "path: index.html\n"
    "-----\n"
    "<h1>Hi</h1>\n"
    "```"
)
PERSIAN_SAVE = "میخوام در مسیر جاری به اسم index.html ذخیره بشه"


def _confirming_model(tool_reply: str, confirm: str = "Saved index.html."):
    def chat(message, *, system, model_id, history):
        if "saved" in message:
            return {"reply": confirm, "model_id": "m1", "model_name": "Test"}
        return {"reply": tool_reply, "model_id": "m1", "model_name": "Test"}

    return chat


class ChatFileWriteTests(unittest.TestCase):
    def test_version(self) -> None:
        self.assertEqual(__version__, "0.2.15")

    def test_system_prompt_requires_local_writes(self) -> None:
        system = build_chat_system()
        self.assertIn("write_file", system)
        self.assertIn("MUST", system)
        self.assertIn("project folder", system)
        self.assertFalse(contains_persian(system))

    def test_persian_save_request_writes_index_html(self) -> None:
        self.assertTrue(user_wants_file_write(PERSIAN_SAVE))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch(
                "picode.file_tools.write_project_file",
                wraps=write_project_file,
            ) as wrote:
                result = run_tool_loop(
                    PERSIAN_SAVE,
                    chat_fn=_confirming_model(WRITE_BLOCK, "فایل index.html ذخیره شد."),
                    permissions="ask",
                    root=root,
                )
            target = root / "index.html"
            self.assertTrue(wrote.called)
            self.assertTrue(target.is_file())
            self.assertEqual(target.read_text(encoding="utf-8"), "<h1>Hi</h1>")
            self.assertIn("index.html", result.wrote)
            self.assertTrue(result.success)
            self.assertFalse(looks_like_file_refusal(result.user_facing()))
            self.assertNotIn("cannot", result.user_facing().lower())

    def test_json_tool_creates_a_new_file(self) -> None:
        block = (
            '```picode-tool\n'
            '{"tool":"write_file","path":"notes.txt","content":"hello"}\n'
            "```"
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = run_tool_loop(
                "Please save notes.txt in the current directory",
                chat_fn=_confirming_model(block, "Saved notes.txt."),
                permissions="auto",
                root=root,
            )
            self.assertEqual((root / "notes.txt").read_text(encoding="utf-8"), "hello")
            self.assertTrue(result.success)

    def test_edit_existing_file(self) -> None:
        block = (
            "```picode-tool\n"
            "write_file\n"
            "path: app.py\n"
            "-----\n"
            "x = 2\n"
            "```"
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "app.py").write_text("x = 1\n", encoding="utf-8")
            result = run_tool_loop(
                "edit app.py and set x to 2",
                chat_fn=_confirming_model(block, "Updated app.py."),
                permissions="auto",
                root=root,
            )
            self.assertEqual((root / "app.py").read_text(encoding="utf-8"), "x = 2")
            self.assertTrue(result.success)

    def test_read_then_write(self) -> None:
        read_block = "```picode-tool\nread_file\npath: index.html\n```"
        write_block = (
            "```picode-tool\n"
            "write_file\n"
            "path: index.html\n"
            "-----\n"
            "<h1>New</h1>\n"
            "```"
        )

        def chat(message, *, system, model_id, history):
            if "write_file" in message and "saved" in message:
                return {"reply": "Updated index.html."}
            if "read_file" in message and "Tool results" in message:
                return {"reply": write_block}
            return {"reply": read_block}

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "index.html").write_text("<h1>Old</h1>\n", encoding="utf-8")
            result = run_tool_loop(
                "edit index.html and change the title",
                chat_fn=chat,
                permissions="auto",
                root=root,
            )
            self.assertEqual((root / "index.html").read_text(encoding="utf-8"), "<h1>New</h1>")
            self.assertTrue(result.success)

    def test_refusal_only_is_not_success(self) -> None:
        def chat(message, *, system, model_id, history):
            return {
                "reply": "I cannot write files on your system. Here are instructions only."
            }

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = run_tool_loop(
                PERSIAN_SAVE,
                chat_fn=chat,
                permissions="auto",
                root=root,
            )
            self.assertFalse((root / "index.html").exists())
            self.assertFalse(result.success)
            self.assertFalse(turn_succeeded(result))
            self.assertEqual(result.notice, no_file_notice())
            self.assertNotIn("cannot", result.user_facing().lower())
            self.assertFalse(looks_like_file_refusal(result.user_facing()))

    def test_refusal_paragraph_is_never_success_even_if_a_path_is_listed(self) -> None:
        forged = ChatTurnResult(
            visible="I cannot save a file on your system.",
            wrote=["index.html"],
            file_intent=True,
            success=True,
        )
        self.assertFalse(turn_succeeded(forged))

    def test_model_refusal_after_write_is_replaced(self) -> None:
        def chat(message, *, system, model_id, history):
            if "saved" in message:
                return {"reply": "I cannot write files on your system."}
            return {"reply": WRITE_BLOCK}

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = run_tool_loop(
                PERSIAN_SAVE,
                chat_fn=chat,
                permissions="ask",
                root=root,
            )
            self.assertEqual((root / "index.html").read_text(encoding="utf-8"), "<h1>Hi</h1>")
            self.assertTrue(result.success)
            self.assertNotIn("cannot", result.user_facing().lower())
            self.assertIn("index.html", result.visible)

    def test_user_supplied_file_is_written_when_model_refuses(self) -> None:
        prompt = (
            PERSIAN_SAVE
            + "\n\n```html\n<h1>سلام</h1>\n```"
        )

        def chat(message, *, system, model_id, history):
            return {"reply": "I cannot save a file on your system. Copy it yourself."}

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = run_tool_loop(
                prompt,
                chat_fn=chat,
                permissions="ask",
                root=root,
            )
            self.assertEqual((root / "index.html").read_text(encoding="utf-8"), "<h1>سلام</h1>")
            self.assertTrue(result.success)
            self.assertFalse(looks_like_file_refusal(result.user_facing()))

    def test_deny_blocks_without_a_model_essay(self) -> None:
        def chat(message, *, system, model_id, history):
            raise AssertionError("model must not run when file writes are off")

        with tempfile.TemporaryDirectory() as tmp:
            result = run_tool_loop(
                PERSIAN_SAVE,
                chat_fn=chat,
                permissions="deny",
                root=Path(tmp),
            )
            self.assertFalse(result.success)
            self.assertEqual(result.notice, writes_off_notice())
            self.assertFalse((Path(tmp) / "index.html").exists())
            self.assertNotIn("cannot", result.user_facing().lower())

    def test_path_must_stay_inside_the_project(self) -> None:
        block = (
            "```picode-tool\n"
            "write_file\n"
            "path: ../picode-sandbox-secret-not-written.txt\n"
            "-----\n"
            "nope\n"
            "```"
        )

        def chat(message, *, system, model_id, history):
            if "error:" in message or "project folder" in message:
                return {"reply": "I cannot write that path."}
            return {"reply": block}

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            outside = root.parent / "picode-sandbox-secret-not-written.txt"
            result = run_tool_loop(
                "save ../picode-sandbox-secret-not-written.txt",
                chat_fn=chat,
                permissions="auto",
                root=root,
            )
            self.assertFalse(outside.exists())
            self.assertFalse(result.success)
            self.assertFalse(result.wrote)

    def test_legacy_ask_config_still_grants_chat_writes(self) -> None:
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as proj:
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = home
            try:
                Path(home, "config.json").write_text(
                    json.dumps({"permissions": "ask"}),
                    encoding="utf-8",
                )
                self.assertEqual(get_permissions(), "ask")
                self.assertTrue(chat_file_writes_allowed())
                root = Path(proj)
                result = run_tool_loop(
                    PERSIAN_SAVE,
                    chat_fn=_confirming_model(WRITE_BLOCK, "فایل ذخیره شد: index.html"),
                    root=root,
                )
                self.assertTrue((root / "index.html").is_file())
                self.assertTrue(result.success)
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def test_missing_permissions_default_to_auto(self) -> None:
        with tempfile.TemporaryDirectory() as home:
            previous = os.environ.get("PICODE_HOME")
            os.environ["PICODE_HOME"] = home
            try:
                Path(home, "config.json").write_text("{}", encoding="utf-8")
                self.assertEqual(get_permissions(), "auto")
                self.assertTrue(chat_file_writes_allowed())
                self.assertFalse(chat_file_writes_allowed("deny"))
            finally:
                if previous is None:
                    os.environ.pop("PICODE_HOME", None)
                else:
                    os.environ["PICODE_HOME"] = previous

    def _type(self, text: str, root: Path, state: LineState | None = None) -> LineState:
        current = state or LineState()
        for ch in text:
            current, submitted, kind = apply_key(current, ch, root=root)
            self.assertEqual(kind, "continue")
            self.assertIsNone(submitted)
        return current

    def test_at_menu_attaches_file_and_chat_still_writes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.txt").write_text("alpha\n", encoding="utf-8")
            (root / "note.txt").write_text("hello from disk\n", encoding="utf-8")
            (root / "z.txt").write_text("zeta\n", encoding="utf-8")
            (root / ".git").mkdir()
            (root / "node_modules").mkdir()
            (root / "__pycache__").mkdir()
            (root / "blob.bin").write_bytes(b"\x00\x01\x02")

            slash = self._type("/", root)
            slash_kind, slash_rows = active_menu(slash, root)
            self.assertEqual(slash_kind, "slash")
            self.assertEqual(slash_rows[0][0], "/help")

            opened = self._type("@", root)
            kind, rows = active_menu(opened, root)
            self.assertEqual(kind, "file")
            names = [name for name, _desc in rows]
            self.assertIn("@a.txt", names)
            self.assertIn("@note.txt", names)
            self.assertIn("@z.txt", names)
            self.assertNotIn("@.git", names)
            self.assertFalse(any("node_modules" in name for name in names))
            self.assertFalse(any("__pycache__" in name for name in names))

            filtered = self._type("note", root, opened)
            kind, rows = active_menu(filtered, root)
            self.assertEqual(kind, "file")
            self.assertEqual([name for name, _desc in rows], ["@note.txt"])
            picked, submitted, kind = apply_key(filtered, "enter", root=root)
            self.assertEqual(kind, "continue")
            self.assertIsNone(submitted)
            self.assertIn("@note.txt", picked.text())

            moved = self._type("@", root)
            _kind, open_rows = active_menu(moved, root)
            self.assertGreaterEqual(len(open_rows), 2)
            moved, _submitted, kind = apply_key(moved, "down", root=root)
            self.assertEqual(kind, "continue")
            moved, submitted, kind = apply_key(moved, "enter", root=root)
            self.assertEqual(kind, "continue")
            self.assertIsNone(submitted)
            self.assertIn(open_rows[1][0], moved.text())

            prompt = picked.text() + PERSIAN_SAVE
            outgoing = expand_mentions(prompt, root)
            self.assertIn("path: note.txt", outgoing)
            self.assertIn("hello from disk", outgoing)
            both = expand_mentions("@a.txt @z.txt", root)
            self.assertIn("alpha", both)
            self.assertIn("zeta", both)
            binary = expand_mentions("@blob.bin", root)
            self.assertIn("Binary file; contents not included.", binary)
            self.assertNotIn("\x00", binary)

            seen: list[str] = []

            def chat(message, *, system, model_id, history):
                seen.append(message)
                if "saved" in message:
                    return {"reply": "فایل index.html ذخیره شد."}
                return {"reply": WRITE_BLOCK}

            result = run_tool_loop(
                prompt,
                chat_fn=chat,
                permissions="auto",
                root=root,
            )
            self.assertTrue(seen)
            self.assertIn("hello from disk", seen[0])
            self.assertIn("path: note.txt", seen[0])
            self.assertEqual((root / "index.html").read_text(encoding="utf-8"), "<h1>Hi</h1>")
            self.assertTrue(result.success)
            self.assertFalse(looks_like_file_refusal(result.user_facing()))

    def test_do_chat_uses_the_tool_loop(self) -> None:
        from picode.slash import do_chat

        with (
            patch("picode.slash.require_ai_credit", return_value=True),
            patch("picode.slash.ApiClient"),
            patch("picode.repo_index.query_repo_index", return_value=[]),
            patch("picode.slash.run_tool_loop") as loop,
            patch("picode.slash.console"),
        ):
            loop.return_value = ChatTurnResult(visible="ok", success=True)
            do_chat(ReplSession(), "hello")
            self.assertTrue(loop.called)


if __name__ == "__main__":
    unittest.main()
