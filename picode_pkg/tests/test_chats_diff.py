"""Multi-chat persistence + unified diffs + usage totals."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock


class ChatStoreTests(unittest.TestCase):
    def test_create_list_switch_persist(self) -> None:
        from picode.chat_store import (
            create_chat,
            ensure_active_chat,
            list_chats,
            load_chat,
            save_chat,
        )
        from picode.config_helpers import set_project_dir
        from picode.session import ReplSession

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            set_project_dir(str(root))
            a = create_chat(title="Alpha", root=root)
            a.add_turn("hello", "world")
            a.record_usage({"prompt_tokens": 3, "completion_tokens": 5})
            save_chat(a, root=root)
            b = create_chat(title="Beta", root=root)
            self.assertEqual(len(list_chats(root)), 2)
            loaded = load_chat(a.chat_id, root=root)
            assert loaded is not None
            self.assertEqual(loaded.history[0]["content"], "hello")
            self.assertEqual(loaded.usage_totals["prompt_tokens"], 3)
            self.assertEqual(loaded.usage_totals["completion_tokens"], 5)
            self.assertEqual(loaded.usage_totals["turns"], 1)
            active = ensure_active_chat(root)
            self.assertIsInstance(active, ReplSession)
            self.assertTrue((root / ".picode" / "chats").is_dir())

    def test_unified_diff_and_preview_hook(self) -> None:
        from picode.diff_view import make_unified_diff, preview_write_allowed, write_preview_hook

        diff = make_unified_diff("a.txt", "one\n", "two\n")
        self.assertIn("-one", diff)
        self.assertIn("+two", diff)

        calls: list[tuple] = []

        def hook(path, old, new, unified):
            calls.append((path, old, new, unified))
            return False

        import picode.diff_view as dv

        prev = dv.write_preview_hook
        dv.write_preview_hook = hook
        try:
            ok, _ = preview_write_allowed("a.txt", "one\n", "two\n", mode="auto")
            self.assertFalse(ok)
            self.assertEqual(calls[0][0], "a.txt")
        finally:
            dv.write_preview_hook = prev

    def test_mentions_multi_attach(self) -> None:
        from picode.mentions import expand_mentions, iter_mention_tokens

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.py").write_text("aaa", encoding="utf-8")
            (root / "b.py").write_text("bbb", encoding="utf-8")
            tokens = iter_mention_tokens("@a.py @b.py please")
            self.assertEqual(tokens, ["a.py", "b.py"])
            out = expand_mentions("@a.py @b.py please", root)
            self.assertIn("path: a.py", out)
            self.assertIn("path: b.py", out)
            self.assertIn("aaa", out)
            self.assertIn("bbb", out)

    def test_version(self) -> None:
        from picode import __version__

        self.assertEqual(__version__, "0.2.15")


if __name__ == "__main__":
    unittest.main()
