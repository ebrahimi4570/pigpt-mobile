# PiGPT Mobile (Flutter)

Native Android/iOS client for [pigpt.ir](https://pigpt.ir) — consumer features only (no admin, PiCode guide-only).

مشکلات شناخته‌شده در برابر وب (برای تکمیل بعدی): [`FLUTTER_VS_WEB_ISSUES.md`](FLUTTER_VS_WEB_ISSUES.md).

## Project path

`C:\MyServer\pigpt-mobile\mobile`

## Run locally

```bash
cd mobile
flutter pub get
flutter run
```

API base is fixed to `https://pigpt.ir` (override only via code for staging).

## Features

- Auth (email/password, optional Google via browser)
- Chat with SSE streaming, chat/agent mode, model picker, rotating starters (no auto-TTS)
- Image attachments on chat (`POST /uploads` + `attachment_ids`)
- Conversation search (server) and archive
- Manual speaker button only (never auto-play)
- Agent missions UI
- Quick Start wizards
- User studios hub (enabled capabilities; «به‌زودی» for others)
- Wallet / plans / settings / support / referral / About
- PiCode install guide + device code confirm

## Build Android APK (public)

**هرگز APK سنگین / fat / universal نسازید.** نسخهٔ عمومی فقط **arm64** است (~۲۰MB)، نه fat سه‌ABI (~۵۸MB). جزئیات: [`docs/APK_BUILD.md`](docs/APK_BUILD.md).

```bash
cd mobile
flutter build apk --release --target-platform android-arm64
```

یا `--split-per-abi` و فقط `app-arm64-v8a-release.apk` را منتشر کنید.  
`flutter build apk --release` بدون `--target-platform` ممنوع است (نسخهٔ ۱.۳.۱ اشتباهاً این کار را کرد و حجم سه‌برابر شد).

## CI

GitHub Actions workflow `.github/workflows/android-apk.yml` runs analyze + test + **arm64-only** APK build on push/`workflow_dispatch`. CI must keep `--target-platform android-arm64`.
