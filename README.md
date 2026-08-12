# PiGPT Mobile (Flutter)

Native Android/iOS client for [pigpt.ir](https://pigpt.ir) — consumer features only (no admin, PiCode guide-only).

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

## CI

GitHub Actions workflow `.github/workflows/android-apk.yml` runs analyze + test + APK build on push/`workflow_dispatch`.
