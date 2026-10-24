"""Resolve UI fonts: Vazir/Vazirmatn for fa/ar; Segoe UI for en/tr."""

from __future__ import annotations

import sys
from pathlib import Path

_VAZIR_FAMILY: str | None = None
_LOADED = False

LATIN_UI_FONT = "Segoe UI"
MONO_FONT = "Consolas"


def _package_root() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "picode"  # type: ignore[attr-defined]
    return Path(__file__).resolve().parent


def font_file() -> Path | None:
    candidate = _package_root() / "fonts" / "Vazirmatn-Regular.ttf"
    return candidate if candidate.is_file() else None


def brand_icon_path() -> Path | None:
    root = _package_root() / "assets"
    for name in ("brand-pi.ico", "brand-pi.png"):
        path = root / name
        if path.is_file():
            return path
    # Dev checkout: Flutter brand mark (same PiGPT Pi)
    alt = (
        Path(__file__).resolve().parents[2]
        / "mobile"
        / "assets"
        / "brand"
        / "brand-pi-512.png"
    )
    return alt if alt.is_file() else None


def ensure_vazir_loaded() -> str | None:
    """Register bundled Vazirmatn with Qt; return family name or None."""
    global _VAZIR_FAMILY, _LOADED
    if _LOADED:
        return _VAZIR_FAMILY
    _LOADED = True
    path = font_file()
    if path is None:
        return None
    try:
        from PySide6.QtGui import QFontDatabase

        fid = QFontDatabase.addApplicationFont(str(path))
        if fid < 0:
            return None
        families = QFontDatabase.applicationFontFamilies(fid)
        if not families:
            return None
        _VAZIR_FAMILY = str(families[0])
        return _VAZIR_FAMILY
    except Exception:  # noqa: BLE001
        return None


def ui_font_family(lang: str | None = None) -> str:
    """Primary UI font for the active (or given) chrome language."""
    from picode.i18n import get_ui_lang

    code = (lang or get_ui_lang()).lower()
    if code in ("fa", "ar"):
        family = ensure_vazir_loaded()
        if family:
            return family
        # System fallbacks that cover Arabic script
        return "Vazirmatn"
    return LATIN_UI_FONT


def applies_vazir(lang: str | None = None) -> bool:
    from picode.i18n import get_ui_lang

    return (lang or get_ui_lang()).lower() in ("fa", "ar")
