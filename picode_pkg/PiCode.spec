# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path

from PyInstaller.utils.hooks import collect_submodules

PKG = Path(SPECPATH)
ICON = PKG / "picode" / "assets" / "brand-pi.ico"
FONT = PKG / "picode" / "fonts" / "Vazirmatn-Regular.ttf"

hiddenimports = []
hiddenimports += collect_submodules("picode")

datas = []
if ICON.is_file():
    datas.append((str(ICON), "picode/assets"))
png = PKG / "picode" / "assets" / "brand-pi.png"
if png.is_file():
    datas.append((str(png), "picode/assets"))
if FONT.is_file():
    datas.append((str(FONT), "picode/fonts"))

a = Analysis(
    [str(PKG / "picode_window.py")],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="PiCode",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ICON) if ICON.is_file() else None,
)
