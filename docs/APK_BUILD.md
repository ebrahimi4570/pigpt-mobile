# ساخت APK عمومی — فقط arm64

**هرگز APK سنگین / fat / universal نسازید.** نسخهٔ عمومی باید **فقط arm64** باشد (~۲۰ مگابایت)، نه fat سه‌ABI (~۵۸ مگابایت).

**Never ship a fat/universal APK.** Public release is **arm64-only** (~20MB), never the 3-ABI fat build (~58MB).

---

## دستور الزامی (required)

از پوشهٔ `mobile/`:

```bash
flutter build apk --release --target-platform android-arm64
```

خروجی: `mobile/build/app/outputs/flutter-apk/app-release.apk` (arm64-only).

### جایگزین: split per ABI

اگر split می‌سازید، **فقط** فایل arm64 را منتشر کنید:

```bash
flutter build apk --release --split-per-abi
```

منتشر کنید: `app-arm64-v8a-release.apk`  
منتشر نکنید: `app-armeabi-v7a-release.apk` ، `app-x86_64-release.apk` ، یا APK ترکیبی.

---

## ممنوع

| دستور | نتیجه |
|--------|--------|
| `flutter build apk --release` بدون `--target-platform` | fat / universal ≈ ۳ ABI ≈ ~۵۸MB — **ممنوع** |
| انتشار هر سه ABI یا APK universal | حجم سه‌برابر برای کاربر — **ممنوع** |

نسخهٔ **۱.۳.۱** اشتباهاً با `flutter build apk --release` (بدون `target-platform`) ساخته شد و حجم تقریباً سه‌برابر شد. این اشتباه تکرار نشود.

---

## CI

Workflow: `.github/workflows/android-apk.yml`

باید همیشه شامل باشد:

`--target-platform android-arm64`

اگر این فلگ حذف شود، CI دوباره APK سنگین می‌سازد. آن را تغییر ندهید مگر با تصمیم صریح نگهداری.

---

## یادداشت

الان لازم نیست APK جدید بسازید؛ این سند فقط قانون ساخت را ثبت می‌کند.
