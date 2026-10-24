"""Multi-project workspaces + per-project .picode/ temp."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path


class WorkspaceTempTests(unittest.TestCase):
    def setUp(self) -> None:
        self._prev = os.environ.get("PICODE_HOME")
        self._home = tempfile.TemporaryDirectory()
        os.environ["PICODE_HOME"] = self._home.name
        # Fresh config
        Path(self._home.name, "config.json").write_text("{}", encoding="utf-8")

    def tearDown(self) -> None:
        if self._prev is None:
            os.environ.pop("PICODE_HOME", None)
        else:
            os.environ["PICODE_HOME"] = self._prev
        self._home.cleanup()

    def test_migrate_single_project_dir(self) -> None:
        from picode.config_helpers import list_workspaces, set_project_dir

        with tempfile.TemporaryDirectory() as proj:
            set_project_dir(proj)
            # Wipe workspaces key to simulate legacy config
            cfg_path = Path(self._home.name) / "config.json"
            data = json.loads(cfg_path.read_text(encoding="utf-8"))
            data.pop("workspaces", None)
            cfg_path.write_text(json.dumps(data), encoding="utf-8")
            ws = list_workspaces()
            self.assertEqual(len(ws), 1)
            self.assertEqual(Path(ws[0]["path"]).resolve(), Path(proj).resolve())
            # persisted
            data2 = json.loads(cfg_path.read_text(encoding="utf-8"))
            self.assertTrue(data2.get("workspaces"))

    def test_multi_project_switch(self) -> None:
        from picode.config_helpers import (
            add_workspace,
            list_workspaces,
            project_root,
            switch_workspace,
        )

        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            add_workspace("alpha", a)
            add_workspace("beta", b)
            self.assertEqual(len(list_workspaces()), 2)
            switch_workspace("alpha")
            self.assertEqual(project_root().resolve(), Path(a).resolve())
            switch_workspace("beta")
            self.assertEqual(project_root().resolve(), Path(b).resolve())

    def test_project_picode_temp_layout(self) -> None:
        from picode.config_helpers import (
            make_project_temp_file,
            project_picode_dir,
            project_temp_dir,
            set_project_dir,
        )

        with tempfile.TemporaryDirectory() as proj:
            root = set_project_dir(proj)
            d = project_picode_dir(root)
            self.assertTrue(d.is_dir())
            self.assertEqual(d.name, ".picode")
            self.assertTrue((d / "tmp").is_dir())
            self.assertTrue((d / "scratch").is_dir())
            self.assertTrue((d / ".gitignore").is_file())
            tmp = make_project_temp_file(prefix="t-", suffix=".txt", root=root)
            self.assertTrue(tmp.exists())
            self.assertTrue(str(tmp).startswith(str(project_temp_dir(root))))
            # Must not look like user source at project root
            self.assertNotEqual(tmp.parent, root)

    def test_index_ignores_picode_and_stores_local(self) -> None:
        from picode.config_helpers import set_project_dir
        from picode.repo_index import IGNORE_DIRS, build_repo_index, index_path

        self.assertIn(".picode", IGNORE_DIRS)
        with tempfile.TemporaryDirectory() as proj:
            root = Path(proj)
            (root / "app.py").write_text("def hello():\n    return 1\n", encoding="utf-8")
            set_project_dir(proj)
            # Create junk under .picode that must not be indexed as source
            junk = root / ".picode" / "tmp" / "secret.py"
            junk.parent.mkdir(parents=True, exist_ok=True)
            junk.write_text("SECRET = 1\n", encoding="utf-8")
            payload = build_repo_index(root)
            paths = [f["path"] for f in payload.get("files") or []]
            self.assertIn("app.py", paths)
            self.assertFalse(any(".picode" in p for p in paths))
            self.assertEqual(
                index_path(root).resolve(),
                (root / ".picode" / "index.json").resolve(),
            )
            self.assertTrue(index_path(root).is_file())


if __name__ == "__main__":
    unittest.main()
