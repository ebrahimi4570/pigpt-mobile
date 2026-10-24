# PiCode — کلاینت PiGPT

دستیار کدنویسی متصل به API محصول **PiGPT**.

**محصول ویندوزی (سطح اصلی روی ویندوز = پنجرهٔ فارسی، نه ترمینال):** مشخصات قفل‌شده در [`docs/PICODE_WINDOWS_PRODUCT.md`](docs/PICODE_WINDOWS_PRODUCT.md).

- **ویندوز:** اپ پنجره‌ای `PiCode.exe` (رابط فارسی/RTL). هستهٔ CLI زیر آن می‌ماند؛ کاربر نهایی نباید مجبور به ترمینال شود.
- **مک / لینوکس:** سطح محصول اصلی = CLI در ترمینال.

برندها فقط لاتین: **PiCode** / **PiGPT**.

## نصب

### ویندوز (پیشنهادی) — پنجره

دانلود و اجرا:

[https://pigpt.ir/downloads/picode/PiCode.exe](https://pigpt.ir/downloads/picode/PiCode.exe)

صفحهٔ دانلود و متادیتا: [https://pigpt.ir/downloads/picode/](https://pigpt.ir/downloads/picode/)

اختیاری — نصب CLI زیرین (PowerShell)، اگر اتوماسیون ترمینال لازم باشد:

```powershell
irm https://pigpt.ir/install-picode.ps1 | iex
```

### macOS / Linux / WSL — CLI

```bash
curl -fsSL https://pigpt.ir/install-picode.sh | bash
```

اگر در همین شل پیدا نشد:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

نیاز: **Python ≥ 3.10**. اسکریپت venv در `~/.picode-venv` می‌سازد، wheel را از `https://pigpt.ir/downloads/picode/` نصب می‌کند. API پیش‌فرض: `https://pigpt.ir`.

### بعد از نصب (CLI)

```bash
picode --version
picode --help
picode login          # مرورگر روی pigpt.ir
picode                # نشست تعاملی (REPL)
picode chat "سلام"    # یک‌مرحله‌ای → POST /api/v1/cli/chat
```

توکن و تنظیمات در `~/.picode/config.json` ذخیره می‌شوند.

در پنجرهٔ ویندوز: ورود از دکمهٔ «ورود» یا دستور `/login`؛ چت در همان پنجره؛ `/` برای دستورها؛ `@` برای پیوست فایل از پوشهٔ پروژه.

## ورود

```bash
picode login
```

پیش‌فرض API: `https://pigpt.ir` (قابل تغییر با `PICODE_API_URL`، `--api-url`، یا `api_url` در config).

جایگزین:

```bash
picode login --manual
picode login --token "eyJ…"
picode login --no-browser
picode logout
```

## REPL و دستورات اسلش (CLI و همان هسته در پنجره)

بدون زیر‌دستور، `picode` وارد **REPL** می‌شود. داخل REPL با `/` یا `/help` فهرست دستورات را ببینید.

| دستور | کار |
|--------|-----|
| پیام عادی | چت با agent |
| `/help` | راهنما |
| `/status` | احراز هویت، پلن، کوتا |
| `/model [id]` | مدل جاری |
| `/login` / `/logout` | ورود / خروج |
| `/permissions` | مجوز نوشتن فایل / شل |
| `/exit` | خروج از REPL |

## افزونه VS Code

Marketplace نیست. VSIX:

```bash
code --install-extension https://pigpt.ir/downloads/picode/picode-0.1.1.vsix
```

یا از صفحهٔ [دانلود PiCode](https://pigpt.ir/app/cli).

## توسعه از سورس (اختیاری)

```bash
python -m venv .venv && .venv/Scripts/pip install -e ".[desktop]"
picode-desktop
```
