"""PiCode Windows window — professional shell; same core as the CLI."""

from __future__ import annotations

import io
import sys
import threading
import webbrowser
from pathlib import Path

from picode import BRAND_NAME, __version__
from picode.i18n import get_ui_lang, is_rtl, language_choices, localized_commands, set_ui_lang, t
from picode.repl_input import NEEDS_ARGS
from picode.session import ReplSession
from picode.ui_fonts import (
    LATIN_UI_FONT,
    MONO_FONT,
    brand_icon_path,
    ensure_vazir_loaded,
    ui_font_family,
)


def _capture_console():
    from rich.console import Console

    import picode.cli as cli_mod
    import picode.slash as slash
    import picode.ui as ui

    buf = io.StringIO()
    width = ui.PANEL_COLUMNS or 88
    con = Console(
        file=buf,
        force_terminal=False,
        color_system=None,
        width=width,
        highlight=False,
        soft_wrap=True,
    )
    cli_mod.console = con
    slash.console = con
    return buf


def _text(buf: io.StringIO) -> str:
    return buf.getvalue().replace("\r\n", "\n").replace("\r", "").strip()


def execute(
    line: str,
    session: ReplSession,
    ask,
    on_activity=None,
    on_write_preview=None,
) -> tuple[str, bool]:
    """Run one REPL line. Returns (output, should_close)."""
    import picode.activity as activity
    import picode.diff_view as diff_view
    import picode.slash as slash
    from picode.api_client import ApiClient
    from picode.billing_guard import require_ai_credit
    from picode.cli import _clear_token, _run_browser_login
    from picode.slash import do_chat, handle_slash

    buf = _capture_console()
    slash.confirm_hook = ask
    prev_hook = activity.activity_hook
    prev_preview = diff_view.write_preview_hook
    if on_activity is not None:
        activity.activity_hook = on_activity
    if on_write_preview is not None:
        diff_view.write_preview_hook = on_write_preview
    try:
        if line.startswith("/"):
            keep = handle_slash(
                line,
                session,
                on_login=lambda: _run_browser_login(),
                on_logout=_clear_token,
            )
            if not keep:
                slash.console.print(t("help.goodbye", brand=BRAND_NAME))
                return _text(buf), True
            return _text(buf), False
        if not require_ai_credit(ApiClient(), slash.console):
            return _text(buf), False
        do_chat(session, line)
        return _text(buf), False
    except Exception as exc:  # noqa: BLE001
        return (_text(buf) + f"\n{exc}").strip(), False
    finally:
        slash.confirm_hook = None
        activity.activity_hook = prev_hook
        diff_view.write_preview_hook = prev_preview


def boot(ask, on_activity=None) -> str:
    import typer

    import picode.activity as activity
    import picode.cli as cli_mod
    import picode.slash as slash
    from picode.cli import _repl_auth_at_start
    from picode.updates import maybe_notify_update

    buf = _capture_console()
    slash.confirm_hook = ask
    prev_hook = activity.activity_hook
    if on_activity is not None:
        activity.activity_hook = on_activity
    try:
        try:
            _repl_auth_at_start()
        except (typer.Exit, SystemExit):
            pass
        maybe_notify_update(cli_mod.console)
        return _text(buf)
    finally:
        slash.confirm_hook = None
        activity.activity_hook = prev_hook


def _is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def _slash_labels() -> list[str]:
    return [f"{name}  —  {desc}" for name, desc in localized_commands()]


def main() -> None:
    import multiprocessing

    multiprocessing.freeze_support()
    try:
        from PySide6.QtCore import QStringListModel, Qt, QThread, Signal
        from PySide6.QtGui import (
            QAction,
            QColor,
            QFont,
            QFontMetrics,
            QIcon,
            QTextCharFormat,
            QTextCursor,
        )
        from PySide6.QtWidgets import (
            QApplication,
            QComboBox,
            QCompleter,
            QDialog,
            QDialogButtonBox,
            QFileDialog,
            QFormLayout,
            QFrame,
            QHBoxLayout,
            QLabel,
            QLineEdit,
            QListWidget,
            QListWidgetItem,
            QMainWindow,
            QMessageBox,
            QPlainTextEdit,
            QPushButton,
            QSplitter,
            QStatusBar,
            QTabWidget,
            QTextEdit,
            QToolBar,
            QVBoxLayout,
            QWidget,
        )
    except ImportError:
        sys.stderr.write("PiCode window needs PySide6-Essentials.\n")
        raise

    class Worker(QThread):
        finished_text = Signal(str, bool)
        need_confirm = Signal(str)
        need_diff = Signal(str, str, str, str)
        activity = Signal(str, str)

        def __init__(self, session: ReplSession, line: str | None) -> None:
            super().__init__()
            self.session = session
            self.line = line
            self._event = threading.Event()
            self._answer = False

        def provide(self, yes: bool) -> None:
            self._answer = yes
            self._event.set()

        def _ask(self, text: str) -> bool:
            self._event.clear()
            self.need_confirm.emit(text)
            self._event.wait()
            return self._answer

        def _preview_write(self, path: str, old: str, new: str, unified: str) -> bool:
            self._event.clear()
            self.need_diff.emit(path, old or "", new or "", unified or "")
            self._event.wait()
            return self._answer

        def _on_activity(self, kind: str, message: str) -> None:
            self.activity.emit(kind, message)

        def run(self) -> None:
            if self.line is None:
                self.finished_text.emit(boot(self._ask, self._on_activity), False)
                return
            text, close = execute(
                self.line,
                self.session,
                self._ask,
                self._on_activity,
                self._preview_write,
            )
            self.finished_text.emit(text, close)

    class PermissionsDialog(QDialog):
        def __init__(self, parent: QWidget | None = None) -> None:
            super().__init__(parent)
            from picode.config_helpers import (
                get_permissions,
                get_remote_permissions,
                get_shell_permissions,
                get_web_permissions,
            )

            self.setWindowTitle(t("desk.perm_title", brand=BRAND_NAME))
            self.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            self.setMinimumWidth(420)
            form = QFormLayout(self)
            self.file_mode = QComboBox()
            self.file_mode.addItem(t("desk.perm_auto"), "auto")
            self.file_mode.addItem(t("desk.perm_ask"), "ask")
            self.file_mode.addItem(t("desk.perm_deny"), "deny")
            self.shell_mode = QComboBox()
            self.shell_mode.addItem(t("desk.perm_shell_ask"), "ask")
            self.shell_mode.addItem(t("desk.perm_shell_auto"), "auto")
            self.shell_mode.addItem(t("desk.perm_shell_deny"), "deny")
            self.remote_mode = QComboBox()
            self.remote_mode.addItem(t("desk.perm_shell_ask"), "ask")
            self.remote_mode.addItem(t("desk.perm_shell_auto"), "auto")
            self.remote_mode.addItem(t("desk.perm_shell_deny"), "deny")
            self.web_mode = QComboBox()
            self.web_mode.addItem(t("desk.perm_shell_ask"), "ask")
            self.web_mode.addItem(t("desk.perm_shell_auto"), "auto")
            self.web_mode.addItem(t("desk.perm_shell_deny"), "deny")
            cur_f = get_permissions()
            cur_s = get_shell_permissions()
            cur_r = get_remote_permissions()
            cur_w = get_web_permissions()
            for box, cur in (
                (self.file_mode, cur_f),
                (self.shell_mode, cur_s),
                (self.remote_mode, cur_r),
                (self.web_mode, cur_w),
            ):
                for i in range(box.count()):
                    if box.itemData(i) == cur:
                        box.setCurrentIndex(i)
                        break
            form.addRow(t("desk.perm_files"), self.file_mode)
            form.addRow(t("desk.perm_shell"), self.shell_mode)
            form.addRow(t("desk.perm_remote"), self.remote_mode)
            form.addRow(t("desk.perm_web"), self.web_mode)
            hint = QLabel(t("desk.perm_hint"))
            hint.setWordWrap(True)
            form.addRow(hint)
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText(t("confirm.save"))
            buttons.button(QDialogButtonBox.StandardButton.Cancel).setText(t("confirm.cancel"))
            buttons.accepted.connect(self.accept)
            buttons.rejected.connect(self.reject)
            form.addRow(buttons)

        def apply(self) -> None:
            from picode.config_helpers import (
                set_permissions,
                set_remote_permissions,
                set_shell_permissions,
                set_web_permissions,
            )

            set_permissions(str(self.file_mode.currentData()))
            set_shell_permissions(str(self.shell_mode.currentData()))
            set_remote_permissions(str(self.remote_mode.currentData()))
            set_web_permissions(str(self.web_mode.currentData()))

    class ConnectionsDialog(QDialog):
        """Manage saved SSH profiles (credentials stay in ~/.picode/config.json)."""

        def __init__(self, parent: QWidget | None = None) -> None:
            super().__init__(parent)
            from picode.ssh_remote import get_ssh_default, list_ssh_profiles

            self.setWindowTitle(t("desk.conn_title", brand=BRAND_NAME))
            self.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            self.setMinimumWidth(520)
            layout = QVBoxLayout(self)
            hint = QLabel(t("desk.conn_hint"))
            hint.setWordWrap(True)
            layout.addWidget(hint)
            layout.addWidget(QLabel(t("desk.conn_list")))
            self.list = QListWidget()
            layout.addWidget(self.list)
            form = QFormLayout()
            self.name = QLineEdit()
            self.host = QLineEdit()
            self.port = QLineEdit("22")
            self.user = QLineEdit()
            self.auth = QComboBox()
            self.auth.addItem(t("desk.conn_auth_key"), "key")
            self.auth.addItem(t("desk.conn_auth_password"), "password")
            self.key_path = QLineEdit()
            self.passphrase = QLineEdit()
            self.passphrase.setEchoMode(QLineEdit.EchoMode.Password)
            self.password = QLineEdit()
            self.password.setEchoMode(QLineEdit.EchoMode.Password)
            form.addRow(t("desk.conn_name"), self.name)
            form.addRow(t("desk.conn_host"), self.host)
            form.addRow(t("desk.conn_port"), self.port)
            form.addRow(t("desk.conn_user"), self.user)
            form.addRow(t("desk.conn_auth"), self.auth)
            form.addRow(t("desk.conn_key"), self.key_path)
            form.addRow(t("desk.conn_passphrase"), self.passphrase)
            form.addRow(t("desk.conn_password"), self.password)
            layout.addLayout(form)
            self.auth.currentIndexChanged.connect(self._sync_auth_fields)
            self._sync_auth_fields()
            row = QHBoxLayout()
            btn_save = QPushButton(t("desk.conn_add"))
            btn_save.clicked.connect(self._save)
            btn_del = QPushButton(t("desk.conn_delete"))
            btn_del.clicked.connect(self._delete)
            btn_test = QPushButton(t("desk.conn_test"))
            btn_test.clicked.connect(self._test)
            btn_def = QPushButton(t("desk.conn_default"))
            btn_def.clicked.connect(self._set_default)
            row.addWidget(btn_save)
            row.addWidget(btn_del)
            row.addWidget(btn_test)
            row.addWidget(btn_def)
            layout.addLayout(row)
            self.status = QLabel("")
            self.status.setWordWrap(True)
            layout.addWidget(self.status)
            close = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
            close.rejected.connect(self.reject)
            close.accepted.connect(self.accept)
            layout.addWidget(close)
            self.list.currentItemChanged.connect(self._load_selected)
            self._reload(get_ssh_default())

        def _sync_auth_fields(self) -> None:
            is_key = self.auth.currentData() == "key"
            self.key_path.setEnabled(is_key)
            self.passphrase.setEnabled(is_key)
            self.password.setEnabled(not is_key)

        def _reload(self, select: str | None = None) -> None:
            from picode.ssh_remote import get_ssh_default, list_ssh_profiles

            self.list.clear()
            default = get_ssh_default()
            for p in list_ssh_profiles():
                label = f"{p.name}  —  {p.username}@{p.host}:{p.port} ({p.auth})"
                if p.name == default:
                    label += " ★"
                item = QListWidgetItem(label)
                item.setData(Qt.ItemDataRole.UserRole, p.name)
                self.list.addItem(item)
                if select and p.name == select:
                    self.list.setCurrentItem(item)

        def _load_selected(self, current: QListWidgetItem | None, _prev=None) -> None:
            from picode.ssh_remote import get_ssh_profile

            if current is None:
                return
            name = current.data(Qt.ItemDataRole.UserRole)
            p = get_ssh_profile(str(name))
            if not p:
                return
            self.name.setText(p.name)
            self.host.setText(p.host)
            self.port.setText(str(p.port))
            self.user.setText(p.username)
            idx = 0 if p.auth == "key" else 1
            self.auth.setCurrentIndex(idx)
            self.key_path.setText(p.private_key)
            self.passphrase.setText(p.passphrase)
            self.password.setText(p.password)
            self._sync_auth_fields()

        def _save(self) -> None:
            from picode.ssh_remote import SshProfile, upsert_ssh_profile

            try:
                port = int(self.port.text().strip() or "22")
            except ValueError:
                port = 22
            try:
                profile = SshProfile(
                    name=self.name.text().strip(),
                    host=self.host.text().strip(),
                    port=port,
                    username=self.user.text().strip(),
                    auth=str(self.auth.currentData()),
                    private_key=self.key_path.text().strip(),
                    passphrase=self.passphrase.text(),
                    password=self.password.text(),
                )
                upsert_ssh_profile(profile)
            except Exception as exc:  # noqa: BLE001
                self.status.setText(str(exc))
                return
            self.status.setText(t("ok.ssh_saved", name=profile.name))
            self._reload(profile.name)

        def _delete(self) -> None:
            from picode.ssh_remote import delete_ssh_profile

            name = self.name.text().strip()
            if not name:
                return
            delete_ssh_profile(name)
            self.status.setText(t("ok.ssh_deleted", name=name))
            self._reload()

        def _set_default(self) -> None:
            from picode.ssh_remote import set_ssh_default

            name = self.name.text().strip()
            try:
                set_ssh_default(name)
            except Exception as exc:  # noqa: BLE001
                self.status.setText(str(exc))
                return
            self.status.setText(t("ok.ssh_default", name=name))
            self._reload(name)

        def _test(self) -> None:
            from picode.ssh_remote import test_ssh_connection

            name = self.name.text().strip() or None
            try:
                data = test_ssh_connection(name)
            except Exception as exc:  # noqa: BLE001
                self.status.setText(str(exc))
                return
            self.status.setText(
                t(
                    "ok.ssh_test",
                    name=data.get("connection"),
                    code=data.get("exit_status"),
                )
            )

    class LanguageDialog(QDialog):
        def __init__(self, parent: QWidget | None = None) -> None:
            super().__init__(parent)
            self.setWindowTitle(t("desk.language"))
            self.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            form = QFormLayout(self)
            self.combo = QComboBox()
            for code, label in language_choices():
                self.combo.addItem(label, code)
            cur = get_ui_lang()
            for i in range(self.combo.count()):
                if self.combo.itemData(i) == cur:
                    self.combo.setCurrentIndex(i)
                    break
            form.addRow(t("desk.language"), self.combo)
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText(t("confirm.save"))
            buttons.button(QDialogButtonBox.StandardButton.Cancel).setText(t("confirm.cancel"))
            buttons.accepted.connect(self.accept)
            buttons.rejected.connect(self.reject)
            form.addRow(buttons)

        def selected(self) -> str:
            return str(self.combo.currentData())

    class SettingsDialog(QDialog):
        """Unified settings: permissions, language, SSH, usage (account + session)."""

        def __init__(
            self,
            session: ReplSession,
            parent: QWidget | None = None,
        ) -> None:
            super().__init__(parent)
            self.session = session
            self._perm = PermissionsDialog(self)
            self.setWindowTitle(t("desk.settings_title", brand=BRAND_NAME))
            self.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            self.setMinimumSize(560, 520)
            lay = QVBoxLayout(self)
            tabs = QTabWidget()
            tabs.addTab(self._build_permissions_tab(), t("desk.settings_tab_perm"))
            tabs.addTab(self._build_language_tab(), t("desk.settings_tab_lang"))
            tabs.addTab(self._build_connections_tab(), t("desk.settings_tab_conn"))
            tabs.addTab(self._build_usage_tab(), t("desk.settings_tab_usage"))
            tabs.addTab(self._build_about_tab(), t("desk.settings_tab_about"))
            lay.addWidget(tabs, 1)
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText(t("confirm.save"))
            buttons.button(QDialogButtonBox.StandardButton.Cancel).setText(t("confirm.cancel"))
            buttons.accepted.connect(self.accept)
            buttons.rejected.connect(self.reject)
            lay.addWidget(buttons)

        def _build_permissions_tab(self) -> QWidget:
            w = QWidget()
            outer = QVBoxLayout(w)
            outer.setContentsMargins(0, 0, 0, 0)
            self._perm.setWindowFlags(Qt.WindowType.Widget)
            form = self._perm.layout()
            if isinstance(form, QFormLayout):
                for i in range(form.rowCount()):
                    field = form.itemAt(i, QFormLayout.ItemRole.FieldRole)
                    if field and isinstance(field.widget(), QDialogButtonBox):
                        field.widget().hide()
            outer.addWidget(self._perm)
            return w

        def _build_language_tab(self) -> QWidget:
            w = QWidget()
            form = QFormLayout(w)
            self.lang_combo = QComboBox()
            for code, label in language_choices():
                self.lang_combo.addItem(label, code)
            cur = get_ui_lang()
            for i in range(self.lang_combo.count()):
                if self.lang_combo.itemData(i) == cur:
                    self.lang_combo.setCurrentIndex(i)
                    break
            form.addRow(t("desk.language"), self.lang_combo)
            hint = QLabel(t("desk.settings_lang_hint"))
            hint.setWordWrap(True)
            form.addRow(hint)
            return w

        def _build_connections_tab(self) -> QWidget:
            w = QWidget()
            lay = QVBoxLayout(w)
            hint = QLabel(t("desk.conn_hint"))
            hint.setWordWrap(True)
            lay.addWidget(hint)
            btn = QPushButton(t("desk.connections"))
            btn.clicked.connect(self._open_connections)
            lay.addWidget(btn)
            lay.addStretch(1)
            return w

        def _open_connections(self) -> None:
            ConnectionsDialog(self).exec()

        def _build_usage_tab(self) -> QWidget:
            w = QWidget()
            lay = QVBoxLayout(w)
            self.usage_view = QTextEdit()
            self.usage_view.setReadOnly(True)
            self.usage_view.setLayoutDirection(Qt.LeftToRight)
            lay.addWidget(self.usage_view, 1)
            refresh = QPushButton(t("desk.usage_refresh"))
            refresh.clicked.connect(self._reload_usage)
            lay.addWidget(refresh)
            self._reload_usage()
            return w

        def _reload_usage(self) -> None:
            from picode.api_client import ApiClient, get_token
            from picode.diff_view import usage_lines_from_me
            from picode.language import terminal_text

            lines: list[str] = [t("desk.usage_account_title"), ""]
            if not get_token():
                lines.append(t("warn.not_signed_in"))
            else:
                try:
                    bundle = ApiClient().usage_bundle()
                    me = bundle.get("me") or {}
                    lines.extend(usage_lines_from_me(me))
                    wallet = bundle.get("wallet")
                    if isinstance(wallet, dict) and wallet:
                        lines.extend(["", t("desk.usage_wallet_api_title"), ""])
                        for key, val in wallet.items():
                            lines.append(f"{key}: {terminal_text(val)}")
                    report = bundle.get("token_report")
                    if isinstance(report, dict) and report:
                        lines.extend(["", t("desk.usage_token_report_title"), ""])
                        for key, val in list(report.items())[:40]:
                            lines.append(f"{key}: {terminal_text(val)[:500]}")
                except Exception as exc:  # noqa: BLE001
                    lines.append(str(exc))
            lines.extend(["", t("desk.usage_session_title"), ""])
            lines.append(
                f"{t('desk.usage_session_msgs')}: {len(self.session.history)}"
            )
            lines.append(
                f"{t('desk.usage_session_tokens')}: ~{self.session.approx_tokens()}"
            )
            totals = self.session.usage_totals or {}
            lines.append(
                f"{t('desk.usage_session_turns')}: {totals.get('turns', 0)}"
            )
            lines.append(
                f"{t('desk.usage_session_prompt_total')}: {totals.get('prompt_tokens', 0)}"
            )
            lines.append(
                f"{t('desk.usage_session_completion_total')}: "
                f"{totals.get('completion_tokens', 0)}"
            )
            lines.append(
                f"{t('desk.usage_session_token_total')}: {totals.get('total_tokens', 0)}"
            )
            if self.session.last_usage:
                u = self.session.last_usage
                lines.append(
                    f"{t('desk.usage_last_prompt')}: {u.get('prompt_tokens', 0)}"
                )
                lines.append(
                    f"{t('desk.usage_last_completion')}: {u.get('completion_tokens', 0)}"
                )
                for key, val in u.items():
                    if key in ("prompt_tokens", "completion_tokens"):
                        continue
                    lines.append(f"{key}: {val}")
            else:
                lines.append(t("desk.usage_session_empty"))
            self.usage_view.setPlainText("\n".join(lines))

        def _build_about_tab(self) -> QWidget:
            from picode.config_helpers import project_picode_dir, project_root

            w = QWidget()
            lay = QVBoxLayout(w)
            about = QLabel(
                t(
                    "desk.settings_about",
                    brand=BRAND_NAME,
                    version=__version__,
                    root=project_root(),
                    picode=project_picode_dir(),
                )
            )
            about.setWordWrap(True)
            about.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            lay.addWidget(about)
            lay.addStretch(1)
            return w

        def apply(self) -> str | None:
            """Apply permissions + language. Returns new lang if language changed."""
            self._perm.apply()
            new_lang = str(self.lang_combo.currentData())
            prev = get_ui_lang()
            if new_lang != prev:
                set_ui_lang(new_lang)
                return new_lang
            return None

    class FilterPickerDialog(QDialog):
        """Generic filterable list picker — value stored in UserRole, label shown only."""

        def __init__(
            self,
            title: str,
            rows: list[tuple[str, str]],
            *,
            current: str | None = None,
            parent: QWidget | None = None,
        ) -> None:
            super().__init__(parent)
            self._all = list(rows)
            self._chosen: str | None = None
            self._current = current
            self.setWindowTitle(title)
            self.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            self.setMinimumSize(440, 480)
            lay = QVBoxLayout(self)
            self.filter = QLineEdit()
            self.filter.setPlaceholderText(t("desk.picker_filter"))
            self.filter.setLayoutDirection(Qt.LeftToRight)
            self.filter.textChanged.connect(self._refill)
            self.list = QListWidget()
            self.list.setLayoutDirection(Qt.LeftToRight)
            self.list.itemActivated.connect(self._accept_item)
            self.list.itemDoubleClicked.connect(self._accept_item)
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText(t("confirm.save"))
            buttons.button(QDialogButtonBox.StandardButton.Cancel).setText(
                t("confirm.cancel")
            )
            buttons.accepted.connect(self._accept_current)
            buttons.rejected.connect(self.reject)
            lay.addWidget(self.filter)
            lay.addWidget(self.list, 1)
            lay.addWidget(buttons)
            self._refill()
            self.filter.setFocus()

        def _refill(self, _text: str = "") -> None:
            needle = self.filter.text().strip().lower()
            self.list.clear()
            current_row = 0
            shown = 0
            for label, value in self._all:
                if needle and needle not in label.lower() and needle not in value.lower():
                    continue
                mark = " ●" if self._current and value == self._current else ""
                item = QListWidgetItem(f"{label}{mark}")
                item.setData(Qt.ItemDataRole.UserRole, value)
                self.list.addItem(item)
                if self._current and value == self._current:
                    current_row = shown
                shown += 1
            if self.list.count():
                self.list.setCurrentRow(current_row)

        def _accept_item(self, item=None) -> None:
            row = item or self.list.currentItem()
            if row is None:
                return
            self._chosen = str(row.data(Qt.ItemDataRole.UserRole) or "") or None
            if self._chosen:
                self.accept()

        def _accept_current(self) -> None:
            self._accept_item(self.list.currentItem())

        def chosen(self) -> str | None:
            return self._chosen

    class ModelsDialog(FilterPickerDialog):
        """Filterable name-only model picker. Labels strip arvan_; ids stay real."""

        def __init__(
            self,
            models: list,
            current_id: str | None,
            parent: QWidget | None = None,
        ) -> None:
            from picode.model_picker import filter_models

            rows = [(label, mid) for label, mid, _m in filter_models(models, "")]
            super().__init__(
                t("desk.models_pick"),
                rows,
                current=current_id,
                parent=parent,
            )

        def chosen_id(self) -> str | None:
            return self.chosen()

    class DiffDialog(QDialog):
        """Unified / before-after preview before applying a file write."""

        def __init__(
            self,
            path: str,
            old: str,
            new: str,
            unified: str,
            parent: QWidget | None = None,
        ) -> None:
            super().__init__(parent)
            self.setWindowTitle(t("desk.diff_title", path=path))
            self.setLayoutDirection(Qt.LeftToRight)
            self.resize(820, 560)
            lay = QVBoxLayout(self)
            hint = QLabel(t("desk.diff_hint", path=path))
            hint.setWordWrap(True)
            lay.addWidget(hint)
            tabs = QTabWidget()
            uni = QPlainTextEdit()
            uni.setReadOnly(True)
            uni.setPlainText(unified or "(no changes)")
            uni.setFont(QFont(MONO_FONT, 10))
            before = QPlainTextEdit()
            before.setReadOnly(True)
            before.setPlainText(old if old else "(new file)")
            before.setFont(QFont(MONO_FONT, 10))
            after = QPlainTextEdit()
            after.setReadOnly(True)
            after.setPlainText(new or "")
            after.setFont(QFont(MONO_FONT, 10))
            tabs.addTab(uni, t("desk.diff_unified"))
            tabs.addTab(before, t("desk.diff_before"))
            tabs.addTab(after, t("desk.diff_after"))
            lay.addWidget(tabs, 1)
            buttons = QDialogButtonBox(
                QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
            )
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText(t("desk.diff_apply"))
            buttons.button(QDialogButtonBox.StandardButton.Cancel).setText(
                t("desk.diff_skip")
            )
            buttons.accepted.connect(self.accept)
            buttons.rejected.connect(self.reject)
            lay.addWidget(buttons)

    class Window(QMainWindow):
        def __init__(self) -> None:
            super().__init__()
            import picode.slash as slash_mod
            from picode.chat_store import ensure_active_chat

            self.session = ensure_active_chat()
            self.worker: Worker | None = None
            self._attached: list[str] = []
            self._switching_chat = False
            self.setObjectName("root")
            self.setWindowTitle(f"{BRAND_NAME} {__version__}")
            self.resize(1100, 780)
            icon_path = brand_icon_path()
            if icon_path is not None:
                self.setWindowIcon(QIcon(str(icon_path)))
            slash_mod.ssh_editor_hook = self._do_connections
            self._apply_direction()
            self._apply_ui_font()

            central = QWidget()
            central.setObjectName("central")
            self.setCentralWidget(central)

            # —— Left: projects + local session list ——
            from picode.config_helpers import project_picode_dir, project_root

            sidebar = QFrame()
            sidebar.setObjectName("sidebar")
            sidebar.setMinimumWidth(210)
            sidebar.setMaximumWidth(300)
            side_lay = QVBoxLayout(sidebar)
            side_lay.setContentsMargins(10, 12, 10, 12)
            side_lay.setSpacing(8)
            self.projects_title = QLabel(t("desk.projects_title"))
            self.projects_title.setObjectName("projectLabel")
            self.project_list = QListWidget()
            self.project_list.setObjectName("projectList")
            self.project_list.setLayoutDirection(Qt.LeftToRight)
            self.project_list.itemClicked.connect(self._on_project_clicked)
            side_btns = QHBoxLayout()
            self.btn_add_project = QPushButton(t("desk.project_add"))
            self.btn_add_project.clicked.connect(self._add_project)
            self.btn_remove_project = QPushButton(t("desk.project_remove"))
            self.btn_remove_project.clicked.connect(self._remove_project)
            side_btns.addWidget(self.btn_add_project)
            side_btns.addWidget(self.btn_remove_project)
            side_lay.addWidget(self.projects_title)
            side_lay.addWidget(self.project_list, 1)
            side_lay.addLayout(side_btns)

            self.chats_title = QLabel(t("desk.chats_title"))
            self.chats_title.setObjectName("projectLabel")
            self.chat_list = QListWidget()
            self.chat_list.setObjectName("chatList")
            self.chat_list.setLayoutDirection(Qt.LeftToRight)
            self.chat_list.itemClicked.connect(self._on_chat_clicked)
            chat_btns = QHBoxLayout()
            self.btn_new_chat = QPushButton(t("desk.chat_new"))
            self.btn_new_chat.clicked.connect(self._new_chat)
            self.btn_del_chat = QPushButton(t("desk.chat_delete"))
            self.btn_del_chat.clicked.connect(self._delete_chat)
            chat_btns.addWidget(self.btn_new_chat)
            chat_btns.addWidget(self.btn_del_chat)
            side_lay.addWidget(self.chats_title)
            side_lay.addWidget(self.chat_list, 1)
            side_lay.addLayout(chat_btns)

            # —— Right: chat column ——
            right = QWidget()
            right_lay = QVBoxLayout(right)
            right_lay.setContentsMargins(12, 12, 16, 12)
            right_lay.setSpacing(8)

            title = QLabel(BRAND_NAME)
            title.setObjectName("title")
            title.setLayoutDirection(Qt.LeftToRight)
            self.subtitle = QLabel(t("desk.subtitle", version=__version__))
            self.subtitle.setObjectName("hint")

            self.activity_label = QLabel(t("status.done"))
            self.activity_label.setObjectName("activity")
            self.activity_label.setMinimumHeight(28)

            project_box = QFrame()
            project_box.setObjectName("projectBox")
            project_lay = QVBoxLayout(project_box)
            project_lay.setContentsMargins(12, 8, 12, 8)
            project_lay.setSpacing(4)
            self.project_label = QLabel(t("desk.project_box"))
            self.project_label.setObjectName("projectLabel")
            self.project_hint = QLabel(t("desk.project_hint"))
            self.project_hint.setObjectName("hint")
            self.project_hint.setWordWrap(True)
            path_row = QHBoxLayout()
            self.project_edit = QLineEdit(str(project_root()))
            self.project_edit.setObjectName("projectEdit")
            self.project_edit.setLayoutDirection(Qt.LeftToRight)
            self.project_edit.setFont(QFont(MONO_FONT, 10))
            self.project_edit.returnPressed.connect(self._apply_project_path)
            self.btn_browse = QPushButton(t("desk.project_browse"))
            self.btn_browse.clicked.connect(self._browse_project)
            self.btn_apply_project = QPushButton(t("desk.project_apply"))
            self.btn_apply_project.clicked.connect(self._apply_project_path)
            path_row.addWidget(self.project_edit, 1)
            path_row.addWidget(self.btn_browse)
            path_row.addWidget(self.btn_apply_project)
            project_lay.addWidget(self.project_label)
            project_lay.addLayout(path_row)
            project_lay.addWidget(self.project_hint)
            self.temp_hint = QLabel(
                t("desk.project_temp", path=project_picode_dir())
            )
            self.temp_hint.setObjectName("hint")
            self.temp_hint.setWordWrap(True)
            self.temp_hint.setLayoutDirection(Qt.LeftToRight)
            project_lay.addWidget(self.temp_hint)

            tab_row = QHBoxLayout()
            self.chat_tabs = QTabWidget()
            self.chat_tabs.setObjectName("chatTabs")
            self.chat_tabs.setTabsClosable(True)
            self.chat_tabs.setDocumentMode(True)
            self.chat_tabs.setMovable(True)
            self.chat_tabs.currentChanged.connect(self._on_tab_changed)
            self.chat_tabs.tabCloseRequested.connect(self._on_tab_close)
            self.btn_tab_new = QPushButton("+")
            self.btn_tab_new.setFixedWidth(32)
            self.btn_tab_new.setToolTip(t("desk.chat_new"))
            self.btn_tab_new.clicked.connect(self._new_chat)
            tab_row.addWidget(self.chat_tabs, 1)
            tab_row.addWidget(self.btn_tab_new)

            self.output = QTextEdit()
            self.output.setReadOnly(True)
            self.output.setLayoutDirection(
                Qt.RightToLeft if is_rtl() else Qt.LeftToRight
            )

            # Composer: model switcher + attachments + multiline input
            composer = QFrame()
            composer.setObjectName("composer")
            composer_lay = QVBoxLayout(composer)
            composer_lay.setContentsMargins(10, 8, 10, 8)
            composer_lay.setSpacing(6)
            model_row = QHBoxLayout()
            self.model_label = QLabel(t("desk.model_switch"))
            self.model_combo = QComboBox()
            self.model_combo.setMinimumWidth(180)
            self.model_combo.setLayoutDirection(Qt.LeftToRight)
            self.model_combo.activated.connect(self._on_model_combo)
            self.btn_refresh_models = QPushButton(t("desk.models"))
            self.btn_refresh_models.clicked.connect(self._open_models_picker)
            model_row.addWidget(self.model_label)
            model_row.addWidget(self.model_combo, 1)
            model_row.addWidget(self.btn_refresh_models)
            composer_lay.addLayout(model_row)

            attach_row = QHBoxLayout()
            self.btn_attach = QPushButton(t("desk.attach_files"))
            self.btn_attach.clicked.connect(self._attach_files)
            self.btn_clear_attach = QPushButton(t("desk.attach_clear"))
            self.btn_clear_attach.clicked.connect(self._clear_attachments)
            self.attach_label = QLabel(t("desk.attach_empty"))
            self.attach_label.setObjectName("hint")
            self.attach_label.setWordWrap(True)
            self.attach_label.setLayoutDirection(Qt.LeftToRight)
            attach_row.addWidget(self.btn_attach)
            attach_row.addWidget(self.btn_clear_attach)
            attach_row.addWidget(self.attach_label, 1)
            composer_lay.addLayout(attach_row)

            self.input = QPlainTextEdit()
            self.input.setObjectName("composerInput")
            self.input.setPlaceholderText(t("desk.placeholder_multi"))
            self.input.setLayoutDirection(
                Qt.RightToLeft if is_rtl() else Qt.LeftToRight
            )
            self.input.setFixedHeight(88)
            self._slash_labels = _slash_labels()
            self._completer = QCompleter(self._slash_labels, self.input)
            self._completer.setCaseSensitivity(Qt.CaseInsensitive)
            self._completer.setFilterMode(Qt.MatchContains)
            self._completer.setCompletionMode(QCompleter.PopupCompletion)
            self._completer.setModel(QStringListModel(self._slash_labels))
            self._completer.activated.connect(self._on_complete)
            self._file_mode = False
            self._saved_line = ""
            self._saved_cursor = 0
            self.files = QListWidget()
            self.files.setMaximumHeight(160)
            self.files.hide()
            self.files.setLayoutDirection(Qt.LeftToRight)
            self.files.itemActivated.connect(self._pick_file)
            self.input.installEventFilter(self)
            self.input.textChanged.connect(self._on_input_changed)

            self.send = QPushButton(t("desk.send"))
            self.send.clicked.connect(self._submit)
            send_row = QHBoxLayout()
            send_row.addStretch(1)
            send_row.addWidget(self.send)
            composer_lay.addWidget(self.files)
            composer_lay.addWidget(self.input)
            composer_lay.addLayout(send_row)

            line = QFrame()
            line.setFrameShape(QFrame.Shape.HLine)
            line.setObjectName("rule")

            right_lay.addWidget(title)
            right_lay.addWidget(self.subtitle)
            right_lay.addWidget(line)
            right_lay.addWidget(project_box)
            right_lay.addLayout(tab_row)
            right_lay.addWidget(self.activity_label)
            right_lay.addWidget(self.output, 1)
            right_lay.addWidget(composer)

            splitter = QSplitter()
            splitter.setObjectName("mainSplit")
            splitter.addWidget(sidebar)
            splitter.addWidget(right)
            splitter.setStretchFactor(0, 0)
            splitter.setStretchFactor(1, 1)
            splitter.setSizes([240, 860])

            lay = QHBoxLayout(central)
            lay.setContentsMargins(0, 0, 0, 0)
            lay.addWidget(splitter)

            self._build_menus()
            self._build_toolbar()
            self.status = QStatusBar()
            self.setStatusBar(self.status)
            self._reload_project_list()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self._reload_model_combo()
            self._refresh_status_bar()
            self._refresh_attach_label()

            self._apply_stylesheet()
            if not self.session.ui_log:
                self._append(
                    None, t("desk.welcome", brand=BRAND_NAME, version=__version__)
                )
            else:
                self._restore_ui_log()
            self._start(None)

        def _apply_direction(self) -> None:
            direction = Qt.RightToLeft if is_rtl() else Qt.LeftToRight
            self.setLayoutDirection(direction)
            app = QApplication.instance()
            if app is not None:
                app.setLayoutDirection(direction)

        def _apply_ui_font(self) -> None:
            ensure_vazir_loaded()
            family = ui_font_family()
            app = QApplication.instance()
            if app is not None:
                app.setFont(QFont(family, 11))
            if hasattr(self, "output"):
                self.output.setFont(QFont(family, 11))
            if hasattr(self, "input"):
                self.input.setFont(QFont(family, 12))
            if hasattr(self, "subtitle"):
                self.subtitle.setFont(QFont(family, 11))
            if hasattr(self, "activity_label"):
                self.activity_label.setFont(QFont(family, 11))

        def _apply_stylesheet(self) -> None:
            family = ui_font_family()
            # CSS family quote; fall back stack for Latin chrome
            stack = f'"{family}", "{LATIN_UI_FONT}", Tahoma, sans-serif'
            self.setStyleSheet(
                f"""
                QMainWindow, QWidget#central {{ background: #0b1220; }}
                QFrame#sidebar {{
                    background: #0a0f1a; border-right: 1px solid #1f2937;
                }}
                QLabel#title {{
                    color: #2dd4bf; font-size: 22px; font-weight: 700;
                    font-family: {stack};
                    letter-spacing: 0.5px;
                }}
                QLabel#hint {{ color: #94a3b8; font-size: 12px; font-family: {stack}; }}
                QLabel#activity {{
                    color: #67e8f9; font-size: 12px; font-family: {stack};
                    background: #111827; border: 1px solid #1f2937;
                    border-radius: 6px; padding: 6px 10px;
                }}
                QFrame#projectBox, QFrame#composer {{
                    background: #0f172a; border: 1px solid #334155;
                    border-radius: 10px;
                }}
                QLabel#projectLabel {{
                    color: #2dd4bf; font-size: 12px; font-weight: 700;
                    font-family: {stack};
                }}
                QLineEdit#projectEdit {{
                    background: #111827; color: #e5e7eb;
                    border: 1px solid #475569; border-radius: 8px; padding: 8px 10px;
                }}
                QPlainTextEdit#composerInput {{
                    background: #111827; color: #e5e7eb;
                    border: 1px solid #14b8a6; border-radius: 8px; padding: 10px 12px;
                    font-family: {stack};
                }}
                QFrame#rule {{ color: #1f2937; max-height: 1px; }}
                QTextEdit {{
                    background: #111827; color: #e5e7eb;
                    border: 1px solid #1f2937; border-radius: 10px; padding: 14px;
                    selection-background-color: #0d9488;
                    font-family: {stack};
                }}
                QLineEdit {{
                    background: #111827; color: #e5e7eb;
                    border: 1px solid #14b8a6; border-radius: 10px; padding: 11px 14px;
                    font-family: {stack};
                }}
                QPushButton {{
                    background: #0d9488; color: #042f2e; font-weight: 700;
                    border: none; border-radius: 8px; padding: 8px 14px;
                    min-width: 64px; font-family: {stack};
                }}
                QPushButton:disabled {{ background: #334155; color: #94a3b8; }}
                QToolBar {{
                    background: #0f172a; border: none; spacing: 6px;
                    padding: 4px 8px; margin: 0;
                }}
                QToolBar::separator {{
                    background: #334155; width: 1px; margin: 6px 8px;
                }}
                QToolBar QToolButton {{
                    background: transparent; color: #e2e8f0; border-radius: 6px;
                    padding: 6px 10px; font-weight: 600; font-family: {stack};
                }}
                QToolBar QToolButton:hover {{ background: #134e4a; color: #ecfeff; }}
                QMenuBar {{
                    background: #0f172a; color: #e2e8f0;
                    padding: 2px 6px; spacing: 2px; font-family: {stack};
                }}
                QMenuBar::item {{ padding: 5px 10px; margin: 0 1px; border-radius: 4px; }}
                QMenuBar::item:selected {{ background: #134e4a; }}
                QMenu {{
                    background: #111827; color: #e2e8f0;
                    border: 1px solid #334155; padding: 4px;
                    font-family: {stack};
                }}
                QMenu::item {{ padding: 6px 28px 6px 16px; border-radius: 4px; }}
                QMenu::item:selected {{ background: #0f766e; }}
                QMenu::separator {{
                    height: 1px; background: #1f2937; margin: 4px 10px;
                }}
                QListWidget {{
                    background: #111827; color: #e5e7eb;
                    border: 1px solid #1f2937; border-radius: 8px;
                    font-family: {stack};
                }}
                QListWidget#projectList, QListWidget#chatList {{
                    border: 1px solid #334155;
                }}
                QListWidget#projectList::item:selected,
                QListWidget#chatList::item:selected {{
                    background: #0f766e; color: #ecfeff;
                }}
                QComboBox, QDialog, QStatusBar, QTabWidget::pane {{
                    background: #111827; color: #e5e7eb; font-family: {stack};
                }}
                QTabBar::tab {{
                    background: #0f172a; color: #94a3b8; padding: 8px 14px;
                    border: 1px solid #1f2937; border-bottom: none;
                    font-family: {stack};
                }}
                QTabBar::tab:selected {{
                    background: #111827; color: #2dd4bf;
                }}
                QStatusBar {{ border-top: 1px solid #1f2937; }}
                """
            )

        def _build_menus(self) -> None:
            menubar = self.menuBar()
            menubar.clear()

            file_menu = menubar.addMenu(t("desk.menu_file"))
            act_exit = QAction(t("cmd./exit"), self)
            act_exit.triggered.connect(self.close)
            file_menu.addAction(act_exit)

            account = menubar.addMenu(t("desk.menu_account"))
            act_login = QAction(t("desk.login"), self)
            act_login.triggered.connect(self._do_login)
            act_logout = QAction(t("desk.logout"), self)
            act_logout.triggered.connect(lambda: self._run_cmd("/logout"))
            act_status = QAction(t("desk.status"), self)
            act_status.triggered.connect(lambda: self._run_cmd("/status"))
            act_update = QAction(t("desk.update"), self)
            act_update.triggered.connect(self._do_update)
            account.addAction(act_login)
            account.addAction(act_logout)
            account.addSeparator()
            account.addAction(act_status)
            account.addAction(act_update)

            tools = menubar.addMenu(t("desk.menu_tools"))
            act_cmds = QAction(t("desk.commands_pick"), self)
            act_cmds.triggered.connect(self._open_commands_picker)
            act_models = QAction(t("desk.models"), self)
            act_models.triggered.connect(self._open_models_picker)
            act_ws = QAction(t("desk.workspaces_pick"), self)
            act_ws.triggered.connect(self._open_workspaces_picker)
            tools.addAction(act_cmds)
            tools.addAction(act_models)
            tools.addAction(act_ws)
            tools.addSeparator()
            for name, label_key in (
                ("/project", "desk.project"),
                ("/config", "cmd./config"),
            ):
                act = QAction(t(label_key), self)
                act.triggered.connect(lambda _=False, c=name: self._run_cmd(c))
                tools.addAction(act)
            tools.addSeparator()
            for name, label_key in (
                ("/cost", "cmd./cost"),
                ("/index", "cmd./index"),
                ("/commit", "cmd./commit"),
                ("/pr", "cmd./pr"),
            ):
                act = QAction(t(label_key), self)
                act.triggered.connect(lambda _=False, c=name: self._run_cmd(c))
                tools.addAction(act)

            settings = menubar.addMenu(t("desk.menu_settings"))
            act_settings = QAction(t("desk.settings_open"), self)
            act_settings.triggered.connect(self._do_settings)
            act_perm = QAction(t("desk.permissions"), self)
            act_perm.triggered.connect(self._do_permissions)
            act_conn = QAction(t("desk.connections"), self)
            act_conn.triggered.connect(self._do_connections)
            act_lang = QAction(t("desk.language"), self)
            act_lang.triggered.connect(self._do_language)
            act_usage = QAction(t("desk.settings_tab_usage"), self)
            act_usage.triggered.connect(lambda: self._do_settings(tab="usage"))
            settings.addAction(act_settings)
            settings.addSeparator()
            settings.addAction(act_perm)
            settings.addAction(act_conn)
            settings.addAction(act_lang)
            settings.addAction(act_usage)

            view = menubar.addMenu(t("desk.menu_view"))
            act_clear = QAction(t("desk.clear"), self)
            act_clear.triggered.connect(lambda: self._run_cmd("/clear"))
            act_clean = QAction(t("cmd./clean"), self)
            act_clean.triggered.connect(lambda: self._run_cmd("/clean"))
            act_hub = QAction(t("desk.open_hub"), self)
            act_hub.triggered.connect(
                lambda: webbrowser.open("https://pigpt.ir/app/cli")
            )
            view.addAction(act_clear)
            view.addAction(act_clean)
            view.addSeparator()
            view.addAction(act_hub)

        def _build_toolbar(self) -> None:
            bar = QToolBar()
            bar.setMovable(False)
            bar.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextOnly)
            self.addToolBar(bar)
            # Compact primary actions only — rest live in menus
            self._tb_help = bar.addAction(
                t("desk.commands_pick"), self._open_commands_picker
            )
            self._tb_models = bar.addAction(t("desk.models"), self._open_models_picker)
            self._tb_projects = bar.addAction(
                t("desk.workspaces_pick"), self._open_workspaces_picker
            )
            bar.addSeparator()
            self._tb_settings = bar.addAction(
                t("desk.settings_open"), self._do_settings
            )
            self._tb_perms = bar.addAction(t("desk.permissions"), self._do_permissions)
            bar.addSeparator()
            self._tb_login = bar.addAction(t("desk.login"), self._do_login)

        def _refresh_chrome(self) -> None:
            from picode.config_helpers import project_picode_dir

            self._apply_direction()
            self._apply_ui_font()
            self._apply_stylesheet()
            self.subtitle.setText(t("desk.subtitle", version=__version__))
            self.input.setPlaceholderText(t("desk.placeholder_multi"))
            self.send.setText(t("desk.send"))
            self.activity_label.setText(t("status.done"))
            self.project_label.setText(t("desk.project_box"))
            self.project_hint.setText(t("desk.project_hint"))
            self.btn_browse.setText(t("desk.project_browse"))
            self.btn_apply_project.setText(t("desk.project_apply"))
            self.projects_title.setText(t("desk.projects_title"))
            self.btn_add_project.setText(t("desk.project_add"))
            self.btn_remove_project.setText(t("desk.project_remove"))
            if hasattr(self, "chats_title"):
                self.chats_title.setText(t("desk.chats_title"))
                self.btn_new_chat.setText(t("desk.chat_new"))
                self.btn_del_chat.setText(t("desk.chat_delete"))
                self.btn_attach.setText(t("desk.attach_files"))
                self.btn_clear_attach.setText(t("desk.attach_clear"))
                self._refresh_attach_label()
            self.model_label.setText(t("desk.model_switch"))
            self.btn_refresh_models.setText(t("desk.models"))
            self.temp_hint.setText(t("desk.project_temp", path=project_picode_dir()))
            self.output.setLayoutDirection(
                Qt.RightToLeft if is_rtl() else Qt.LeftToRight
            )
            self.input.setLayoutDirection(
                Qt.RightToLeft if is_rtl() else Qt.LeftToRight
            )
            self._slash_labels = _slash_labels()
            self._completer.setModel(QStringListModel(self._slash_labels))
            self.menuBar().clear()
            for tb in self.findChildren(QToolBar):
                self.removeToolBar(tb)
            self._build_menus()
            self._build_toolbar()
            self._reload_project_list()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self._sync_project_box()
            self._refresh_status_bar()

        def _sync_project_box(self) -> None:
            from picode.config_helpers import project_picode_dir, project_root

            path = str(project_root())
            if self.project_edit.text().strip() != path:
                self.project_edit.setText(path)
            self.temp_hint.setText(t("desk.project_temp", path=project_picode_dir()))

        def _reload_project_list(self) -> None:
            from picode.config_helpers import current_workspace_name, list_workspaces

            self.project_list.blockSignals(True)
            self.project_list.clear()
            current = current_workspace_name()
            select_row = 0
            for i, w in enumerate(list_workspaces()):
                name = str(w.get("name") or "?")
                path = str(w.get("path") or "")
                item = QListWidgetItem(f"{name}\n{path}")
                item.setData(Qt.ItemDataRole.UserRole, name)
                item.setToolTip(path)
                self.project_list.addItem(item)
                if current and name == current:
                    select_row = i
            if self.project_list.count():
                self.project_list.setCurrentRow(select_row)
            self.project_list.blockSignals(False)

        def _on_project_clicked(self, item: QListWidgetItem) -> None:
            from picode.chat_store import ensure_active_chat, save_chat
            from picode.config_helpers import switch_workspace

            name = str(item.data(Qt.ItemDataRole.UserRole) or "")
            if not name:
                return
            try:
                save_chat(self.session)
            except Exception:  # noqa: BLE001
                pass
            try:
                path = switch_workspace(name)
            except ValueError as exc:
                self._append(None, str(exc))
                return
            self.session = ensure_active_chat()
            self._attached.clear()
            self._refresh_attach_label()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self._restore_ui_log()
            self._sync_project_box()
            self._refresh_status_bar()
            self._append(None, t("ok.workspace_set", name=name, path=path))

        def _add_project(self) -> None:
            from picode.chat_store import ensure_active_chat, save_chat
            from picode.config_helpers import add_workspace, project_root

            chosen = QFileDialog.getExistingDirectory(
                self,
                t("desk.project_add"),
                str(project_root()),
            )
            if not chosen:
                return
            name = Path(chosen).name or "project"
            try:
                save_chat(self.session)
            except Exception:  # noqa: BLE001
                pass
            try:
                add_workspace(name, chosen)
            except ValueError as exc:
                self._append(None, str(exc))
                return
            self.session = ensure_active_chat()
            self._attached.clear()
            self._refresh_attach_label()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self._restore_ui_log()
            self._reload_project_list()
            self._sync_project_box()
            self._refresh_status_bar()
            self._append(None, t("ok.workspace_set", name=name, path=chosen))

        def _remove_project(self) -> None:
            from picode.config_helpers import remove_workspace

            item = self.project_list.currentItem()
            if item is None:
                return
            name = str(item.data(Qt.ItemDataRole.UserRole) or "")
            if not name:
                return
            box = QMessageBox(self)
            box.setWindowTitle(BRAND_NAME)
            box.setText(t("desk.project_remove_confirm", name=name))
            box.setStandardButtons(
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            box.button(QMessageBox.StandardButton.Yes).setText(t("confirm.yes"))
            box.button(QMessageBox.StandardButton.No).setText(t("confirm.no"))
            if box.exec() != QMessageBox.StandardButton.Yes:
                return
            remove_workspace(name)
            self._reload_project_list()
            self._sync_project_box()
            self._refresh_status_bar()

        def _browse_project(self) -> None:
            from picode.config_helpers import project_root

            chosen = QFileDialog.getExistingDirectory(
                self,
                t("desk.project_box"),
                str(project_root()),
            )
            if chosen:
                self.project_edit.setText(chosen)
                self._apply_project_path()

        def _apply_project_path(self) -> None:
            from picode.chat_store import ensure_active_chat, save_chat
            from picode.config_helpers import project_root, set_project_dir

            raw = self.project_edit.text().strip().strip('"')
            if not raw:
                return
            prev = str(project_root())
            try:
                save_chat(self.session)
            except Exception:  # noqa: BLE001
                pass
            try:
                path = set_project_dir(raw)
            except ValueError:
                self._append(None, t("warn.bad_project", path=raw))
                self._sync_project_box()
                return
            self.project_edit.setText(str(path))
            if str(path) != prev:
                self.session = ensure_active_chat()
                self._attached.clear()
                self._refresh_attach_label()
                self._reload_chat_ui(select_id=self.session.chat_id)
                self._restore_ui_log()
            self._reload_project_list()
            self._refresh_status_bar()
            self._append(None, t("ok.project_set", path=path))

        def _reload_model_combo(self) -> None:
            from picode.api_client import ApiClient, get_token
            from picode.config_helpers import get_model_id
            from picode.model_picker import model_label
            from picode.slash import _fetch_models

            self.model_combo.blockSignals(True)
            self.model_combo.clear()
            self.model_combo.addItem(t("desk.model_default"), "")
            current = get_model_id() or ""
            if not get_token():
                self.model_combo.blockSignals(False)
                return
            try:
                models = _fetch_models(ApiClient())
            except Exception:  # noqa: BLE001
                self.model_combo.blockSignals(False)
                return
            select = 0
            for i, m in enumerate(models, start=1):
                mid = str(m.get("id") or "")
                self.model_combo.addItem(model_label(m), mid)
                if mid and mid == current:
                    select = i
            self.model_combo.setCurrentIndex(select)
            self.model_combo.blockSignals(False)

        def _on_model_combo(self, index: int) -> None:
            from picode.config_helpers import clear_model_id, set_model_id

            mid = self.model_combo.itemData(index)
            label = self.model_combo.itemText(index)
            if not mid:
                clear_model_id()
                self._append(None, t("info.default_model"))
                return
            set_model_id(str(mid))
            self._append(None, t("ok.model_set", name=label))

        def _refresh_status_bar(self) -> None:
            from picode.config_helpers import (
                current_workspace_name,
                get_model_id,
                project_root,
            )

            root = project_root()
            ws = current_workspace_name() or "—"
            model = get_model_id() or "default"
            usage_bit = ""
            if self.session.last_usage:
                u = self.session.last_usage
                usage_bit = (
                    f" · last {u.get('prompt_tokens', 0)}+"
                    f"{u.get('completion_tokens', 0)} tok"
                )
            self.status.showMessage(
                f"{BRAND_NAME} {__version__} · {get_ui_lang()} · {ws} · {root} · "
                f"model {model}{usage_bit}"
            )
            self._sync_project_box()

        @staticmethod
        def _slash_name(line: str | None) -> str:
            if not line:
                return ""
            return line.strip().split()[0].lower()

        def _handle_clean_ui(self, line: str | None) -> bool:
            """Clear the chat panel for /clear and /clean (Qt bridge)."""
            name = self._slash_name(line)
            if name not in ("/clear", "/clean"):
                return False
            self.output.clear()
            if name == "/clean":
                self.session.reset()
            return True

        def _sync_width(self) -> None:
            import picode.ui as ui

            adv = max(QFontMetrics(self.output.font()).horizontalAdvance("n"), 1)
            ui.PANEL_COLUMNS = max(48, self.output.viewport().width() // adv)

        def _append(self, user_line: str | None, body: str) -> None:
            cursor = self.output.textCursor()
            cursor.movePosition(QTextCursor.End)
            if user_line:
                prompt = QTextCharFormat()
                prompt.setForeground(QColor("#2dd4bf"))
                prompt.setFontWeight(700)
                cursor.insertText(f"\n> {user_line}\n", prompt)
                self.session.append_ui("user", user_line)
            if body:
                normal = QTextCharFormat()
                normal.setForeground(QColor("#e5e7eb"))
                cursor.insertText(body + "\n", normal)
                self.session.append_ui("assistant", body)
            self.output.setTextCursor(cursor)
            self.output.ensureCursorVisible()
            try:
                from picode.chat_store import save_chat

                if self.session.chat_id and not self._switching_chat:
                    save_chat(self.session)
                    self._sync_tab_title()
            except Exception:  # noqa: BLE001
                pass

        def _append_activity(self, kind: str, message: str) -> None:
            if not message and kind == "done":
                self.activity_label.setText(t("status.done"))
                return
            if not message:
                return
            self.activity_label.setText(f"● {message}")
            cursor = self.output.textCursor()
            cursor.movePosition(QTextCursor.End)
            fmt = QTextCharFormat()
            colors = {
                "thinking": "#67e8f9",
                "reading": "#a5b4fc",
                "writing": "#86efac",
                "running": "#fcd34d",
                "error": "#fca5a5",
                "info": "#94a3b8",
            }
            fmt.setForeground(QColor(colors.get(kind, "#94a3b8")))
            cursor.insertText(f"  · {message}\n", fmt)
            self.output.setTextCursor(cursor)
            self.output.ensureCursorVisible()

        def _set_busy(self, busy_flag: bool) -> None:
            self.input.setEnabled(not busy_flag)
            self.send.setEnabled(not busy_flag)
            self.project_edit.setEnabled(not busy_flag)
            self.btn_browse.setEnabled(not busy_flag)
            self.btn_apply_project.setEnabled(not busy_flag)
            self.project_list.setEnabled(not busy_flag)
            self.btn_add_project.setEnabled(not busy_flag)
            self.btn_remove_project.setEnabled(not busy_flag)
            if hasattr(self, "chat_list"):
                self.chat_list.setEnabled(not busy_flag)
                self.btn_new_chat.setEnabled(not busy_flag)
                self.btn_del_chat.setEnabled(not busy_flag)
                self.btn_tab_new.setEnabled(not busy_flag)
                self.chat_tabs.setEnabled(not busy_flag)
                self.btn_attach.setEnabled(not busy_flag)
                self.btn_clear_attach.setEnabled(not busy_flag)
            self.model_combo.setEnabled(not busy_flag)
            self.menuBar().setEnabled(not busy_flag)
            for tb in self.findChildren(QToolBar):
                tb.setEnabled(not busy_flag)
            self.send.setText(t("desk.busy") if busy_flag else t("desk.send"))
            if busy_flag:
                self.activity_label.setText(t("status.busy"))
            else:
                self.activity_label.setText(t("status.done"))

        def _try_ui_picker(self, line: str | None) -> bool:
            """Open in-app pickers for menu/list slash cmds — never dump tables into chat."""
            if not line:
                return False
            parts = line.strip().split()
            if not parts:
                return False
            name = parts[0].lower()
            args = parts[1:]
            if name in ("/help", "/h", "/?") or line.strip() == "/":
                self._open_commands_picker()
                return True
            if name == "/models" or (name == "/model" and not args):
                self._open_models_picker()
                return True
            if name in ("/permissions", "/perm") and not args:
                self._do_permissions()
                return True
            if name == "/ssh" and (not args or args[0].lower() in ("list", "ls", "add")):
                self._do_connections()
                return True
            if name == "/language" and not args:
                self._do_language()
                return True
            if name in ("/workspaces",) and not args:
                self._open_workspaces_picker()
                return True
            if name in ("/settings",) and not args:
                self._do_settings()
                return True
            if name in ("/cost", "/usage") and not args:
                self._do_settings(tab="usage")
                return True
            return False

        def _open_commands_picker(self) -> None:
            rows = [(f"{cmd}  —  {desc}", cmd) for cmd, desc in localized_commands()]
            dlg = FilterPickerDialog(t("desk.commands_pick"), rows, parent=self)
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            cmd = dlg.chosen()
            if not cmd:
                return
            if cmd in ("/help", "/h", "/?"):
                return
            if cmd in NEEDS_ARGS:
                self._set_input_text(cmd + " ", len(cmd) + 1)
                self.input.setFocus()
                return
            # Nested pickers / actions — avoid printing help text into chat.
            if self._try_ui_picker(cmd):
                return
            self._pending_line = cmd
            self._start(cmd)

        def _open_models_picker(self) -> None:
            from picode.api_client import ApiClient, get_token
            from picode.config_helpers import get_model_id, set_model_id
            from picode.model_picker import model_label
            from picode.slash import _fetch_models

            if not get_token():
                self._append(None, t("warn.not_signed_in"))
                return
            try:
                models = _fetch_models(ApiClient())
            except Exception as exc:  # noqa: BLE001
                self._append(None, str(exc))
                return
            current = get_model_id()
            dlg = ModelsDialog(models, current, self)
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            chosen = dlg.chosen_id()
            if not chosen:
                return
            set_model_id(chosen)
            picked = next((m for m in models if str(m.get("id")) == chosen), None)
            name = model_label(picked) if picked else chosen
            self._reload_model_combo()
            self._append(None, t("ok.model_set", name=name))

        def _open_workspaces_picker(self) -> None:
            from picode.config_helpers import list_workspaces, project_root, switch_workspace

            workspaces = list_workspaces()
            if not workspaces:
                self._add_project()
                return
            root = str(project_root())
            rows = [
                (f"{w.get('name', '?')}  —  {w.get('path', '')}", str(w.get("name", "")))
                for w in workspaces
                if w.get("name")
            ]
            current = next(
                (str(w.get("name")) for w in workspaces if w.get("path") == root),
                None,
            )
            dlg = FilterPickerDialog(
                t("desk.workspaces_pick"), rows, current=current, parent=self
            )
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            name = dlg.chosen()
            if not name:
                return
            try:
                path = switch_workspace(name)
            except ValueError as exc:
                self._append(None, str(exc))
                return
            self._reload_project_list()
            self._sync_project_box()
            self._refresh_status_bar()
            self._append(None, t("ok.workspace_set", name=name, path=path))

        def _start(self, line: str | None) -> None:
            if self.worker and self.worker.isRunning():
                return
            if self._try_ui_picker(line):
                self._pending_line = None
                return
            # Clear the Qt panel immediately so /clear and /clean work like the CLI.
            cleaned = self._handle_clean_ui(line)
            self._sync_width()
            self._set_busy(True)
            self.worker = Worker(self.session, line)
            self.worker.need_confirm.connect(self._confirm)
            self.worker.need_diff.connect(self._confirm_diff)
            self.worker.activity.connect(self._append_activity)
            self.worker.finished_text.connect(self._done)
            # Remember so _done can avoid re-dumping a full cleared buffer oddly
            self._last_was_clean = cleaned
            self.worker.start()

        def _confirm(self, text: str) -> None:
            box = QMessageBox(self)
            box.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
            box.setWindowTitle(BRAND_NAME)
            box.setText(text)
            box.setStandardButtons(
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            box.button(QMessageBox.StandardButton.Yes).setText(t("confirm.yes"))
            box.button(QMessageBox.StandardButton.No).setText(t("confirm.no"))
            yes = box.exec() == QMessageBox.StandardButton.Yes
            if self.worker:
                self.worker.provide(yes)

        def _confirm_diff(self, path: str, old: str, new: str, unified: str) -> None:
            dlg = DiffDialog(path, old, new, unified, self)
            yes = dlg.exec() == QDialog.DialogCode.Accepted
            if self.worker:
                self.worker.provide(yes)

        def _done(self, text: str, close: bool) -> None:
            line = getattr(self, "_pending_line", None)
            was_clean = getattr(self, "_last_was_clean", False)
            self._last_was_clean = False
            if was_clean:
                # Panel already cleared; show only the short confirmation line.
                body = (text or "").strip()
                if body:
                    self._append(None, body)
            else:
                self._append(line, text)
            self._pending_line = None
            self._set_busy(False)
            if line and str(line).startswith("/language"):
                self._refresh_chrome()
            elif line and self._slash_name(line) == "/project":
                self._reload_project_list()
                self._sync_project_box()
                self._refresh_status_bar()
            else:
                self._refresh_status_bar()
            self.input.setFocus()
            if close:
                self.close()

        def _run_cmd(self, cmd: str) -> None:
            self._pending_line = cmd
            self._start(cmd)

        def _do_login(self) -> None:
            self._run_cmd("/login")

        def _do_settings(self, tab: str | None = None) -> None:
            dlg = SettingsDialog(self.session, self)
            if tab == "usage":
                # Usage is the 4th tab (0-based index 3)
                tabs = dlg.findChild(QTabWidget)
                if tabs is not None:
                    tabs.setCurrentIndex(3)
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            lang = dlg.apply()
            from picode.config_helpers import (
                get_permissions,
                get_remote_permissions,
                get_shell_permissions,
                get_web_permissions,
            )

            self._append(
                None,
                t(
                    "ok.permissions_saved",
                    files=get_permissions(),
                    shell=get_shell_permissions(),
                    remote=get_remote_permissions(),
                    web=get_web_permissions(),
                ),
            )
            if lang:
                self._refresh_chrome()
                self._append(None, t("ok.language_set", lang=lang))
            self._refresh_status_bar()

        def _do_permissions(self) -> None:
            dlg = PermissionsDialog(self)
            if dlg.exec() == QDialog.DialogCode.Accepted:
                dlg.apply()
                from picode.config_helpers import (
                    get_permissions,
                    get_remote_permissions,
                    get_shell_permissions,
                    get_web_permissions,
                )

                self._append(
                    None,
                    t(
                        "ok.permissions_saved",
                        files=get_permissions(),
                        shell=get_shell_permissions(),
                        remote=get_remote_permissions(),
                        web=get_web_permissions(),
                    ),
                )

        def _do_connections(self) -> None:
            dlg = ConnectionsDialog(self)
            dlg.exec()

        def _do_language(self) -> None:
            dlg = LanguageDialog(self)
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            lang = set_ui_lang(dlg.selected())
            self._refresh_chrome()
            self._append(None, t("ok.language_set", lang=lang))

        def _do_update(self) -> None:
            from picode.updates import format_update_panel, update_notice

            notice = update_notice(force=True)
            if not notice:
                self._append(
                    None, t("ok.up_to_date", brand=BRAND_NAME, version=__version__)
                )
                return
            exe_url = notice.get("windows_exe_url") or notice.get("hub")
            if _is_frozen() and exe_url:
                self._append(
                    None,
                    format_update_panel(notice) + f"\n\n{exe_url}",
                )
                try:
                    webbrowser.open(str(exe_url))
                except Exception:  # noqa: BLE001
                    pass
                return
            self._run_cmd("/update")

        def _input_text(self) -> str:
            return self.input.toPlainText()

        def _input_cursor(self) -> int:
            return self.input.textCursor().position()

        def _set_input_text(self, text: str, cursor: int | None = None) -> None:
            self.input.setPlainText(text)
            if cursor is not None:
                c = self.input.textCursor()
                c.setPosition(min(cursor, len(text)))
                self.input.setTextCursor(c)

        def eventFilter(self, obj, event):  # noqa: N802
            from PySide6.QtCore import QEvent

            if obj is not self.input or event.type() != QEvent.Type.KeyPress:
                return super().eventFilter(obj, event)
            key = event.key()
            mods = event.modifiers()
            if self.files.isVisible():
                if key == Qt.Key.Key_Down:
                    row = min(self.files.currentRow() + 1, self.files.count() - 1)
                    self.files.setCurrentRow(max(row, 0))
                    return True
                if key == Qt.Key.Key_Up:
                    row = max(self.files.currentRow() - 1, 0)
                    self.files.setCurrentRow(row)
                    return True
                if key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                    self._pick_file()
                    return True
                if key == Qt.Key.Key_Escape:
                    self.files.hide()
                    return True
            if key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                if mods & Qt.KeyboardModifier.ShiftModifier:
                    return False  # newline
                self._submit()
                return True
            return super().eventFilter(obj, event)

        def _on_input_changed(self) -> None:
            self._open_slash_menu(self._input_text())

        def _open_slash_menu(self, text: str) -> None:
            from picode.config_helpers import project_root
            from picode.mentions import at_token_span, file_menu_rows

            self._saved_line = text
            self._saved_cursor = self._input_cursor()
            first_line = text.split("\n", 1)[0]
            if first_line.startswith("/") and " " not in first_line and "\n" not in text:
                self._file_mode = False
                self.files.hide()
                self._completer.setModel(QStringListModel(self._slash_labels))
                self._completer.setCompletionPrefix(first_line)
                self._completer.setWidget(self.input)
                self._completer.complete()
                return
            span = at_token_span(text, self._input_cursor())
            if span is None:
                self._file_mode = False
                self.files.hide()
                if self._completer.popup().isVisible():
                    self._completer.popup().hide()
                return
            self._file_mode = True
            self._completer.popup().hide()
            rows = file_menu_rows(project_root(), span[2])
            self.files.clear()
            for label, kind in rows:
                self.files.addItem(f"{label}  —  {kind}")
            if rows:
                self.files.setCurrentRow(0)
                self.files.show()
            else:
                self.files.hide()

        def _pick_file(self, _item=None) -> None:
            from picode.mentions import at_token_span

            current = self.files.currentItem()
            if current is None:
                return
            chosen = current.text().split("—")[0].strip()
            base = self._saved_line
            cursor = min(self._saved_cursor, len(base))
            span = at_token_span(base, cursor)
            if span is None:
                self.files.hide()
                return
            start, end, _query = span
            insertion = chosen if chosen.endswith("/") else chosen + " "
            updated = base[:start] + insertion + base[end:]
            self.files.hide()
            self._set_input_text(updated, start + len(insertion))

        def _on_complete(self, text: object) -> None:
            if self._file_mode:
                return
            if not isinstance(text, str):
                return
            cmd = text.split("—")[0].strip()
            if cmd in NEEDS_ARGS:
                self._set_input_text(cmd + " ", len(cmd) + 1)
                return
            self.input.clear()
            self._pending_line = cmd
            self._start(cmd)

        def _restore_ui_log(self) -> None:
            self.output.clear()
            self._switching_chat = True
            try:
                for entry in self.session.ui_log:
                    kind = entry.get("kind") or "assistant"
                    text = entry.get("text") or ""
                    if not text:
                        continue
                    cursor = self.output.textCursor()
                    cursor.movePosition(QTextCursor.End)
                    if kind == "user":
                        prompt = QTextCharFormat()
                        prompt.setForeground(QColor("#2dd4bf"))
                        prompt.setFontWeight(700)
                        cursor.insertText(f"\n> {text}\n", prompt)
                    else:
                        normal = QTextCharFormat()
                        normal.setForeground(QColor("#e5e7eb"))
                        cursor.insertText(text + "\n", normal)
                    self.output.setTextCursor(cursor)
            finally:
                self._switching_chat = False
            self.output.ensureCursorVisible()

        def _reload_chat_ui(self, select_id: str | None = None) -> None:
            from picode.chat_store import list_chats

            target = select_id or (self.session.chat_id if self.session else None)
            self._switching_chat = True
            try:
                self.chat_list.blockSignals(True)
                self.chat_tabs.blockSignals(True)
                self.chat_list.clear()
                while self.chat_tabs.count():
                    self.chat_tabs.removeTab(0)
                rows = list_chats()
                select_row = 0
                for i, row in enumerate(rows):
                    cid = str(row["id"])
                    title = str(row.get("title") or "Chat")
                    item = QListWidgetItem(title)
                    item.setData(Qt.ItemDataRole.UserRole, cid)
                    item.setToolTip(cid)
                    self.chat_list.addItem(item)
                    self.chat_tabs.addTab(QWidget(), title)
                    self.chat_tabs.tabBar().setTabData(i, cid)
                    if target and cid == target:
                        select_row = i
                if self.chat_list.count():
                    self.chat_list.setCurrentRow(select_row)
                    self.chat_tabs.setCurrentIndex(select_row)
                self.chat_list.blockSignals(False)
                self.chat_tabs.blockSignals(False)
            finally:
                self._switching_chat = False

        def _sync_tab_title(self) -> None:
            if not self.session.chat_id:
                return
            title = self.session.title or "Chat"
            for i in range(self.chat_tabs.count()):
                if str(self.chat_tabs.tabBar().tabData(i) or "") == self.session.chat_id:
                    self.chat_tabs.setTabText(i, title)
                    break
            for i in range(self.chat_list.count()):
                item = self.chat_list.item(i)
                if item and str(item.data(Qt.ItemDataRole.UserRole) or "") == self.session.chat_id:
                    item.setText(title)
                    break

        def _switch_to_chat(self, chat_id: str) -> None:
            from picode.chat_store import load_chat, save_chat

            if not chat_id or chat_id == self.session.chat_id:
                return
            if self.worker and self.worker.isRunning():
                return
            try:
                save_chat(self.session)
            except Exception:  # noqa: BLE001
                pass
            loaded = load_chat(chat_id)
            if loaded is None:
                return
            self.session = loaded
            self._reload_chat_ui(select_id=chat_id)
            self._restore_ui_log()
            self._refresh_status_bar()

        def _on_chat_clicked(self, item: QListWidgetItem) -> None:
            cid = str(item.data(Qt.ItemDataRole.UserRole) or "")
            if cid:
                self._switch_to_chat(cid)

        def _on_tab_changed(self, index: int) -> None:
            if self._switching_chat or index < 0:
                return
            cid = str(self.chat_tabs.tabBar().tabData(index) or "")
            if cid:
                self._switch_to_chat(cid)

        def _on_tab_close(self, index: int) -> None:
            cid = str(self.chat_tabs.tabBar().tabData(index) or "")
            if not cid:
                return
            # Closing a tab deletes the local chat (session list stays in sync).
            self._delete_chat_id(cid)

        def _new_chat(self) -> None:
            from picode.chat_store import create_chat, save_chat

            if self.worker and self.worker.isRunning():
                return
            try:
                save_chat(self.session)
            except Exception:  # noqa: BLE001
                pass
            self.session = create_chat()
            self._attached.clear()
            self._refresh_attach_label()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self.output.clear()
            self._append(None, t("desk.chat_started", title=self.session.title))
            self._refresh_status_bar()

        def _delete_chat(self) -> None:
            item = self.chat_list.currentItem()
            if item is None:
                return
            cid = str(item.data(Qt.ItemDataRole.UserRole) or "")
            if cid:
                self._delete_chat_id(cid)

        def _delete_chat_id(self, chat_id: str) -> None:
            from picode.chat_store import create_chat, delete_chat, ensure_active_chat, list_chats

            if self.worker and self.worker.isRunning():
                return
            box = QMessageBox(self)
            box.setWindowTitle(BRAND_NAME)
            box.setText(t("desk.chat_delete_confirm"))
            box.setStandardButtons(
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            box.button(QMessageBox.StandardButton.Yes).setText(t("confirm.yes"))
            box.button(QMessageBox.StandardButton.No).setText(t("confirm.no"))
            if box.exec() != QMessageBox.StandardButton.Yes:
                return
            delete_chat(chat_id)
            if not list_chats():
                self.session = create_chat()
            else:
                self.session = ensure_active_chat()
            self._reload_chat_ui(select_id=self.session.chat_id)
            self._restore_ui_log()
            if not self.session.ui_log:
                self.output.clear()
                self._append(None, t("desk.chat_started", title=self.session.title))
            self._refresh_status_bar()

        def _refresh_attach_label(self) -> None:
            if not self._attached:
                self.attach_label.setText(t("desk.attach_empty"))
            else:
                self.attach_label.setText(
                    t("desk.attach_list", files=", ".join(f"@{p}" for p in self._attached))
                )

        def _attach_files(self) -> None:
            from picode.config_helpers import project_root

            root = project_root().resolve()
            chosen, _ = QFileDialog.getOpenFileNames(
                self,
                t("desk.attach_files"),
                str(root),
            )
            if not chosen:
                return
            for raw in chosen:
                try:
                    path = Path(raw).resolve()
                except OSError:
                    continue
                if root not in path.parents and path != root:
                    self._append(None, t("desk.attach_outside", path=raw))
                    continue
                rel = str(path.relative_to(root)).replace("\\", "/")
                if rel not in self._attached:
                    self._attached.append(rel)
            # Cap like mentions.MAX_ATTACHED_FILES
            self._attached = self._attached[:8]
            self._refresh_attach_label()

        def _clear_attachments(self) -> None:
            self._attached.clear()
            self._refresh_attach_label()

        def _submit(self) -> None:
            if self.files.isVisible() or self._completer.popup().isVisible():
                return
            if not self.input.isEnabled():
                return
            line = self._input_text().strip()
            if not line and not self._attached:
                return
            if self._attached:
                from picode.mentions import iter_mention_tokens

                existing = set(iter_mention_tokens(line))
                extras = [p for p in self._attached if p not in existing]
                if extras:
                    mention_prefix = " ".join(f"@{p}" for p in extras)
                    line = f"{mention_prefix}\n{line}".strip() if line else mention_prefix
                self._attached.clear()
                self._refresh_attach_label()
            if not line:
                return
            self.input.clear()
            self._pending_line = line
            self._start(line)

    app = QApplication(sys.argv)
    app.setApplicationName(BRAND_NAME)
    app.setOrganizationName("PiGPT")
    ensure_vazir_loaded()
    icon_path = brand_icon_path()
    if icon_path is not None:
        app.setWindowIcon(QIcon(str(icon_path)))
    app.setLayoutDirection(Qt.RightToLeft if is_rtl() else Qt.LeftToRight)
    app.setFont(QFont(ui_font_family(), 11))
    window = Window()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
