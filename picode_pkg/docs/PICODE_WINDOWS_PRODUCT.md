# محصول ویندوزی PiCode — مشخصات و runbook

**منابع حقیقت (SoT):** این فایل.  
**مالک محصول:** vira  
**تصمیم قفل‌شدهٔ محصول:** ۲۳ اکتبر ۲۰۲۶ (۱ آبان ۱۴۰۵)  
**نسخهٔ پکیج:** `0.2.15` (`picode/__init__.py` / `pyproject.toml`)

برندها همیشه لاتین می‌مانند: **PiCode** و **PiGPT**. توکن برند هرگز به فارسی/آوانویسی نوشته نمی‌شود.

---

## ۱) حکم قفل‌شده (Locked product decision)

| اصل | تصمیم |
|-----|--------|
| هسته | **یک هسته** — همان مغز CLI فعلی. پنجرهٔ ویندوز فقط لایهٔ UI است و همان ماژول‌ها را صدا می‌زند. |
| محصول هدف کاربر نهایی روی ویندوز | **پنجرهٔ GUI حرفه‌ای** — نه کار داخل ترمینال. |
| واقعیت فنی روی ویندوز | هر دو وجود دارند (هسته + پنجره)؛ تجربهٔ پیش‌فرض = پنجره (`PiCode.exe`). |
| مک / لینوکس | سطح محصول اصلی = **CLI** (ترمینال). |
| مسیر ساخت | **تکمیل** محصول PySide6 موجود (`picode/desktop.py`، `PiCode.spec`، `picode_window.py`) — نه Electron، نه از صفر. |
| زبان کروم UI | قابل انتخاب **fa / en / tr / ar**؛ **پیش‌فرض فارسی (`fa`)**؛ ذخیره در `~/.picode/config.json` کلید `ui_language`. برای fa و ar فونت **Vazirmatn** (باندل‌شده)؛ en/tr با Segoe UI. آیکن exe همان mark پی PiGPT (`brand-pi`). |
| پاسخ دستیار | همچنان مطابق زبان پیام کاربر (قانون `language.py` / `LANGUAGE_RULE`) — جدا از زبان UI. |
| فعالیت زنده | همان رویدادهای وضعیت هسته (فکر / خواندن / نوشتن / اجرا / خطا) در CLI و پنجره دیده می‌شود؛ نه فقط پاسخ نهایی. |
| پوشهٔ کار | **چند پروژه / فضای کار** در فهرست؛ هر کدام مسیر خودش را دارد؛ تعویض از نوار کناری یا `/workspaces`. مسیر تک‌فایل قدیمی (`project_dir`) یک‌بار به مدل چندپروژه‌ای مهاجرت می‌کند. |
| پوشهٔ موقت PiCode | داخل هر پروژه: `<root>/.picode/` (زیرپوشه‌های `tmp/` و `scratch/` + ایندکس محلی). **با سورس کاربر مخلوط نمی‌شود**؛ ایندکس ریپو `.picode` را نادیده می‌گیرد. |
| پاک‌کردن | `/clear` صفحه؛ `/clean` صفحه + تاریخچهٔ گفتگو (ویندوز: بریج UI واقعاً پنل را پاک می‌کند). |
| برند | فقط `PiCode` / `PiGPT` لاتین. |

### یک‌خطی

> روی ویندوز محصول نهایی = اپ پنجره‌ای حرفه‌ای با زبان رابط قابل تنظیم (پیش‌فرض فارسی)؛ روی مک/لینوکس = CLI با همان زبان رابط؛ یک هسته مشترک؛ چند پروژه؛ پوشهٔ موقت `.picode/`؛ فعالیت زنده مشترک؛ مسیر = تکمیل PySide6.

---

## ۲) هدف محصول

- کاربر ایرانی ویندوز بدون ترمینال سیاه: چت، ساخت/ویرایش فایل در پروژه (پیش‌فرض نوشتن = `permissions=auto`)، `@` پیوست فایل، `/` پالت دستور، ورود، مجوزها، زبان رابط، آپدیت، وضعیت زنده هنگام کار.
- چند پروژه با مسیر جدا؛ تعویض سریع؛ پایهٔ مدیریت پروژه‌های بزرگ (ریشهٔ workspace + ایندکس با ignore برای `.picode`).
- از گفتگو: ابزارهای `ssh_exec` (پروفایل‌های ذخیره در `~/.picode` با رمز یا کلید)، `web_search` و `fetch_url` با مجوز جدا (`remote` / `web`، پیش‌فرض `ask`). مدیریت اتصال: `/ssh` یا تنظیمات → اتصالات.
- چند گفتگو در هر پروژه (تب + فهرست کناری)، ماندگار در `<project>/.picode/chats/`.
- دیف درون‌خطی قبل از اعمال `write_file` / `/apply`؛ پیوست چندفایلی Composer (`@` + دکمهٔ پیوست).
- مصرف حساب از `/me` (+ اختیاری `/billing/wallet` و `/me/token-report`) و جمع توکن همان گفتگو در تنظیمات → مصرف.
- منطق کسب‌وکار در شل تکرار نمی‌شود — فقط `slash` / `file_tools` / `ssh_remote` / `web_tools` / `api_client` / `config` / `mentions` / `updates` / `i18n` / `activity`.
- توزیع: `https://pigpt.ir/downloads/picode/PiCode.exe` (+ `latest.json` / `/api/v1/cli/info`).

---

## ۳) غیرهدف‌ها

| غیرهدف | توضیح |
|--------|--------|
| برند دوم / نام فارسی محصول | فقط لاتین |
| Electron / Flutter به‌عنوان جایگزین | ممنوع مگر Owner پشته را عوض کند |
| بازنویسی هسته برای GUI | UI نازک روی هسته |
| اجبار کاربر ویندوز به ترمینال برای فارسی | ممنوع به‌عنوان مسیر اصلی |
| جایگزینی CLI روی مک/لینوکس | CLI آنجا سطح اصلی می‌ماند |
| قفل کروم فقط انگلیسی | منسوخ؛ پیش‌فرض fa با تنظیم en |
| `rsync --delete` روی SPA/landing | فقط کپی زیر `downloads/picode/` |
| کپی کامل Cursor (agent tree ابری، Composer ابری، Electron) | هدف «نزدیک‌تر» است نه برابری کامل — شکاف‌ها در §۸ |

---

## ۴) معماری

```
Windows end-user:
  PiCode.exe (PyInstaller, console=False)
      └── picode.desktop.main  ← UI حرفه‌ای + RTL/LTR بر اساس ui_language
              └── ReplSession + slash / do_chat / activity hook / i18n / updates

Mac/Linux end-user:
  picode (CLI REPL)  ← سطح محصول اصلی؛ همان i18n + activity
```

| ماژول | نقش |
|--------|-----|
| `picode/cli.py` | Typer / REPL ترمینال (مک/لینوکس + زیرساخت ویندوز) |
| `picode/desktop.py` | پنجرهٔ Qt — محصول هدف ویندوز |
| `picode/config_helpers.py` | workspaces، `project_dir`، `.picode/` temp |
| `picode/chat_store.py` | چند گفتگو زیر `.picode/chats/` |
| `picode/diff_view.py` | دیف یکپارچه + هوک پیش‌نمایش نوشتن |
| `picode/repo_index.py` | ایندکس محلی در `<project>/.picode/index.json`؛ ignore برای temp |
| `picode/i18n.py` | لایهٔ fa/en/tr/ar برای کروم CLI + دسکتاپ |
| `picode/activity.py` | رویداد وضعیت زنده (thinking/reading/writing/running/error) |
| `picode/slash.py` | دستورات `/` شامل `/language`، `/workspaces`، `/cost` |
| `picode/file_tools.py` / `files.py` | خواندن/نوشتن + گزارش فعالیت |
| `picode/mentions.py` | `@` |
| `picode/updates.py` | مقایسه با `/api/v1/cli/info`؛ برای exe → لینک `windows_exe` |
| `picode_window.py` + `PiCode.spec` | بسته‌بندی `PiCode.exe` |

---

## ۵) UX پنجره (۰٫۲٫۱۵)

| سطح | زبان / جهت |
|------|------------|
| عنوان، منوها، نوار ابزار، راهنما، مجوزها، تأیید، وضعیت زنده | مطابق `ui_language` (پیش‌فرض fa + RTL؛ ar + RTL؛ en/tr + LTR)؛ برند لاتین |
| نام دستورات `/` و مسیر فایل | لاتین / LTR |
| پاسخ دستیار | زبان پیام کاربر |

**چیدمان نزدیک‌تر به Cursor (در حد ممکن روی PySide6):**

- نوار کناری: پروژه‌ها + فهرست گفتگوهای محلی همان پروژه
- تب‌های چندگفتگو (ایجاد / بستن / تعویض)؛ ماندگار در `.picode/chats/`
- ناحیهٔ گفتگو + نوار فعالیت زنده
- Composer: ورودی چندخطی + پیوست چند فایل (`@` و دکمه) + سوییچر مدل
- دیالوگ دیف (unified / قبل / بعد) قبل از اعمال نوشتن فایل
- منوی **تنظیمات** یکپارچه با تب‌ها: مجوزها، زبان، SSH/وب، مصرف، درباره

**جعبهٔ پوشهٔ کار:** ریشهٔ پروژهٔ جاری؛ قابل ویرایش با تایپ مسیر + «اعمال» یا «انتخاب…». همهٔ `@`، خواندن و نوشتن از همان ریشه.

**پوشهٔ موقت هر پروژه:** `<project>/.picode/` — `tmp/` و `scratch/` و `chats/`؛ ایندکس در `.picode/index.json`. سورس کاربر آنجا نوشته نمی‌شود.

**مصرف:** تب تنظیمات → مصرف: `/api/v1/me` (+ در صورت وجود `/billing/wallet` و `/me/token-report`) + جمع توکن همان گفتگو و آخرین پاسخ.

**Pickerهای داخل‌اپ (ویندوز):**

| دستور | رفتار ویندوز |
|--------|----------------|
| `/help` ، `/` | پالت فیلترپذیر دستورها |
| `/models` ، `/model` | فقط نام مدل؛ بدون پیشوند نمایشی `arvan_` |
| `/permissions` | دیالوگ / تب مجوزها |
| `/settings` ، `/cost` | تنظیمات یکپارچه (مصرف برای `/cost`) |
| `/ssh` | دیالوگ اتصالات SSH |
| `/language` | دیالوگ / تب زبان |
| `/workspaces` | فهرست فضاهای کار و تعویض |

---

## ۶) زبان رابط (همهٔ پلتفرم‌ها)

| مورد | مقدار |
|------|--------|
| کلید config | `ui_language` در `~/.picode/config.json` |
| پیش‌فرض | `fa` (اگر کلید نباشد) |
| مقادیر | `fa` \| `en` \| `tr` \| `ar` |
| CLI | `/language` یا `/language fa\|en\|tr\|ar` |
| ویندوز | تنظیمات → زبان |
| دامنه | status، هشدار، help، کروم، confirms — نه زبان پاسخ مدل |

---

## ۷) بسته‌بندی و توزیع

- باینری: **`PiCode.exe`** فقط.
- URL: `https://pigpt.ir/downloads/picode/PiCode.exe`
- `latest.json`: `version`, `wheel`, `windows_exe`, `upgrade_windows` (pip/CLI), `upgrade_windows_exe` (راهنمای exe), `upgrade_unix`, `upgrade_cli`, `hub`
- `GET /api/v1/cli/info`: همان فیلدها را از `latest.json` تبلیغ می‌کند.
- Publish: `pigpt-mobile/deploy/publish_picode.sh` — wheel + در صورت وجود، کپی `PiCode.exe`؛ بدون wipe SPA/landing.
- مهمان `https://pigpt.ir/` = لندینگ بازاریابی (دست نزن).

---

## ۸) نسخه و شیپ

- نسخهٔ پنجره = `__version__` پکیج.
- شیپ کاربرمحور ویندوز → bump پچ + `changelog-picode` + آپلود exe واقعی قبل از ادعا در بلاگ.

### شکاف‌های صادقانه در برابر Cursor کامل (۰٫۲٫۱۵)

- بدون Electron؛ بدون agent tree ابری / همگام‌سازی cloud جلسات؛ فهرست گفتگوها **محلی** زیر `.picode/chats/` است.
- Composer چندفایلی = پیوست `@` / دکمه + حلقهٔ `write_file` چندمسیره؛ نه Composer ابری Cursor با review چندفایلی همزمان پیچیده.
- دیف گرافیکی = دیالوگ Qt (unified / قبل / بعد) قبل از اعمال — نه ادیتور دیف کناره‌به‌کنارهٔ داخل IDE.
- بدون همگام‌سازی cloud از workspace؛ فهرست پروژه‌ها محلی در `~/.picode/config.json` است.
- مصرف: هرچه `/me` و endpointهای اختیاری برگردانند + جمع محلی گفتگو؛ داشبورد صورتحساب چندروزهٔ وب ساخته نمی‌شود.
- احراز SSH با **رمز ذخیره‌شده در پروفایل** یا **مسیر کلید خصوصی** (+ passphrase اختیاری). پرامپت تعاملی رمز در هر دستور هنوز UX جدا ندارد.
- اجرای SSH از طریق **paramiko**؛ جستجوی وب کلاینت‌ساید + `fetch_url` با بلاک localhost/IP خصوصی — نه مرورگر کامل.

---

## ۹) فهرست فایل‌های کلیدی

| مسیر | نقش |
|------|-----|
| `picode_pkg/docs/PICODE_WINDOWS_PRODUCT.md` | این SoT |
| `picode_pkg/picode/desktop.py` | پنجره |
| `picode_pkg/picode/config_helpers.py` | پروژه‌ها + `.picode/` |
| `picode_pkg/picode/i18n.py` | زبان رابط |
| `picode_pkg/picode/activity.py` | فعالیت زنده |
| `picode_pkg/picode_window.py` | entry PyInstaller |
| `picode_pkg/PiCode.spec` | windowed build |
| `pigpt-mobile/deploy/publish_picode.sh` | انتشار downloads |
| Live: `/var/www/pigpt-spa/downloads/picode/` | مقصد آرتیفکت |

---

## ۱۰) اشاره از README

`picode_pkg/README.md` لینک به این فایل دارد و نصب ویندوز را به‌عنوان دانلود پنجره توصیف می‌کند.
