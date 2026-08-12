# مشخصات محصول و مهندسی — اپلیکیشن موبایل PiGPT (Flutter)

| فیلد | مقدار |
|------|--------|
| محصول | **PiGPT** — اپلیکیشن موبایل (Android + iOS) |
| دامنه API / وب | `https://pigpt.ir` |
| نسخه سند | `1.0.0` |
| تاریخ | ۱۴۰۴-۰۵-۲۱ / 2026-08-12 |
| وضعیت | تأیید دامنه توسط کاربر — **فقط مستندسازی** (بدون اسکفولد Flutter در این تسک) |
| مخاطب سند | محصول، طراحی UX، مهندسی موبایل، بک‌اند API |
| منبع تحقیق | SPA وب (`App.tsx` / `nav.ts` / صفحات app)، APIهای `/api/v1/*`، Brand Bible، Auth/Billing/Agent/Quick-Start |

---

## ۱. اهداف و غیر اهداف

### ۱.۱ اهداف (In scope)

1. ارائهٔ **تمام قابلیت‌های کاربرمحور وب** `pigpt.ir` روی موبایل، با UX بومی موبایل، انیمیشن نرم، و گرافیک باکیفیت (دارک پولیش شبیه Cursor در جاهای مرتبط، بدون تقلید کور دسکتاپ).
2. همگام‌سازی کامل با API موجود: گفتگو (استریم SSE)، حالت ایجنت در گفتگو، ماموریت‌های ایجنت (در صورت استقرار API)، شروع سریع، استودیوهای کاربر، کیف‌توکن / سقف روزانه، پلن‌ها، مدل‌ها، تنظیمات، پشتیبانی، ارجاع، مصرف، پروفایل، برند About.
3. **PiCode**: فقط صفحهٔ راهنما / دستور نصب (معادل وب `/app/cli`) — بدون جاسازی CLI یا ترمینال.
4. احراز هویت هم‌تراز وب: ایمیل/رمز، تأیید ایمیل، گوگل (اگر در سرور فعال باشد)؛ OTP تلفن فقط در صورت فعال‌سازی مجدد سرور.
5. RTL فارسی پیش‌فرض، تم دارک پیش‌فرض، هویت برند PiGPT (نه نام vendor مدل).

### ۱.۲ غیر اهداف (Out of scope)

| مورد | دلیل |
|------|------|
| کل مسیر `/admin/**` و APIهای `/api/v1/admin/**` | ادمین فقط وب |
| اجرای runtime کامل PiCode / ترمینال / VS Code extension داخل اپ | تأیید کاربر: فقط guide |
| وب‌ویو کامل SPA به‌عنوان «اپ» | محصول باید بومی Flutter باشد |
| مدیریت کلیدها، اقتصاد توکن ادمین، feature flags ادمین، صف jobs ادمین | وب‌ادمین |
| Push اعلان در MVP | فعلاً روی وب نیست → فاز بعد (بخش ۱۲) |
| تغییر قرارداد شکنندهٔ API بدون هماهنگی بک‌اند | اپ کلاینت است |
| پرداخت داخل‌اپ استور (IAP) در MVP | همان جریان زرین‌پال/درگاه وب؛ بازبینی حقوقی استور در فاز بعد |

---

## ۲. مخاطب و ارزش

### ۲.۱ مخاطب

| بخش | نیاز |
|-----|------|
| کاربر فارسی‌زبان روزمره | چت سریع، شروع سریع، شارژ توکن، مدل دلخواه روی موبایل |
| تولیدکننده محتوا / کسب‌وکار کوچک | استودیو تصویر/نوشتن/رسانه بدون لپ‌تاپ |
| توسعه‌دهنده | راهنمای نصب PiCode روی دسکتاپ از داخل اپ |
| کاربر رایگان | دیدن سقف روزانه و موجودی بدون سردرگمی |

### ۲.۲ ارزش پیشنهادی

- **همان حساب وب** روی گوشی با تجربهٔ لمسی عالی.
- پاسخ استریم‌شدهٔ روان، انتخاب مدل، حالت گفتگو/ایجنت.
- دسترسی به استودیوها و شروع سریع بدون اتکا به مرورگر موبایل SPA.
- شفافیت کیف‌توکن و سقف روزانه (Asia/Tehran).

### ۲.۳ معیارهای موفقیت محصول (سطح بالا)

| KPI | هدف اولیه (۳ ماه پس از انتشار) |
|-----|--------------------------------|
| نرخ تکمیل ورود (login → اولین پیام) | ≥ ۷۰٪ |
| crash-free sessions | ≥ ۹۹٫۵٪ |
| زمان تا اولین توکن استریم | P50 < ۱٫۵s روی شبکهٔ خوب |
| هم‌ترازی feature با وب کاربر | ۱۰۰٪ مسیرهای consumer تأییدشده در ماتریس بخش ۵ |

---

## ۳. اصول UX / UI و Motion

### ۳.۱ اصول طراحی

1. **موبایل‌نیتیو اول**: Bottom navigation برای محورهای اصلی؛ نه سایدبار دسکتاپ.
2. **دارک پیش‌فرض** (`theme: dark`) مطابق وب (`DEFAULT_THEME = dark`)؛ پشتیبانی light و system.
3. **RTL فارسی** پیش‌فرض (`ui_locale: fa`)؛ LTR فقط برای کد، URL، ایمیل، دستور نصب.
4. **یک ترکیب بصری در هر صفحهٔ اصلی**: برند/عنوان واضح، یک CTA اصلی، بدون داشبورد شلوغ.
5. **بدون کارت تزئینی بی‌هدف**؛ کارت فقط وقتی تعامل یا انتخاب واقعی است.
6. **برند اول**: نام **PiGPT** در splash و هدر چت؛ متای پاسخ: `PiGPT · قدرت‌گرفته از {model}`.
7. رنگ برند از توکن‌های وب (`--brand`, `--brand-soft`, پس‌زمینهٔ عمیق دارک) — از پالت بنفش کلیشه‌ای AI دوری کنید مگر اینکه توکن برند وب صریحاً آن باشد.

### ۳.۲ سیستم Motion (الزام کیفیت)

| الگو | کاربرد | مشخصات پیشنهادی |
|------|--------|------------------|
| Shared element / Hero | آواتار مدل، ورود به گفتگو | 280–350ms, easeOutCubic |
| Stagger list | لیست گفتگوها، کارت‌های شروع سریع، استودیوها | 30–50ms فاصله |
| Streaming caret / fade-in | توکن‌های پاسخ | opacity + subtle slide 8–12px |
| Sheet spring | تنظیمات، انتخاب مدل، منوی پروفایل | damping متوسط، بدون bounce اغراق‌آمیز |
| Page transition | push/pop با Directionality RTL | Cupertino یا custom slide از راست |
| Micro | دکمهٔ ارسال، toggle حالت چت/ایجنت | scale 0.96 → 1.0، 120ms |
| Skeleton shimmer | لود اولیه لیست‌ها | هماهنگ با دارک تم |
| Haptics | ارسال پیام، کپی، خطای محدود | light / medium بر اساس پلتفرم |

حداقل **۲–۳ موشن عمدی** در هر سطح اصلی (چت، شروع سریع، استودیو hub) الزامی است.

### ۳.۳ تایپوگرافی و گرافیک

- فونت فارسی خوانا و اختصاصی (مثلاً Vazirmatn / IRANYekanX — نهایی در kickoff)؛ نه Inter/Roboto به‌عنوان display.
- کد و monospaces برای بلوک کد در پاسخ‌ها.
- لوگو: mark `π` + PNG برند وب (`brand-pi.png`)؛ splash کوتاه با fade.

### ۳.۴ دسترس‌پذیری

- کنتراست WCAG AA روی دارک.
- اندازهٔ هدف لمسی ≥ ۴۴pt.
- VoiceOver / TalkBack روی کنترل‌های چت و ارسال.
- کاهش حرکت: احترام به `disable animations` سیستم.

---

## ۴. نقشه اطلاعات (IA) و صفحات

### ۴.۱ ناوبری اصلی (Bottom Nav)

معادل `consumerNav` وب + دسترسی سریع به حساب:

| تب | مسیر اپ | معادل وب | توضیح |
|----|---------|----------|--------|
| گفتگو | `/chat` | `/app`, `/app/c/:id` | لیست + نخ فعال؛ حالت chat/agent |
| شروع سریع | `/quick-start` | `/app/quick-start` | کارت‌ها و ویزارد |
| استودیوها | `/studios` | `/app/studios` + ابزارها | هاب + ورود به هر استودیو |
| حساب | `/account` | ProfileMenu + settings/plans/... | کیف، پلن، مدل‌ها، تنظیمات، PiCode guide، پشتیبانی |

جستجوی سراسری (معادل Ctrl+K) در فاز ۲ به‌صورت Search sheet.

### ۴.۲ درخت صفحات (شامل)

| ID | صفحه | مسیر پیشنهادی Deep Link | توضیح عملکردی |
|----|------|-------------------------|----------------|
| A1 | Splash / Bootstrap | — | خواندن توکن امن، `/api/v1/me`، تم |
| A2 | ورود | `/auth` | ایمیل/رمز؛ گوگل؛ لینک تأیید |
| A3 | ثبت‌نام | `/auth?mode=register` | + نمایش‌نام و تلفن اختیاری |
| A4 | تأیید ایمیل | `/auth/verify` | deep link از ایمیل |
| A5 | OAuth Callback | `/auth/callback` | custom scheme / App Links |
| C1 | لیست گفتگوها | `/app` | جستجو، بایگانی، جدید |
| C2 | نخ گفتگو | `/app/c/:id` | استریم، آپلود، مدل، share، regenerate، edit |
| C3 | مرور مدل‌ها | `/app/models` | شروع گفتگو با مدل انتخابی |
| Q1 | هاب شروع سریع | `/app/quick-start` | کارت‌ها + تاریخچه |
| Q2 | ویزارد کارت | `/app/quick-start/:cardId` | فیلدها، quality، خروجی |
| AG1 | ایجنت ماموریت‌ها | `/app/agent` | لیست + ایجاد هدف (اگر API زنده باشد) |
| AG2 | جزئیات ماموریت | `/app/agent/:id` | steps، confirm، tools |
| S0 | هاب استودیو | `/app/studios` | دسته‌ها + router پیشنهاد |
| S1 | گالری خروجی | `/app/studios/gallery` | |
| S2 | تصویر | `/app/image` | presets، generate، batch، edit، brand-kit |
| S3 | نوشتن | `/app/writing` | templates، run stream، SEO، export |
| S4 | اسناد/RAG | `/app/documents` | آپلود و پرسش |
| S5 | رسانه | `/app/media` | OCR، TTS، STT، edit |
| S6 | الگوریتم‌ها | `/app/algorithms` | wizard، pipeline |
| S7 | داده و گزارش | `/app/analytics` | CSV analyze |
| S8 | کدنویسی | `/app/coding` | review، scaffold |
| S9 | اتوماسیون | `/app/automation` | workflow سطح کاربر |
| S10 | کسب‌وکار ایران | `/app/biz` | invoice/support/report |
| S11 | دستیار پروژه‌ای | `/app/assistant` | projects، multi-agent |
| S12 | آموزش | `/app/edu` | quiz، interview |
| S13 | ایمنی و رشد | `/app/growth` | filter، A/B، marketplace کاربر |
| S14 | فضای کاری سازمان | `/app/workspace` | team (سطح کاربر) |
| P1 | تنظیمات | sheet یا `/app/settings` | تم، زبان، لحن، مدل‌های من، حریم |
| P2 | پلن و کیف | `/app/plans` | plans، packages، wallet، daily cap |
| P3 | مصرف | `/app/usage` | خلاصه مصرف کاربر |
| P4 | ارجاع | `/app/referral` | |
| P5 | پشتیبانی / تیکت | `/app/support` | تیکت کاربر (نه ادمین) |
| P6 | راهنمای PiCode | `/app/cli` | نصب + کپی دستور؛ اختیاری confirm کد دستگاه |
| P7 | تأیید دستگاه CLI | `/app/cli/authorize` | deep link از `picode login` |
| P8 | درباره / برند | `/about` | هویت PiGPT، لینک وب |
| X1 | اشتراک عمومی | `/share/:token` | فقط‌خواندنی در صورت نیاز |

### ۴.۳ اسکچ IA

```text
[Auth]
   └─► [Main Shell]
         ├─ Chat ──► Conversation (mode: chat|agent)
         ├─ Quick Start ──► Wizard ──► Result
         ├─ Studios Hub ──► Studio_* pages
         └─ Account
               ├─ Wallet / Plans / Usage
               ├─ My Models / Settings
               ├─ Support / Referral
               ├─ PiCode Guide (+ Authorize)
               └─ About / Logout
```

---

## ۵. ماتریس ویژگی وب ↔ موبایل

### ۵.۱ محورهای consumer

| ویژگی وب | مسیر وب | موبایل | فاز | یادداشت |
|----------|---------|--------|-----|---------|
| گفتگو + استریم | `/app`, `/app/c/:id` | شامل | MVP | SSE اجباری |
| حالت Chat/Agent در چت | `ChatModeToggle` + `mode` | شامل | MVP | همان body استریم |
| ماموریت‌های ایجنت | `/app/agent*` + `/api/v1/agent/*` | شامل | فاز ۱٫۵ | اگر روی prod نیست: feature-flag تا فعال شدن API |
| شروع سریع | `/app/quick-start` | شامل | MVP | |
| استودیو هاب + همهٔ ابزارهای کاربر | `/app/studios`, `/app/*` | شامل | فاز ۱–۲ | MVP: image + writing؛ بقیه کامل‌سازی |
| گالری | `/app/studios/gallery` | شامل | فاز ۲ | |
| مدل‌ها | `/app/models` | شامل | MVP | |
| تنظیمات / مدل‌های من | SettingsModal | شامل | MVP | به‌صورت صفحه/شیت موبایل |
| پلن + پکیج توکن + کیف | `/app/plans` | شامل | MVP | پرداخت: مرورگر خارجی/Custom Tabs |
| مصرف | `/app/usage` | شامل | فاز ۱ | |
| ارجاع | `/app/referral` | شامل | فاز ۲ | |
| پشتیبانی کاربر | `/app/support` | شامل | فاز ۱ | |
| PiCode guide | `/app/cli` | شامل | فاز ۱ | فقط راهنما |
| CLI authorize | `/app/cli/authorize` | شامل | فاز ۱ | deep link |
| Share عمومی | `/share/:token` | شامل | فاز ۲ | |
| Command Palette | Ctrl+K | معادل Search | فاز ۲ | |
| Focus/dense shell | AppShell | اختیاری | فاز ۳ | اولویت پایین موبایل |
| Admin * | `/admin/**` | **مستثنی** | — | |
| PiCode runtime | CLI | **مستثنی** | — | |

### ۵.۲ استودیوها (capability codes از `nav.ts`)

| استودیو | capability | موبایل |
|---------|------------|--------|
| تصویر | `image_studio` | شامل |
| نوشتن | `writing_studio` | شامل |
| اسناد | `document_rag` | شامل |
| الگوریتم‌ها | `algorithms_studio` | شامل (secondary) |
| رسانه | `media_studio` | شامل |
| داده و گزارش | `analytics_studio` | شامل |
| کدنویسی | `coding_studio` | شامل (UI ساده‌تر از Monaco وب) |
| اتوماسیون | `automation_studio` | شامل |
| کسب‌وکار | `biz_studio` | شامل |
| دستیار پروژه‌ای | `assistant_studio` | شامل |
| آموزش | `edu_studio` | شامل |
| ایمنی و رشد | `growth_studio` | شامل |
| فضای کاری | `workspace_studio` | شامل |

اگر capability از سرور خاموش باشد، کارت را غیرفعال/مخفی کنید (همان رفتار وب).

---

## ۶. معماری Flutter

### ۶.۱ لایه‌ها (پیشنهاد قطعی برای kickoff)

```text
presentation/     # screens, widgets, themes, motion
application/      # Riverpod notifiers / controllers, use-cases
domain/           # entities, repository interfaces, failures
data/             # DTOs, API clients, SSE parser, secure storage, local cache
core/             # routing, di, logging, constants, brand
```

### ۶.۲ State management

**پیشنهاد اصلی: Riverpod 2.x** (+ `riverpod_annotation` اختیاری)

| دلیل | توضیح |
|------|--------|
| تست‌پذیری | override در widget/integration tests |
| مناسب استریم | `AsyncNotifier` / `StreamProvider` برای SSE و wallet refresh |
| مقیاس | جداسازی chat session، studios، auth بدون God-object |

جایگزین قابل قبول تیمی: Bloc — فقط اگر تیم از قبل استاندارد Bloc دارد. از GetX اجتناب شود.

### ۶.۳ Networking

| جزء | انتخاب |
|-----|--------|
| HTTP JSON | `dio` یا `http` + interceptor Bearer |
| Base URL | `https://pigpt.ir` (قابل override برای staging) |
| SSE / استریم چت | `POST` + خواندن `text/event-stream` (همان `runStream`/`readSse` وب)؛ کتابخانهٔ کمکی یا parser اختصاصی |
| آپلود | `multipart` به `/api/v1/uploads` |
| خطا | نگاشت `detail` فارسی؛ پیام دوستانهٔ برند (نه raw provider) |
| Timeout | connect 15s؛ دریافت استریم بدون timeout کوتاه سخت |

الگوی استریم چت (قرارداد رفتاری):

1. `POST /api/v1/conversations/{id}/messages` با `Authorization: Bearer …`
2. خواندن تدریجی SSE → به‌روزرسانی بافر assistant
3. رویداد خطا → `error_fa` روی پیام
4. در پایان → refresh `/api/v1/me` (کیف/سقف) و لیست گفتگوها
5. پشتیبانی `Abort` / لغو کاربر

### ۶.۴ Auth storage امن

| پلتفرم | محل توکن |
|--------|----------|
| کلید | هم‌تراز وب: مفهومی `pigpt_v2_token` |
| Android | EncryptedSharedPreferences / flutter_secure_storage (Keystore) |
| iOS | Keychain |
| ممنوع | SharedPreferences明文، لاگ توکن، کرش‌ریپورت خام توکن |

پس از 401/403: پاک‌سازی توکن و هدایت به Auth.

### ۶.۵ کش و آفلاین

| داده | استراتژی |
|------|----------|
| لیست گفتگوها / پیش‌نویس پیام | کش محلی (Drift یا hive_ce) + stale-while-revalidate |
| پیام‌های نخ | کش آخرین N نخ؛ منبع حقیقت سرور |
| کارت‌های quick-start | کش ۲۴ساعته |
| مدل‌ها و prefs | کش تا logout یا invalidate |

آفلاین کامل تولید AI **نیست**؛ فقط خواندن کش و صف ارسال محدود (فاز ۳).

### ۶.۶ ساختار پکیج پیشنهادی

```text
lib/
  main.dart
  app.dart
  core/
  features/
    auth/
    chat/
    agent/
    quick_start/
    studios/
    billing/
    account/
    picode_guide/
  shared/
```

### ۶.۷ کیفیت مهندسی

- `flutter_lints` سخت؛ CI: analyze + test + build apk/ipa smoke
- طلایی: golden برای Chat bubble و QuickStart card در دارک
- نسخه‌گذاری اپ: SemVer؛ header اختیاری `X-PiGPT-Client: flutter/{version}`

---

## ۷. قرارداد API (گروه‌بندی‌شده)

**Base:** `https://pigpt.ir`  
**Prefix نسخه:** `/api/v1`  
**Auth header:** `Authorization: Bearer <access_token>`

> این فهرست از کلاینت/روترهای واقعی وب استخراج شده است. فیلدهای دقیق schema در OpenAPI سرور مرجع نهایی‌اند؛ اپ نباید مسیر ادمین را صدا بزند.

### ۷.۱ Auth

| Method | Path | کاربرد |
|--------|------|--------|
| GET | `/api/v1/auth/methods` | `{ google?: bool }` (و فلگ‌های دیگر در صورت وجود) |
| POST | `/api/v1/auth/login` | ایمیل/رمز → `access_token` |
| POST | `/api/v1/auth/register` | ثبت‌نام + ایمیل تأیید |
| POST | `/api/v1/auth/resend-verification` | ارسال مجدد |
| POST | `/api/v1/auth/verify-email` | تأیید با token |
| GET | `/api/v1/auth/google/start` | شروع OAuth (موبایل: Custom Tabs + redirect به app link) |
| GET | `/api/v1/auth/google/callback` | سرور وب |
| POST | `/api/v1/auth/otp/request` | **فعلی: احتمالاً 410 Disabled** |
| POST | `/api/v1/auth/otp/verify` | **فعلی: احتمالاً 410 Disabled** |
| POST | `/api/v1/auth/cli/device` | device flow (از CLI) |
| POST | `/api/v1/auth/cli/device/poll` | |
| POST | `/api/v1/auth/cli/device/confirm` | تأیید کد از اپ/وب |
| GET | `/api/v1/auth/cli/session` | |
| POST | `/api/v1/auth/cli/token` | |

### ۷.۲ Me / Settings / Prefs

| Method | Path | کاربرد |
|--------|------|--------|
| GET/PATCH | `/api/v1/me` | پروفایل + wallet خلاصه |
| GET/PATCH | `/api/v1/me/settings` | theme، ui_locale، tone، memories، speech، … |
| GET/PUT | `/api/v1/me/model-prefs` | مدل‌های فعال کاربر + پیش‌فرض |
| POST | `/api/v1/me/logout-all` | |
| GET | `/api/v1/me/export` | خروجی دادهٔ کاربر |

فیلدهای مهم wallet در `me` (نمونهٔ وب):

- `balance`, `can_generate`
- `free_remaining`, `free_daily_remaining`, `free_daily_cap`
- `daily_token_limit`, `daily_tokens_used`, `daily_tokens_remaining`

### ۷.۳ Models & Chat

| Method | Path | کاربرد |
|--------|------|--------|
| GET | `/api/v1/models` | کاتالوگ مدل |
| GET | `/api/v1/chat/templates` | قالب‌های چت |
| GET | `/api/v1/conversations` | `?archived_only=true` |
| GET | `/api/v1/conversations/search` | |
| POST | `/api/v1/conversations` | `{ model_id, title }` |
| GET/PATCH | `/api/v1/conversations/{id}` | پیام‌ها + meta |
| DELETE | `/api/v1/conversations` | حذف همه (تنظیمات) |
| POST | `/api/v1/conversations/archive-all` | |
| POST | `/api/v1/conversations/{id}/messages` | **SSE stream**؛ body شامل `content`, `mode?: "chat"|"agent"`, … |
| POST | `/api/v1/conversations/{id}/regenerate` | SSE؛ `mode` |
| POST | `/api/v1/conversations/{id}/messages/{messageId}/edit` | SSE |
| POST | `/api/v1/conversations/{id}/share` | لینک عمومی |
| POST | `/api/v1/conversations/{id}/organize` | |
| POST | `/api/v1/message-drafts` | پیش‌نویس |
| POST | `/api/v1/uploads` | فایل |

### ۷.۴ Agent missions

| Method | Path | کاربرد |
|--------|------|--------|
| GET/POST | `/api/v1/agent/missions` | لیست / ایجاد `{ goal, model_id?, confirm_sensitive }` |
| GET/PATCH | `/api/v1/agent/missions/{id}` | |
| POST | `/api/v1/agent/missions/{id}/next` | اجرای قدم بعد |
| POST | `/api/v1/agent/missions/{id}/complete` | |
| POST | `/api/v1/agent/missions/{id}/confirm` | تأیید اقدام حساس |
| POST | `/api/v1/agent/missions/{id}/tools/file` | |
| POST | `/api/v1/agent/missions/{id}/tools/image` | |
| POST | `/api/v1/agent/missions/{id}/tools/quick-start` | |

وضعیت‌های UI: `draft`, `planning`, `running`, `awaiting_confirm`, `completed`, `failed`, `cancelled`.

### ۷.۵ Quick Start

| Method | Path | کاربرد |
|--------|------|--------|
| GET | `/api/v1/quick-start/cards` | + `quality_options` |
| GET | `/api/v1/quick-start/cards/{cardId}` | + follow_ups |
| GET | `/api/v1/quick-start/history` | |
| POST | `/api/v1/quick-start/run` | `{ card_id, fields, quality, follow_up?, previous_text? }` |
| GET | `/api/v1/quick-start/jobs/{jobId}` | polling وضعیت |

### ۷.۶ Billing / Wallet (کاربر)

| Method | Path | کاربرد |
|--------|------|--------|
| GET | `/api/v1/billing/plans` | پلن‌ها + `current_plan_id` + `gateway` |
| GET | `/api/v1/billing/plans/compare` | |
| GET | `/api/v1/billing/token-packages` | |
| GET | `/api/v1/billing/wallet` | موجودی و سقف روزانه |
| GET | `/api/v1/billing/token-ledger` | |
| POST | `/api/v1/billing/payments` | → `redirect_url` (باز کردن در مرورگر) |
| GET | `/api/v1/billing/payments/me` | |
| GET | `/api/v1/billing/callback` | سمت سرور/وب |
| GET | `/api/v1/billing/payments/{id}/invoice.pdf` | |

### ۷.۷ Studios / Pro (کاربر — نمونهٔ کلیدی)

| حوزه | Paths نمونه |
|------|-------------|
| Router هاب | `POST /api/v1/pro/router` |
| تصویر | `/api/v1/studios/image/presets`, `/jobs`, `/generate`؛ `/api/v1/pro/image/batch`, `/edit`؛ `/api/v1/pro/brand-kit` |
| نوشتن | `/api/v1/studios/writing/templates`, `/run`؛ `/api/v1/pro/writing/seo|diff|export` |
| کیفیت | `POST /api/v1/pro/quality-gate` |
| رسانه | `/api/v1/studios/media/{image-edit,ocr,tts,stt,flags}` |
| الگوریتم | `/api/v1/studios/algorithms/*` |
| دستیار | `/api/v1/studios/assistant/*` |
| داده | `POST /api/v1/studios/data/analyze-csv` |
| کد | `/api/v1/studios/coding/{review,scaffold,openapi-mock}` |
| آموزش | `/api/v1/studios/edu/{quiz,interview}` |
| کسب‌وکار | `/api/v1/studios/biz/*` |
| گالری/اشتراک | `/api/v1/studios/gallery`, `/share`, `/ratings`, `/templates/*` |
| ایمنی/تیم/مارکت | `/api/v1/studios/safety/*`, `/team`, `/marketplace` |
| Assets | `/api/v1/assets/{id}` |

### ۷.۸ صریحاً ممنوع در اپ موبایل

همهٔ `/api/v1/admin/**` (users, plans, credentials, models admin, token-economy admin, tickets admin, …).

---

## ۸. برند PiGPT

منبع: `BRAND_BIBLE.md` + `brand.ts` + `pigpt_identity` / `brand_policy_v1`.

| عنصر | مقدار |
|------|--------|
| نام نمایش | PiGPT |
| نام فنی وب | pigpt |
| CLI خواهر | PiCode (`picode`) — فقط راهنما در اپ |
| تگ‌لاین FA | پلتفرم هوش مصنوعی فارسی |
| Logo mark | `π` |
| هویت پاسخ | «PiGPT، قدرت‌گرفته از {model}» |
| Loading | `PiGPT در حال نوشتن…` / معادل ایجنت و شروع سریع |
| خروجی آماده | `آماده‌شده با PiGPT` |

**باید:** برند محصول اول باشد؛ vendor مدل فقط به‌عنوان موتور.  
**نباید:** ادعای ChatGPT/Claude/Gemini بودن محصول؛ نشت خطای خام provider؛ نمایش مسیر ادمین.

صفحهٔ About: مأموریت کوتاه، لینک `https://pigpt.ir`، نسخهٔ اپ، سیاست حریم (لینک وب).

---

## ۹. احراز هویت

### ۹.۱ روش‌های وبِ تأییدشده

| روش | وضعیت وب | الزام موبایل |
|-----|----------|--------------|
| ایمیل + رمز | فعال | MVP |
| تأیید ایمیل | اجباری قبل از استفادهٔ کامل | MVP + deep link |
| Google OAuth | وابسته به env (`GOOGLE_CLIENT_*`)؛ `auth/methods.google` | پیاده‌سازی شرطی |
| OTP پیامک | endpointها موجود؛ UI وب غیرفعال (HTTP 410) | UI مخفی تا سرور فعال کند |
| تلفن | فیلد اختیاری پروفایل | تنظیمات پروفایل |

### ۹.۲ جریان موبایل

```text
Splash → secure token?
   ├─ no  → Auth (login/register)
   └─ yes → GET /me
              ├─ 401 → Auth
              ├─ email_verified=false → پیام تأیید + resend
              └─ ok → Main
```

Google روی موبایل:

1. باز کردن `https://pigpt.ir/api/v1/auth/google/start?next=...` در Custom Tab / ASWebAuthenticationSession  
2. Redirect به App Link / Universal Link (`https://pigpt.ir/auth/callback` یا scheme `pigpt://auth/callback`)  
3. ذخیرهٔ `access_token` در secure storage  

> نکتهٔ باز: ممکن است بک‌اند نیاز به Client ID از نوع iOS/Android جدا یا deep link whitelist داشته باشد — در kickoff با بک‌اند قطعی شود.

---

## ۱۰. قابلیت‌های کلیدی محصول (جزئیات)

### ۱۰.۱ گفتگو

- لیست گفتگو، جستجو، بایگانی، پین/سازمان‌دهی در حد API.
- Composer: متن، آپلود، ارسال، توقف استریم.
- `ChatModeToggle`: **گفتگو | ایجنت** → ارسال `mode` در messages/regenerate/edit.
- Model switcher از prefs کاربر + کاتالوگ.
- Markdown رندر، کد با کپی، متای برند زیر هر پاسخ assistant.
- Share لینک؛ regenerate؛ edit پیام کاربر.
- قالب‌ها (`/chat/templates`) و starter prompts در empty state.
- نمایش موجودی/سقف در هدر یا بنر وقتی `can_generate=false`.

### ۱۰.۲ ایجنت

**دو سطح (هر دو در دامنهٔ موبایل):**

1. **حالت ایجنت داخل چت** (مستقر در SPA فعلی) — MVP.
2. **ماموریت‌محور** (`/app/agent`, API missions) — هدف، فرض‌ها، قدم‌ها، تایم‌لاین، تأیید ابزار حساس، ابزار file/image/quick-start — فاز ۱٫۵ با feature flag.

تمایز UX: «ایجنت = یک هدف تا تکمیل · گفتگو = پرسش‌وپاسخ آزاد».

### ۱۰.۳ شروع سریع

- هاب کارت‌ها (`kind: text|image`)، ویزارد چندمرحله‌ای، `quality: fast|…`.
- اجرای job + polling؛ کپی/دانلود خروجی؛ follow-ups؛ تاریخچه.
- انیمیشن پیشرفت نرم و empty state برنددار.

### ۱۰.۴ استودیوها (فقط کاربر)

- هاب دسته‌بندی‌شده عین وب: تولید محتوا، رسانه، داده و کد، کسب‌وکار.
- پیشنهاد مسیر از `POST /api/v1/pro/router`.
- هر استودیو: فرم ورودی → job/stream → خروجی + ذخیره در گالری در صورت پشتیبانی API.
- کدنویسی موبایل: ویرایشگر سبک (نه الزام Monaco کامل).

### ۱۰.۵ کیف‌توکن و سقف روزانه

نمایش الزامی در Account و بنر چت:

| فیلد | معنی |
|------|------|
| `balance` | موجودی توکن پلتفرم |
| `free_daily_remaining` / `free_daily_cap` | باقیمانده/سقف روزانهٔ رایگان (تقویم Asia/Tehran) |
| `daily_tokens_remaining` | سقف روزانهٔ مؤثر پلن/کاربر |
| `can_generate` | آیا مجاز به تولید هست |

CTA شارژ → Plans؛ اگر درگاه `inactive` → پیام هدایت به پشتیبانی (رفتار وب).

### ۱۰.۶ تنظیمات و مدل‌های من

تب‌های معادل SettingsModal وب (موبایل به‌صورت لیست بخش‌ها):

- عمومی: تم، زبان UI، Enter-to-send (روی موبایل معنای متفاوت؛ ترجیح دکمهٔ ارسال)
- لحن / memories
- مدل‌های من (حداقل یک مدل فعال)
- مدل پیش‌فرض
- گفتار (اگر OS پشتیبانی کند)
- داده: بایگانی همه، حذف گفتگوها، export، logout-all، حذف حساب در حد API

---

## ۱۱. صفحهٔ راهنمای PiCode (فقط Guide)

معادل `/app/cli` — **نصب و آموزش، نه runtime**.

محتوای الزامی:

| بلوک | محتوا |
|------|--------|
| معرفی | PiCode چیست؛ API پیش‌فرض `https://pigpt.ir` |
| نصب Unix | `curl -fsSL https://pigpt.ir/install-picode.sh \| bash` + دکمه کپی |
| نصب Windows | `irm https://pigpt.ir/install-picode.ps1 \| iex` + جایگزین ExecutionPolicy |
| لینک دانلود | `https://pigpt.ir/downloads/picode/` |
| ورود CLI | `picode login` (مرورگر) |
| اختیاری | فرم تأیید `user_code` → `POST /api/v1/auth/cli/device/confirm` |
| Authorize | صفحهٔ `/app/cli/authorize` برای deep link دستگاه |

ممنوع: WebView ترمینال، SSH، اجرای shell روی دستگاه موبایل برای PiCode، بسته‌بندی باینری CLI داخل اپ.

---

## ۱۲. Push / Notification

| وضعیت | توضیح |
|-------|--------|
| وب فعلی | بدون push بومی تأییدشده در دامنهٔ تحقیق |
| MVP موبایل | **بدون** FCM/APNs اجباری |
| فاز بعد | اعلان اتمام job استودیو / تیکت پشتیبانی / اتمام ماموریت ایجنت |

تا فاز بعد: polling محلی هنگام foreground برای jobs کافی است.

---

## ۱۳. امنیت، Deep Link، نسخه API

### ۱۳.۱ امنیت

- TLS فقط به `pigpt.ir`؛ certificate pinning اختیاری فاز ۳.
- توکن فقط Secure Storage؛ پاک‌سازی در logout و logout-all.
- عدم ذخیرهٔ رمز عبور.
- مخفی‌سازی کامل UI/route ادمین حتی اگر `role=admin` (ادمین از وب استفاده کند).
- محدود کردن reverse-engineering سطحی: بدون secrets در باینری؛ فقط public client config.
- آپلود: محدودیت نوع/حجم هم‌تراز سرور؛ نمایش خطا فارسی.
- پرداخت فقط از طریق `redirect_url` رسمی API.

### ۱۳.۲ Deep Link / App Links

| لینک | رفتار اپ |
|------|----------|
| `https://pigpt.ir/app/c/:id` | باز کردن نخ |
| `https://pigpt.ir/app/quick-start/:cardId` | ویزارد |
| `https://pigpt.ir/app/cli/authorize?...` | تأیید PiCode |
| `https://pigpt.ir/auth/verify?token=` | تأیید ایمیل |
| `https://pigpt.ir/share/:token` | پیش‌نمایش اشتراک |
| `pigpt://...` | scheme پشتیبان در صورت نیاز OAuth |

Android App Links + iOS Universal Links باید در سرور `assetlinks.json` / `apple-app-site-association` پیکربندی شوند (کار بک‌اند/DevOps).

### ۱۳.۳ نسخه API

- کلاینت فقط `/api/v1`.
- سازگاری رو به جلو: فیلدهای ناشناخته ignore شوند.
- اگر سرور 426/410 برای قابلیت داد، UI آن بخش را خاموش کند.
- هدر پیشنهادی: `X-PiGPT-Client: flutter/x.y.z` و `Accept-Language: fa`.

---

## ۱۴. فازبندی تحویل و معیار پذیرش

### فاز ۰ — پایه (هفته ۰–۱)

| تحویل | معیار پذیرش |
|-------|-------------|
| اسکفولد Flutter، تم دارک RTL، Brand splash | بیلد Android+iOS بدون crash |
| Secure auth storage + login/register | ورود واقعی به `pigpt.ir` و `/me` |
| Shell با ۴ تب | ناوبری پایدار |

### فاز MVP — گفتگو + حساب ضروری (هفته ۲–۵)

| تحویل | معیار پذیرش |
|-------|-------------|
| لیست/نخ چت + SSE | استریم قابل لغو؛ متای برند؛ mode chat/agent |
| مدل‌ها و model-prefs | تغییر مدل و شروع گفتگو |
| Wallet/Plans نمایش + پرداخت در مرورگر | اعداد هم‌خوان با وب؛ redirect موفق |
| Settings حداقل (تم/زبان/مدل‌های من) | persist از طریق API |
| Empty states و motion پایه | چک‌لیست طراحی تأیید شود |

### فاز ۱ — شروع سریع + PiCode guide + پشتیبانی (هفته ۵–۸)

| تحویل | معیار پذیرش |
|-------|-------------|
| Quick Start کامل | اجرای حداقل ۲ کارت text و ۱ image |
| `/app/cli` guide | کپی دستور؛ authorize کد |
| Support صفحهٔ کاربر | ایجاد/لیست تیکت در حد API موجود |
| Usage | نمایش مصرف |

### فاز ۱٫۵ — ایجنت ماموریت

| تحویل | معیار پذیرش |
|-------|-------------|
| Missions UI + API | ایجاد، next، confirm، complete روی سرور واقعی |
| Feature flag اگر API نبود | عدم crash؛ پیام «به‌زودی» |

### فاز ۲ — استودیوها کامل + گالری + referral + share + search

| تحویل | معیار پذیرش |
|-------|-------------|
| همهٔ استودیوهای جدول ۵٫۲ | هر capability فعال روی سرور در اپ قابل استفاده است |
| Deep links اصلی | از ایمیل/مرورگر به اپ |
| Search سراسری | پیدا کردن گفتگو/استودیو |

### فاز ۳ — پرداخت استور (اختیاری)، push، pinning، آفلاین صف

معیار: سند جدا پس از تصمیم حقوقی/محصول.

---

## ۱۵. ریسک‌ها و تصمیم‌های باز

| # | ریسک / تصمیم | پیشنهاد |
|---|--------------|---------|
| R1 | Google OAuth موبایل نیاز به تنظیمات جدید Google Cloud دارد | kickoff با بک‌اند؛ تا آن زمان ایمیل کافی است |
| R2 | مسیر `/app/agent` ممکن است روی همهٔ deployها نباشد | detect با GET missions؛ flag |
| R3 | سیاست استور روی پرداخت خارجی | MVP: لینک به وب؛ بعداً IAP در صورت اجبار |
| R4 | استودیوی Coding بدون Monaco | ادیتور سبک + خروجی؛ پذیرش کیفیت پایین‌تر UI |
| R5 | OTP فعلاً 410 | مخفی در UI |
| R6 | هم‌گام نگه داشتن ماتریس با وب | قرارداد: هر PR وب consumer → بررسی موبایل |
| R7 | SSE روی برخی پروکسی‌های موبایل | تست ایران‌شبکه‌ها؛ fallback پیام خطا |
| R8 | محل deploy مستندات prod (`/opt/pigpt/docs`) | در زمان نوشتن این سند، SSH به host فعلی `virateam` مسیر `/opt/pigpt` نداشت؛ همگام‌سازی اختیاری روی سرور واقعی PiGPT |

تصمیم‌های باز برای kickoff:

1. State library نهایی: Riverpod (پیشنهاد) vs Bloc  
2. نام applicationId / bundleId  
3. آیا ادمین‌های با `role=admin` اصلاً اشاره به وب ادمین ببینند یا کاملاً مخفی  
4. اولویت استودیوها بعد از image/writing  
5. نیاز به staging base URL جدا

---

## ۱۶. چک‌لیست آمادگی شروع توسعه

### محصول / طراحی

- [ ] تأیید این سند توسط مالک محصول  
- [ ] توکن رنگ/فونت نهایی از Brand + export Figma/Token  
- [ ] فلوی Motion برای Chat و Quick Start مشخص شود  
- [ ] نسخهٔ متن‌های خالی (empty states) فارسی  

### بک‌اند / DevOps

- [ ] OpenAPI یا export مسیرهای `/api/v1` به‌روز  
- [ ] تأیید وضعیت Google OAuth و OTP  
- [ ] تأیید زنده بودن `/api/v1/agent/missions` روی prod  
- [ ] App Links فایل‌ها روی `pigpt.ir`  
- [ ] CORS/redirect برای scheme موبایل در صورت نیاز  
- [ ] Staging یا حساب تست با توکن  

### موبایل

- [ ] ایجاد ریپوی `pigpt-mobile` (Flutter 3.x پایدار)  
- [ ] CI: analyze, test, build  
- [ ] حساب‌های Apple Developer / Google Play  
- [ ] Privacy policy URL (لینک وب)  
- [ ] Sentry یا معادل (بدون PII/توکن)  

### حقوقی / استور

- [ ] متن مجوزها (میکروفون برای speech، عکس برای آپلود)  
- [ ] تصمیم پرداخت داخل‌اپ در برابر وب  

### این سند

- [x] ذخیره در `C:\MyServer\_pigpt_mobile\docs\PIGPT_FLUTTER_APP_SPEC.md`  
- [x] کپی در `C:\MyServer\pigpt-mobile\docs\PIGPT_FLUTTER_APP_SPEC.md`  
- [ ] کپی روی سرور prod `/opt/pigpt/docs/` وقتی SSH به میزبان PiGPT در دسترس است  

---

## پیوست A — مسیرهای وب consumer (مرجع)

```
/auth, /auth/verify, /auth/callback
/share/:token
/app
/app/c/:id
/app/settings
/app/models
/app/plans
/app/usage
/app/referral
/app/support
/app/quick-start
/app/quick-start/:cardId
/app/studios
/app/studios/gallery
/app/image, /app/writing, /app/documents, /app/media
/app/algorithms, /app/analytics, /app/coding, /app/automation
/app/biz, /app/assistant, /app/edu, /app/growth, /app/workspace
/app/cli, /app/cli/authorize
(+ /app/agent, /app/agent/:id وقتی در روت SPA فعال است)
```

مسیرهای `/admin/**` — خارج از دامنهٔ اپ.

## پیوست B — واژه‌نامه

| واژه | معنی |
|------|------|
| Platform token | واحد کیف PiGPT برای مصرف مدل/استودیو |
| Daily cap | سقف مصرف روزانه (تهران) |
| Capability | پرچم فعال‌سازی استودیو از رجیستری سرور |
| SSE | Server-Sent Events برای استریم چت |
| PiCode | CLI خواهر؛ در موبایل فقط راهنما |

---

## English summary (short)

PiGPT Flutter (Android/iOS) will mirror **all consumer web features** of `https://pigpt.ir` with native mobile UX, dark-default RTL Persian UI, and polished motion — **excluding** `/admin/**` and any embedded PiCode runtime (guide/install screen only, like `/app/cli`). Architecture: layered Flutter + Riverpod, secure token storage, Dio/HTTP + SSE streaming against `/api/v1`. Auth: email/password (+ Google if enabled; OTP currently disabled). Delivery: MVP chat/agent-mode + wallet/plans/settings → Quick Start + PiCode guide → agent missions → full studios. Push is post-MVP. Spec path: `C:\MyServer\_pigpt_mobile\docs\PIGPT_FLUTTER_APP_SPEC.md`.
