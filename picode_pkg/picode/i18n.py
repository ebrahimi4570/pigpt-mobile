"""UI chrome language (fa/en/tr/ar). Assistant reply language stays LANGUAGE_RULE."""

from __future__ import annotations

from typing import Any

UI_LANGS = ("fa", "en", "tr", "ar")
DEFAULT_UI_LANG = "fa"

# Flat catalog: key → {fa, en, tr, ar}. Brand tokens stay Latin.
_STRINGS: dict[str, dict[str, str]] = {
    "status.thinking": {
        "fa": "{brand} در حال فکر…",
        "en": "{brand} thinking…",
        "tr": "{brand} düşünüyor…",
        "ar": "{brand} يفكر…",
    },
    "status.reading": {
        "fa": "خواندن {path}",
        "en": "Reading {path}",
        "tr": "Okunuyor {path}",
        "ar": "قراءة {path}",
    },
    "status.writing": {
        "fa": "نوشتن {path}",
        "en": "Writing {path}",
        "tr": "Yazılıyor {path}",
        "ar": "كتابة {path}",
    },
    "status.running": {
        "fa": "اجرا: {cmd}",
        "en": "Running: {cmd}",
        "tr": "Çalışıyor: {cmd}",
        "ar": "تشغيل: {cmd}",
    },
    "status.ssh": {
        "fa": "SSH {host}: {cmd}",
        "en": "SSH {host}: {cmd}",
        "tr": "SSH {host}: {cmd}",
        "ar": "SSH {host}: {cmd}",
    },
    "status.web_search": {
        "fa": "جستجوی وب: {query}",
        "en": "Web search: {query}",
        "tr": "Web araması: {query}",
        "ar": "بحث ويب: {query}",
    },
    "status.web_fetch": {
        "fa": "دریافت: {url}",
        "en": "Fetching: {url}",
        "tr": "İndiriliyor: {url}",
        "ar": "جلب: {url}",
    },
    "status.indexing": {
        "fa": "ایندکس ریپو…",
        "en": "Indexing repo…",
        "tr": "Depo dizini oluşturuluyor…",
        "ar": "فهرسة المستودع…",
    },
    "status.suggest_commit": {
        "fa": "پیشنهاد کامیت…",
        "en": "Suggesting commit…",
        "tr": "Commit önerisi…",
        "ar": "اقتراح commit…",
    },
    "status.suggest_pr": {
        "fa": "پیشنهاد PR…",
        "en": "Suggesting PR…",
        "tr": "PR önerisi…",
        "ar": "اقتراح PR…",
    },
    "status.suggest_edit": {
        "fa": "پیشنهاد ویرایش…",
        "en": "Suggesting edit…",
        "tr": "Düzenleme önerisi…",
        "ar": "اقتراح تعديل…",
    },
    "status.busy": {"fa": "مشغول…", "en": "Busy…", "tr": "Meşgul…", "ar": "مشغول…"},
    "status.done": {"fa": "آماده", "en": "Ready", "tr": "Hazır", "ar": "جاهز"},
    "status.error": {
        "fa": "خطا: {detail}",
        "en": "Error: {detail}",
        "tr": "Hata: {detail}",
        "ar": "خطأ: {detail}",
    },
    "confirm.yes": {"fa": "بله", "en": "Yes", "tr": "Evet", "ar": "نعم"},
    "confirm.no": {"fa": "خیر", "en": "No", "tr": "Hayır", "ar": "لا"},
    "confirm.cancel": {"fa": "انصراف", "en": "Cancel", "tr": "İptal", "ar": "إلغاء"},
    "confirm.save": {"fa": "ذخیره", "en": "Save", "tr": "Kaydet", "ar": "حفظ"},
    "confirm.run_shell": {
        "fa": "اجرا شود؟ {cmd}",
        "en": "Run: {cmd}?",
        "tr": "Çalıştırılsın mı? {cmd}",
        "ar": "تشغيل؟ {cmd}",
    },
    "confirm.ssh": {
        "fa": "SSH روی «{connection}»؟\n{cmd}",
        "en": "SSH on “{connection}”?\n{cmd}",
        "tr": "SSH “{connection}” üzerinde?\n{cmd}",
        "ar": "SSH على «{connection}»؟\n{cmd}",
    },
    "confirm.web_search": {
        "fa": "جستجوی وب؟\n{query}",
        "en": "Search the web?\n{query}",
        "tr": "Web aransın mı?\n{query}",
        "ar": "البحث في الويب؟\n{query}",
    },
    "confirm.web_fetch": {
        "fa": "دریافت این آدرس؟\n{url}",
        "en": "Fetch this URL?\n{url}",
        "tr": "Bu URL indirilsin mi?\n{url}",
        "ar": "جلب هذا الرابط؟\n{url}",
    },
    "confirm.apply_patch": {
        "fa": "اعمال پچ روی دیسک؟",
        "en": "Apply patch to disk?",
        "tr": "Yama diske uygulansın mı?",
        "ar": "تطبيق التصحيح على القرص؟",
    },
    "warn.not_signed_in": {
        "fa": "وارد نشده‌اید. /login",
        "en": "Not signed in. /login",
        "tr": "Oturum açık değil. /login",
        "ar": "لم تسجّل الدخول. /login",
    },
    "warn.cancelled": {"fa": "لغو شد", "en": "Cancelled", "tr": "İptal edildi", "ar": "أُلغي"},
    "warn.shell_denied": {
        "fa": "اجرای شل در حالت deny مسدود است. /permissions shell ask|auto",
        "en": "Shell execution blocked in deny mode. /permissions shell ask|auto",
        "tr": "Shell, deny modunda engelli. /permissions shell ask|auto",
        "ar": "تنفيذ الشل محظور في وضع deny. /permissions shell ask|auto",
    },
    "warn.remote_denied": {
        "fa": "دسترسی SSH خاموش است. /permissions remote ask|auto",
        "en": "SSH access is off. /permissions remote ask|auto",
        "tr": "SSH kapalı. /permissions remote ask|auto",
        "ar": "SSH معطّل. /permissions remote ask|auto",
    },
    "warn.web_denied": {
        "fa": "دسترسی وب خاموش است. /permissions web ask|auto",
        "en": "Web access is off. /permissions web ask|auto",
        "tr": "Web erişimi kapalı. /permissions web ask|auto",
        "ar": "الويب معطّل. /permissions web ask|auto",
    },
    "warn.writes_off": {
        "fa": "نوشتن فایل در تنظیمات خاموش است. /permissions auto",
        "en": "File writes are turned off in settings. /permissions auto",
        "tr": "Dosya yazma ayarlarda kapalı. /permissions auto",
        "ar": "كتابة الملفات معطّلة في الإعدادات. /permissions auto",
    },
    "warn.ssh_none": {
        "fa": "هیچ اتصال SSH ذخیره نشده. /ssh add",
        "en": "No SSH connections saved. /ssh add",
        "tr": "Kayıtlı SSH yok. /ssh add",
        "ar": "لا اتصالات SSH. /ssh add",
    },
    "warn.no_file": {
        "fa": "فایلی نوشته نشد. نام و محتوای فایل را بگویید و دوباره امتحان کنید.",
        "en": "No file was written. Include the file name and contents, then try again.",
        "tr": "Dosya yazılmadı. Dosya adı ve içeriği verip yeniden deneyin.",
        "ar": "لم تُكتب أي ملف. اذكر الاسم والمحتوى ثم أعد المحاولة.",
    },
    "warn.empty_reply": {
        "fa": "(پاسخ خالی)",
        "en": "(empty reply)",
        "tr": "(boş yanıt)",
        "ar": "(رد فارغ)",
    },
    "warn.nothing_to_apply": {
        "fa": "چیزی برای اعمال نیست. اول /edit بزنید.",
        "en": "Nothing to apply. Run /edit first.",
        "tr": "Uygulanacak bir şey yok. Önce /edit çalıştırın.",
        "ar": "لا شيء للتطبيق. نفّذ /edit أولاً.",
    },
    "warn.no_diff": {
        "fa": "دیفی نیست. اول /edit بزنید.",
        "en": "No diff available. Run /edit first.",
        "tr": "Diff yok. Önce /edit çalıştırın.",
        "ar": "لا يوجد diff. نفّذ /edit أولاً.",
    },
    "warn.no_hits": {
        "fa": "نتیجه‌ای نبود. /index برای بازسازی.",
        "en": "No hits. /index to rebuild.",
        "tr": "Sonuç yok. Yeniden oluşturmak için /index.",
        "ar": "لا نتائج. أعد البناء بـ /index.",
    },
    "warn.unknown_cmd": {
        "fa": "دستور ناشناخته: {cmd}",
        "en": "Unknown command: {cmd}",
        "tr": "Bilinmeyen komut: {cmd}",
        "ar": "أمر غير معروف: {cmd}",
    },
    "warn.session_expired": {
        "fa": "نشست API منقضی شد. /login یا {product} login — توکن تا /logout می‌ماند.",
        "en": "API session expired. /login or {product} login — token stays in config until /logout.",
        "tr": "API oturumu doldu. /login veya {product} login — token /logout’a kadar kalır.",
        "ar": "انتهت جلسة API. /login أو {product} login — يبقى الرمز حتى /logout.",
    },
    "warn.ai_usage": {
        "fa": "مصرف AI: {detail}",
        "en": "AI usage: {detail}",
        "tr": "AI kullanımı: {detail}",
        "ar": "استخدام AI: {detail}",
    },
    "warn.still_signed_in": {
        "fa": "هنوز واردید — /status · /cost",
        "en": "Still signed in — /status · /cost",
        "tr": "Hâlâ oturum açık — /status · /cost",
        "ar": "ما زلت مسجّلاً — /status · /cost",
    },
    "ok.wrote": {
        "fa": "نوشته شد {name}",
        "en": "Wrote {name}",
        "tr": "Yazıldı {name}",
        "ar": "كُتب {name}",
    },
    "ok.applied": {
        "fa": "اعمال شد: {path}",
        "en": "Applied: {path}",
        "tr": "Uygulandı: {path}",
        "ar": "طُبّق: {path}",
    },
    "ok.signed_out": {
        "fa": "خارج شدید. نشست از ~/.picode/ پاک شد.",
        "en": "Signed out. Session cleared from ~/.picode/.",
        "tr": "Çıkış yapıldı. Oturum ~/.picode/ içinden silindi.",
        "ar": "تم تسجيل الخروج. مُسحت الجلسة من ~/.picode/.",
    },
    "ok.history_cleared": {
        "fa": "تاریخچهٔ این نشست پاک شد.",
        "en": "Chat history cleared for this session.",
        "tr": "Bu oturumun sohbet geçmişi silindi.",
        "ar": "مُسح سجل هذه الجلسة.",
    },
    "ok.up_to_date": {
        "fa": "{brand} {version} به‌روز است.",
        "en": "{brand} {version} is up to date.",
        "tr": "{brand} {version} güncel.",
        "ar": "{brand} {version} محدّث.",
    },
    "ok.update_installed": {
        "fa": "به‌روزرسانی نصب شد. ترمینال را ببندید و دوباره picode را اجرا کنید.",
        "en": "Update installed. Restart the terminal and run picode again.",
        "tr": "Güncelleme kuruldu. Terminali kapatıp picode’u yeniden çalıştırın.",
        "ar": "تم تثبيت التحديث. أغلق الطرفية وشغّل picode مجددًا.",
    },
    "ok.discarded": {
        "fa": "پیشنهاد ویرایش کنار گذاشته شد",
        "en": "Edit suggestion discarded",
        "tr": "Düzenleme önerisi iptal edildi",
        "ar": "تم تجاهل اقتراح التعديل",
    },
    "ok.language_set": {
        "fa": "زبان رابط: {lang}",
        "en": "UI language: {lang}",
        "tr": "Arayüz dili: {lang}",
        "ar": "لغة الواجهة: {lang}",
    },
    "ok.permissions_saved": {
        "fa": "مجوزها ذخیره شد.\nفایل: {files} · شل: {shell} · SSH: {remote} · وب: {web}",
        "en": "Permissions saved.\nFiles: {files} · Shell: {shell} · SSH: {remote} · Web: {web}",
        "tr": "İzinler kaydedildi.\nDosya: {files} · Shell: {shell} · SSH: {remote} · Web: {web}",
        "ar": "تم حفظ الأذونات.\nالملفات: {files} · الشل: {shell} · SSH: {remote} · الويب: {web}",
    },
    "ok.ssh_saved": {
        "fa": "اتصال SSH ذخیره شد: {name}",
        "en": "SSH connection saved: {name}",
        "tr": "SSH kaydedildi: {name}",
        "ar": "تم حفظ اتصال SSH: {name}",
    },
    "ok.ssh_deleted": {
        "fa": "اتصال حذف شد: {name}",
        "en": "Connection deleted: {name}",
        "tr": "Bağlantı silindi: {name}",
        "ar": "حُذف الاتصال: {name}",
    },
    "ok.ssh_default": {
        "fa": "اتصال پیش‌فرض: {name}",
        "en": "Default connection: {name}",
        "tr": "Varsayılan bağlantı: {name}",
        "ar": "الاتصال الافتراضي: {name}",
    },
    "ok.ssh_test": {
        "fa": "اتصال موفق ({name}) — exit {code}",
        "en": "Connection OK ({name}) — exit {code}",
        "tr": "Bağlantı OK ({name}) — exit {code}",
        "ar": "الاتصال ناجح ({name}) — exit {code}",
    },
    "help.slash_title": {
        "fa": "دستورهای اسلش",
        "en": "Slash commands",
        "tr": "Slash komutları",
        "ar": "أوامر الشرطة المائلة",
    },
    "help.menu_hint": {
        "fa": " {n}/{total}  بالا/پایین  تایپ برای فیلتر  Enter {verb}  Esc بستن",
        "en": " {n}/{total}  up/down move  type to filter  Enter {verb}  Esc close",
        "tr": " {n}/{total}  yukarı/aşağı  filtre için yazın  Enter {verb}  Esc kapat",
        "ar": " {n}/{total}  أعلى/أسفل  اكتب للتصفية  Enter {verb}  Esc إغلاق",
    },
    "help.menu_run": {"fa": "اجرا", "en": "run", "tr": "çalıştır", "ar": "تشغيل"},
    "help.menu_insert": {"fa": "درج", "en": "insert", "tr": "ekle", "ar": "إدراج"},
    "help.repl_welcome": {
        "fa": (
            "{brand} {version} · بک‌اند {web}\n"
            "پروژه: {project}\n"
            "پیام بنویسید. گفتگو می‌تواند در این پوشه فایل بسازد یا ویرایش کند.\n"
            "با / دستورها؛ با @ پیوست فایل. خروج: /exit"
        ),
        "en": (
            "{brand} {version} · backend {web}\n"
            "Project: {project}\n"
            "Type a message. Chat can create and edit files in this folder.\n"
            "Type / for commands. Type @ to attach a file. Exit: /exit"
        ),
        "tr": (
            "{brand} {version} · backend {web}\n"
            "Proje: {project}\n"
            "Mesaj yazın. Sohbet bu klasörde dosya oluşturup düzenleyebilir.\n"
            "Komutlar için / ; dosya eklemek için @ . Çıkış: /exit"
        ),
        "ar": (
            "{brand} {version} · الخلفية {web}\n"
            "المشروع: {project}\n"
            "اكتب رسالة. يمكن للمحادثة إنشاء الملفات وتعديلها في هذا المجلد.\n"
            "اكتب / للأوامر و @ لإرفاق ملف. الخروج: /exit"
        ),
    },
    "help.goodbye": {
        "fa": "خداحافظ — {brand}",
        "en": "Goodbye — {brand}",
        "tr": "Hoşça kalın — {brand}",
        "ar": "إلى اللقاء — {brand}",
    },
    "help.language_usage": {
        "fa": "زبان رابط: {lang}\nتنظیم: /language fa|en|tr|ar  (پیش‌فرض fa)",
        "en": "UI language: {lang}\nSet: /language fa|en|tr|ar  (default fa)",
        "tr": "Arayüz dili: {lang}\nAyar: /language fa|en|tr|ar  (varsayılan fa)",
        "ar": "لغة الواجهة: {lang}\nالتعيين: /language fa|en|tr|ar  (الافتراضي fa)",
    },
    "desk.subtitle": {
        "fa": "نسخه {version} · گفتگو، فایل، و دستورها در همین پنجره",
        "en": "Version {version} · chat, files, and commands in this window",
        "tr": "Sürüm {version} · sohbet, dosyalar ve komutlar bu pencerede",
        "ar": "الإصدار {version} · المحادثة والملفات والأوامر في هذه النافذة",
    },
    "desk.welcome": {
        "fa": (
            "{brand} {version}\n"
            "خروجی گفتگو اینجاست. پیام را پایین بنویسید.\n"
            "وضعیت زنده (فکر، خواندن، نوشتن، اجرا) همین بالا دیده می‌شود.\n"
            "از گفتگو می‌توانید در پوشهٔ جاری فایل بسازید یا ویرایش کنید.\n"
            "با / فهرست دستورها؛ با @ پیوست فایل. زبان رابط از منوی تنظیمات یا /language."
        ),
        "en": (
            "{brand} {version}\n"
            "Chat output appears here. Type below.\n"
            "Live status (thinking, reading, writing, running) shows above while busy.\n"
            "Chat can create and edit files in the current folder.\n"
            "Type / for commands; @ to attach a file. UI language: Settings or /language."
        ),
        "tr": (
            "{brand} {version}\n"
            "Sohbet çıktısı burada. Aşağıya yazın.\n"
            "Canlı durum (düşünme, okuma, yazma, çalıştırma) üstte görünür.\n"
            "Sohbet geçerli klasörde dosya oluşturup düzenleyebilir.\n"
            "Komutlar için / ; dosya için @ . Arayüz dili: Ayarlar veya /language."
        ),
        "ar": (
            "{brand} {version}\n"
            "مخرجات المحادثة هنا. اكتب في الأسفل.\n"
            "الحالة المباشرة (تفكير، قراءة، كتابة، تشغيل) تظهر أعلاه أثناء العمل.\n"
            "يمكن للمحادثة إنشاء الملفات وتعديلها في المجلد الحالي.\n"
            "اكتب / للأوامر و @ لإرفاق ملف. لغة الواجهة من الإعدادات أو /language."
        ),
    },
    "desk.placeholder": {
        "fa": "پیام بنویسید · / برای دستورها · @ برای پیوست فایل",
        "en": "Type a message · / for commands · @ to attach a file",
        "tr": "Mesaj yazın · / komutlar · @ dosya ekle",
        "ar": "اكتب رسالة · / للأوامر · @ لإرفاق ملف",
    },
    "desk.send": {"fa": "ارسال", "en": "Send", "tr": "Gönder", "ar": "إرسال"},
    "desk.busy": {"fa": "…", "en": "…", "tr": "…", "ar": "…"},
    "desk.login": {"fa": "ورود", "en": "Sign in", "tr": "Giriş", "ar": "تسجيل الدخول"},
    "desk.logout": {"fa": "خروج", "en": "Sign out", "tr": "Çıkış", "ar": "تسجيل الخروج"},
    "desk.permissions": {"fa": "مجوزها", "en": "Permissions", "tr": "İzinler", "ar": "الأذونات"},
    "desk.update": {"fa": "به‌روزرسانی", "en": "Update", "tr": "Güncelle", "ar": "تحديث"},
    "desk.language": {
        "fa": "زبان رابط",
        "en": "UI language",
        "tr": "Arayüz dili",
        "ar": "لغة الواجهة",
    },
    "desk.status": {"fa": "وضعیت", "en": "Status", "tr": "Durum", "ar": "الحالة"},
    "desk.project": {"fa": "پروژه", "en": "Project", "tr": "Proje", "ar": "المشروع"},
    "desk.help": {"fa": "دستورها", "en": "Commands", "tr": "Komutlar", "ar": "الأوامر"},
    "desk.clear": {
        "fa": "پاک‌کردن صفحه",
        "en": "Clear screen",
        "tr": "Ekranı temizle",
        "ar": "مسح الشاشة",
    },
    "desk.menu_account": {"fa": "حساب", "en": "Account", "tr": "Hesap", "ar": "الحساب"},
    "desk.menu_tools": {"fa": "ابزارها", "en": "Tools", "tr": "Araçlar", "ar": "الأدوات"},
    "desk.menu_settings": {
        "fa": "تنظیمات",
        "en": "Settings",
        "tr": "Ayarlar",
        "ar": "الإعدادات",
    },
    "desk.menu_view": {"fa": "نمایش", "en": "View", "tr": "Görünüm", "ar": "العرض"},
    "desk.menu_file": {"fa": "فایل", "en": "File", "tr": "Dosya", "ar": "ملف"},
    "desk.activity": {"fa": "فعالیت", "en": "Activity", "tr": "Etkinlik", "ar": "النشاط"},
    "desk.perm_title": {
        "fa": "مجوزها — {brand}",
        "en": "Permissions — {brand}",
        "tr": "İzinler — {brand}",
        "ar": "الأذونات — {brand}",
    },
    "desk.perm_files": {
        "fa": "نوشتن فایل از گفتگو:",
        "en": "Chat file writes:",
        "tr": "Sohbetten dosya yazma:",
        "ar": "كتابة الملفات من المحادثة:",
    },
    "desk.perm_shell": {
        "fa": "اجرای دستور شل:",
        "en": "Shell commands:",
        "tr": "Shell komutları:",
        "ar": "أوامر الشل:",
    },
    "desk.perm_remote": {
        "fa": "SSH ریموت:",
        "en": "Remote SSH:",
        "tr": "Uzak SSH:",
        "ar": "SSH البعيد:",
    },
    "desk.perm_web": {
        "fa": "جستجو / وب:",
        "en": "Web / search:",
        "tr": "Web / arama:",
        "ar": "الويب / البحث:",
    },
    "desk.connections": {
        "fa": "اتصالات SSH",
        "en": "SSH connections",
        "tr": "SSH bağlantıları",
        "ar": "اتصالات SSH",
    },
    "desk.conn_title": {
        "fa": "اتصالات SSH — {brand}",
        "en": "SSH connections — {brand}",
        "tr": "SSH bağlantıları — {brand}",
        "ar": "اتصالات SSH — {brand}",
    },
    "desk.conn_hint": {
        "fa": "رمز و کلید فقط در تنظیمات شما (~/.picode) ذخیره می‌شود. PiCode آن‌ها را برای شما نمی‌دزدد.",
        "en": "Passwords and keys stay in your local config (~/.picode). PiCode never steals them silently.",
        "tr": "Şifre ve anahtarlar yalnızca yerel ayarınızda (~/.picode) kalır.",
        "ar": "كلمات المرور والمفاتيح تبقى في إعداداتك المحلية (~/.picode).",
    },
    "desk.conn_name": {"fa": "نام", "en": "Name", "tr": "Ad", "ar": "الاسم"},
    "desk.conn_host": {"fa": "میزبان", "en": "Host", "tr": "Host", "ar": "المضيف"},
    "desk.conn_port": {"fa": "پورت", "en": "Port", "tr": "Port", "ar": "المنفذ"},
    "desk.conn_user": {"fa": "کاربر", "en": "Username", "tr": "Kullanıcı", "ar": "المستخدم"},
    "desk.conn_auth": {"fa": "احراز هویت", "en": "Auth", "tr": "Kimlik", "ar": "المصادقة"},
    "desk.conn_auth_key": {
        "fa": "کلید خصوصی",
        "en": "Private key",
        "tr": "Özel anahtar",
        "ar": "مفتاح خاص",
    },
    "desk.conn_auth_password": {
        "fa": "رمز عبور",
        "en": "Password",
        "tr": "Şifre",
        "ar": "كلمة المرور",
    },
    "desk.conn_key": {
        "fa": "مسیر کلید",
        "en": "Key path",
        "tr": "Anahtar yolu",
        "ar": "مسار المفتاح",
    },
    "desk.conn_passphrase": {
        "fa": "عبارت عبور کلید (اختیاری)",
        "en": "Key passphrase (optional)",
        "tr": "Anahtar parolası (isteğe bağlı)",
        "ar": "عبارة مرور المفتاح (اختياري)",
    },
    "desk.conn_password": {
        "fa": "رمز عبور",
        "en": "Password",
        "tr": "Şifre",
        "ar": "كلمة المرور",
    },
    "desk.conn_add": {"fa": "افزودن / ویرایش", "en": "Add / edit", "tr": "Ekle / düzenle", "ar": "إضافة / تعديل"},
    "desk.conn_delete": {"fa": "حذف", "en": "Delete", "tr": "Sil", "ar": "حذف"},
    "desk.conn_test": {"fa": "تست اتصال", "en": "Test", "tr": "Test", "ar": "اختبار"},
    "desk.conn_default": {
        "fa": "پیش‌فرض",
        "en": "Set default",
        "tr": "Varsayılan yap",
        "ar": "تعيين افتراضي",
    },
    "desk.conn_list": {
        "fa": "فهرست اتصالات",
        "en": "Saved connections",
        "tr": "Kayıtlı bağlantılar",
        "ar": "الاتصالات المحفوظة",
    },
    "desk.perm_auto": {
        "fa": "خودکار (پیشنهادی)",
        "en": "Auto (recommended)",
        "tr": "Otomatik (önerilen)",
        "ar": "تلقائي (موصى به)",
    },
    "desk.perm_ask": {
        "fa": "پرسش قبل از نوشتن",
        "en": "Ask before write",
        "tr": "Yazmadan önce sor",
        "ar": "اسأل قبل الكتابة",
    },
    "desk.perm_deny": {"fa": "غیرفعال", "en": "Off", "tr": "Kapalı", "ar": "إيقاف"},
    "desk.perm_shell_ask": {
        "fa": "پرسش قبل از اجرا",
        "en": "Ask before run",
        "tr": "Çalıştırmadan önce sor",
        "ar": "اسأل قبل التشغيل",
    },
    "desk.perm_shell_auto": {"fa": "خودکار", "en": "Auto", "tr": "Otomatik", "ar": "تلقائي"},
    "desk.perm_shell_deny": {"fa": "غیرفعال", "en": "Off", "tr": "Kapalı", "ar": "إيقاف"},
    "desk.perm_hint": {
        "fa": "نوشتن فایل پیش‌فرض خودکار است. SSH و وب پیش‌فرض «پرسش» هستند — فقط با اجازهٔ شما.",
        "en": "File writes default to auto. SSH and web default to ask — only with your approval.",
        "tr": "Dosya yazma varsayılanı otomatik. SSH ve web varsayılanı sor — onayınızla.",
        "ar": "كتابة الملفات افتراضيًا تلقائية. SSH والويب افتراضيًا «اسأل» — بموافقتك فقط.",
    },
    # Language picker: native name + Latin tag users recognize
    "desk.lang_fa": {
        "fa": "فارسی",
        "en": "Persian (فارسی)",
        "tr": "Farsça (فارسی)",
        "ar": "الفارسية (فارسی)",
    },
    "desk.lang_en": {
        "fa": "English",
        "en": "English",
        "tr": "English",
        "ar": "English",
    },
    "desk.lang_tr": {
        "fa": "Türkçe",
        "en": "Turkish (Türkçe)",
        "tr": "Türkçe",
        "ar": "التركية (Türkçe)",
    },
    "desk.lang_ar": {
        "fa": "العربية",
        "en": "Arabic (العربية)",
        "tr": "Arapça (العربية)",
        "ar": "العربية",
    },
    "desk.open_hub": {
        "fa": "صفحهٔ PiCode در وب",
        "en": "PiCode on the web",
        "tr": "Web’de PiCode",
        "ar": "PiCode على الويب",
    },
    "desk.models": {"fa": "مدل‌ها", "en": "Models", "tr": "Modeller", "ar": "النماذج"},
    "desk.models_pick": {
        "fa": "انتخاب مدل",
        "en": "Choose model",
        "tr": "Model seç",
        "ar": "اختر نموذجًا",
    },
    "desk.models_filter": {
        "fa": "تایپ برای فیلتر…",
        "en": "Type to filter…",
        "tr": "Filtrelemek için yazın…",
        "ar": "اكتب للتصفية…",
    },
    "desk.commands_pick": {
        "fa": "دستورها",
        "en": "Commands",
        "tr": "Komutlar",
        "ar": "الأوامر",
    },
    "desk.workspaces_pick": {
        "fa": "فضاهای کار",
        "en": "Workspaces",
        "tr": "Çalışma alanları",
        "ar": "مساحات العمل",
    },
    "desk.projects_title": {
        "fa": "پروژه‌ها",
        "en": "Projects",
        "tr": "Projeler",
        "ar": "المشاريع",
    },
    "desk.project_add": {
        "fa": "افزودن",
        "en": "Add",
        "tr": "Ekle",
        "ar": "إضافة",
    },
    "desk.project_remove": {
        "fa": "حذف",
        "en": "Remove",
        "tr": "Sil",
        "ar": "إزالة",
    },
    "desk.project_remove_confirm": {
        "fa": "پروژه «{name}» از فهرست حذف شود؟ (فایل‌های دیسک پاک نمی‌شوند)",
        "en": "Remove project “{name}” from the list? (disk files are not deleted)",
        "tr": "“{name}” listeden kaldırılsın mı? (disk dosyaları silinmez)",
        "ar": "إزالة المشروع «{name}» من القائمة؟ (لن تُحذف ملفات القرص)",
    },
    "desk.project_temp": {
        "fa": "پوشهٔ موقت PiCode: {path}",
        "en": "PiCode temp folder: {path}",
        "tr": "PiCode geçici klasörü: {path}",
        "ar": "مجلد PiCode المؤقت: {path}",
    },
    "desk.placeholder_multi": {
        "fa": "پیام بنویسید · Enter ارسال · Shift+Enter خط جدید · / دستور · @ فایل",
        "en": "Message · Enter send · Shift+Enter newline · / commands · @ file",
        "tr": "Mesaj · Enter gönder · Shift+Enter satır · / komut · @ dosya",
        "ar": "رسالة · Enter إرسال · Shift+Enter سطر · / أوامر · @ ملف",
    },
    "desk.model_switch": {
        "fa": "مدل",
        "en": "Model",
        "tr": "Model",
        "ar": "النموذج",
    },
    "desk.model_default": {
        "fa": "پیش‌فرض سرور",
        "en": "Server default",
        "tr": "Sunucu varsayılanı",
        "ar": "افتراضي الخادم",
    },
    "desk.settings_open": {
        "fa": "تنظیمات…",
        "en": "Settings…",
        "tr": "Ayarlar…",
        "ar": "الإعدادات…",
    },
    "desk.settings_title": {
        "fa": "تنظیمات — {brand}",
        "en": "Settings — {brand}",
        "tr": "Ayarlar — {brand}",
        "ar": "الإعدادات — {brand}",
    },
    "desk.settings_tab_perm": {
        "fa": "مجوزها",
        "en": "Permissions",
        "tr": "İzinler",
        "ar": "الأذونات",
    },
    "desk.settings_tab_lang": {
        "fa": "زبان",
        "en": "Language",
        "tr": "Dil",
        "ar": "اللغة",
    },
    "desk.settings_tab_conn": {
        "fa": "SSH / وب",
        "en": "SSH / web",
        "tr": "SSH / web",
        "ar": "SSH / ويب",
    },
    "desk.settings_tab_usage": {
        "fa": "مصرف",
        "en": "Usage",
        "tr": "Kullanım",
        "ar": "الاستخدام",
    },
    "desk.settings_tab_about": {
        "fa": "درباره",
        "en": "About",
        "tr": "Hakkında",
        "ar": "حول",
    },
    "desk.settings_lang_hint": {
        "fa": "زبان رابط جدا از زبان پاسخ دستیار است.",
        "en": "UI language is separate from assistant reply language.",
        "tr": "Arayüz dili, asistan yanıt dilinden ayrıdır.",
        "ar": "لغة الواجهة منفصلة عن لغة رد المساعد.",
    },
    "desk.settings_about": {
        "fa": (
            "{brand} {version}\n\n"
            "ریشهٔ پروژه: {root}\n"
            "پوشهٔ موقت PiCode: {picode}\n\n"
            "برندها لاتین می‌مانند: PiCode / PiGPT."
        ),
        "en": (
            "{brand} {version}\n\n"
            "Project root: {root}\n"
            "PiCode temp folder: {picode}\n\n"
            "Brand tokens stay Latin: PiCode / PiGPT."
        ),
        "tr": (
            "{brand} {version}\n\n"
            "Proje kökü: {root}\n"
            "PiCode geçici klasörü: {picode}\n\n"
            "Marka adları Latin kalır: PiCode / PiGPT."
        ),
        "ar": (
            "{brand} {version}\n\n"
            "جذر المشروع: {root}\n"
            "مجلد PiCode المؤقت: {picode}\n\n"
            "أسماء العلامة تبقى لاتينية: PiCode / PiGPT."
        ),
    },
    "desk.usage_refresh": {
        "fa": "بروزرسانی مصرف",
        "en": "Refresh usage",
        "tr": "Kullanımı yenile",
        "ar": "تحديث الاستخدام",
    },
    "desk.usage_account_title": {
        "fa": "مصرف حساب (از /me)",
        "en": "Account usage (from /me)",
        "tr": "Hesap kullanımı (/me)",
        "ar": "استخدام الحساب (من /me)",
    },
    "desk.usage_session_title": {
        "fa": "این گفتگو",
        "en": "This conversation",
        "tr": "Bu sohbet",
        "ar": "هذه المحادثة",
    },
    "desk.usage_plan": {"fa": "پلن", "en": "Plan", "tr": "Plan", "ar": "الخطة"},
    "desk.usage_messages": {
        "fa": "پیام امروز",
        "en": "Messages today",
        "tr": "Bugünkü mesaj",
        "ar": "رسائل اليوم",
    },
    "desk.usage_remaining": {
        "fa": "باقی‌مانده",
        "en": "Remaining",
        "tr": "Kalan",
        "ar": "المتبقي",
    },
    "desk.usage_session_msgs": {
        "fa": "پیام‌های نشست",
        "en": "Session messages",
        "tr": "Oturum mesajları",
        "ar": "رسائل الجلسة",
    },
    "desk.usage_session_tokens": {
        "fa": "تقریب توکن زمینه",
        "en": "Approx. context tokens",
        "tr": "Yaklaşık bağlam token",
        "ar": "تقريب رموز السياق",
    },
    "desk.usage_last_prompt": {
        "fa": "آخرین prompt",
        "en": "Last prompt tokens",
        "tr": "Son prompt",
        "ar": "آخر prompt",
    },
    "desk.usage_last_completion": {
        "fa": "آخرین completion",
        "en": "Last completion tokens",
        "tr": "Son completion",
        "ar": "آخر completion",
    },
    "desk.usage_session_empty": {
        "fa": "جزئیات توکن بعد از اولین پاسخ در این نشست ظاهر می‌شود.",
        "en": "Token detail appears after the first reply in this session.",
        "tr": "Token ayrıntısı bu oturumdaki ilk yanıttan sonra görünür.",
        "ar": "تظهر تفاصيل الرموز بعد أول رد في هذه الجلسة.",
    },
    "desk.usage_session_turns": {
        "fa": "نوبت‌های API این گفتگو",
        "en": "API turns this chat",
        "tr": "Bu sohbet API turları",
        "ar": "دورات API لهذه المحادثة",
    },
    "desk.usage_session_prompt_total": {
        "fa": "جمع prompt این گفتگو",
        "en": "Session prompt tokens total",
        "tr": "Oturum prompt toplamı",
        "ar": "مجموع prompt للجلسة",
    },
    "desk.usage_session_completion_total": {
        "fa": "جمع completion این گفتگو",
        "en": "Session completion tokens total",
        "tr": "Oturum completion toplamı",
        "ar": "مجموع completion للجلسة",
    },
    "desk.usage_session_token_total": {
        "fa": "جمع توکن این گفتگو",
        "en": "Session tokens total",
        "tr": "Oturum token toplamı",
        "ar": "مجموع رموز الجلسة",
    },
    "desk.usage_wallet_title": {
        "fa": "کیف پول (از /me)",
        "en": "Wallet (from /me)",
        "tr": "Cüzdan (/me)",
        "ar": "المحفظة (من /me)",
    },
    "desk.usage_wallet_api_title": {
        "fa": "کیف پول (/billing/wallet)",
        "en": "Wallet (/billing/wallet)",
        "tr": "Cüzdan (/billing/wallet)",
        "ar": "المحفظة (/billing/wallet)",
    },
    "desk.usage_token_report_title": {
        "fa": "گزارش توکن (/me/token-report)",
        "en": "Token report (/me/token-report)",
        "tr": "Token raporu (/me/token-report)",
        "ar": "تقرير الرموز (/me/token-report)",
    },
    "desk.usage_subscription_title": {
        "fa": "اشتراک",
        "en": "Subscription",
        "tr": "Abonelik",
        "ar": "الاشتراك",
    },
    "desk.chats_title": {
        "fa": "گفتگوها",
        "en": "Chats",
        "tr": "Sohbetler",
        "ar": "المحادثات",
    },
    "desk.chat_new": {
        "fa": "گفتگوی تازه",
        "en": "New chat",
        "tr": "Yeni sohbet",
        "ar": "محادثة جديدة",
    },
    "desk.chat_delete": {
        "fa": "حذف",
        "en": "Delete",
        "tr": "Sil",
        "ar": "حذف",
    },
    "desk.chat_delete_confirm": {
        "fa": "این گفتگوی محلی حذف شود؟",
        "en": "Delete this local chat?",
        "tr": "Bu yerel sohbet silinsin mi?",
        "ar": "حذف هذه المحادثة المحلية؟",
    },
    "desk.chat_started": {
        "fa": "گفتگوی تازه: {title}",
        "en": "New chat: {title}",
        "tr": "Yeni sohbet: {title}",
        "ar": "محادثة جديدة: {title}",
    },
    "desk.diff_title": {
        "fa": "دیف — {path}",
        "en": "Diff — {path}",
        "tr": "Diff — {path}",
        "ar": "Diff — {path}",
    },
    "desk.diff_hint": {
        "fa": "قبل از اعمال تغییر در «{path}» دیف را ببینید.",
        "en": "Review the diff before applying changes to “{path}”.",
        "tr": "“{path}” uygulanmadan önce diff’i inceleyin.",
        "ar": "راجع الفرق قبل تطبيق التغييرات على «{path}».",
    },
    "desk.diff_unified": {
        "fa": "یکپارچه",
        "en": "Unified",
        "tr": "Birleşik",
        "ar": "موحّد",
    },
    "desk.diff_before": {
        "fa": "قبل",
        "en": "Before",
        "tr": "Önce",
        "ar": "قبل",
    },
    "desk.diff_after": {
        "fa": "بعد",
        "en": "After",
        "tr": "Sonra",
        "ar": "بعد",
    },
    "desk.diff_apply": {
        "fa": "اعمال",
        "en": "Apply",
        "tr": "Uygula",
        "ar": "تطبيق",
    },
    "desk.diff_skip": {
        "fa": "رد کردن",
        "en": "Skip",
        "tr": "Atla",
        "ar": "تخطي",
    },
    "desk.attach_files": {
        "fa": "پیوست چند فایل…",
        "en": "Attach files…",
        "tr": "Dosya ekle…",
        "ar": "إرفاق ملفات…",
    },
    "desk.attach_clear": {
        "fa": "پاک‌کردن پیوست",
        "en": "Clear attachments",
        "tr": "Ekleri temizle",
        "ar": "مسح المرفقات",
    },
    "desk.attach_empty": {
        "fa": "پیوستی نیست — @ یا دکمهٔ پیوست",
        "en": "No attachments — @ or Attach",
        "tr": "Ek yok — @ veya Ekle",
        "ar": "لا مرفقات — @ أو إرفاق",
    },
    "desk.attach_list": {
        "fa": "پیوست: {files}",
        "en": "Attached: {files}",
        "tr": "Ekler: {files}",
        "ar": "المرفقات: {files}",
    },
    "desk.attach_outside": {
        "fa": "خارج از پروژه: {path}",
        "en": "Outside project: {path}",
        "tr": "Proje dışı: {path}",
        "ar": "خارج المشروع: {path}",
    },
    "desk.picker_filter": {
        "fa": "تایپ برای فیلتر…",
        "en": "Type to filter…",
        "tr": "Filtrelemek için yazın…",
        "ar": "اكتب للتصفية…",
    },
    "ok.workspace_set": {
        "fa": "فضای کار: {name} → {path}",
        "en": "Workspace: {name} → {path}",
        "tr": "Çalışma alanı: {name} → {path}",
        "ar": "مساحة العمل: {name} → {path}",
    },
    "warn.no_models": {
        "fa": "مدلی برای پلن شما نیست.",
        "en": "No models available for your plan.",
        "tr": "Planınız için model yok.",
        "ar": "لا نماذج متاحة لخطتك.",
    },
    "ok.model_set": {
        "fa": "مدل: {name}",
        "en": "Model: {name}",
        "tr": "Model: {name}",
        "ar": "النموذج: {name}",
    },
    "info.current_model": {
        "fa": "مدل فعلی: {name}",
        "en": "Current model: {name}",
        "tr": "Geçerli model: {name}",
        "ar": "النموذج الحالي: {name}",
    },
    "info.default_model": {
        "fa": "مدل فعلی: پیش‌فرض سرور",
        "en": "Current model: (server default)",
        "tr": "Geçerli model: (sunucu varsayılanı)",
        "ar": "النموذج الحالي: (افتراضي الخادم)",
    },
    "cmd./help": {
        "fa": "فهرست دستورها",
        "en": "List commands",
        "tr": "Komut listesi",
        "ar": "قائمة الأوامر",
    },
    "cmd./status": {
        "fa": "وضعیت ورود، پلن و سهمیه",
        "en": "Auth, plan, quota, API, project",
        "tr": "Oturum, plan, kota, API, proje",
        "ar": "الدخول والخطة والحصة والـ API والمشروع",
    },
    "cmd./model": {
        "fa": "مدل جاری یا تنظیم مدل",
        "en": "Current model or set model",
        "tr": "Geçerli model veya model ayarla",
        "ar": "النموذج الحالي أو تعيين نموذج",
    },
    "cmd./models": {
        "fa": "فهرست مدل‌های مجاز",
        "en": "List allowed models",
        "tr": "İzinli modelleri listele",
        "ar": "قائمة النماذج المسموحة",
    },
    "cmd./permissions": {
        "fa": "مجوز فایل، شل، SSH و وب",
        "en": "File/shell/SSH/web permissions",
        "tr": "Dosya/shell/SSH/web izinleri",
        "ar": "أذونات الملفات/الشل/SSH/الويب",
    },
    "cmd./ssh": {
        "fa": "مدیریت اتصالات SSH",
        "en": "Manage SSH connections",
        "tr": "SSH bağlantılarını yönet",
        "ar": "إدارة اتصالات SSH",
    },
    "cmd./perm": {
        "fa": "همان /permissions",
        "en": "Alias for /permissions",
        "tr": "/permissions kısayolu",
        "ar": "اختصار لـ /permissions",
    },
    "cmd./login": {
        "fa": "ورود با مرورگر",
        "en": "Sign in again via browser",
        "tr": "Tarayıcıyla giriş",
        "ar": "تسجيل الدخول عبر المتصفح",
    },
    "cmd./update": {
        "fa": "بررسی یا نصب به‌روزرسانی",
        "en": "Check/install PiCode update",
        "tr": "PiCode güncellemesini kontrol et/kur",
        "ar": "التحقق من تحديث PiCode أو تثبيته",
    },
    "cmd./logout": {
        "fa": "خروج و پاک‌کردن توکن",
        "en": "Sign out and clear token",
        "tr": "Çıkış ve token temizleme",
        "ar": "تسجيل الخروج ومسح الرمز",
    },
    "cmd./language": {
        "fa": "زبان رابط fa|en|tr|ar",
        "en": "UI language fa|en|tr|ar",
        "tr": "Arayüz dili fa|en|tr|ar",
        "ar": "لغة الواجهة fa|en|tr|ar",
    },
    "cmd./read": {
        "fa": "خواندن فایل پروژه",
        "en": "Read a project file",
        "tr": "Proje dosyasını oku",
        "ar": "قراءة ملف المشروع",
    },
    "cmd./edit": {
        "fa": "ویرایش فایل با هوش مصنوعی",
        "en": "Edit a file with AI",
        "tr": "AI ile dosya düzenle",
        "ar": "تعديل ملف بالذكاء الاصطناعي",
    },
    "cmd./apply": {
        "fa": "اعمال پیشنهاد ویرایش",
        "en": "Apply pending patch",
        "tr": "Bekleyen yamayı uygula",
        "ar": "تطبيق التصحيح المعلّق",
    },
    "cmd./run": {
        "fa": "اجرای دستور شل",
        "en": "Run a shell command",
        "tr": "Shell komutu çalıştır",
        "ar": "تشغيل أمر شل",
    },
    "cmd./workspaces": {
        "fa": "فهرست فضای کار",
        "en": "List workspaces",
        "tr": "Çalışma alanlarını listele",
        "ar": "قائمة مساحات العمل",
    },
    "cmd./compact": {
        "fa": "خلاصهٔ زمینهٔ نشست",
        "en": "Session context / token summary",
        "tr": "Oturum bağlamı / token özeti",
        "ar": "ملخص سياق الجلسة / الرموز",
    },
    "cmd./context": {
        "fa": "همان /compact",
        "en": "Alias for /compact",
        "tr": "/compact kısayolu",
        "ar": "اختصار لـ /compact",
    },
    "cmd./cost": {
        "fa": "مصرف و سهمیهٔ روزانه",
        "en": "Usage and daily quota",
        "tr": "Kullanım ve günlük kota",
        "ar": "الاستخدام والحصة اليومية",
    },
    "cmd./usage": {
        "fa": "همان /cost",
        "en": "Alias for /cost",
        "tr": "/cost kısayolu",
        "ar": "اختصار لـ /cost",
    },
    "cmd./settings": {
        "fa": "تنظیمات (ویندوز)",
        "en": "Open settings (desktop)",
        "tr": "Ayarlar (masaüstü)",
        "ar": "فتح الإعدادات (سطح المكتب)",
    },
    "cmd./project": {
        "fa": "مسیر ریشهٔ پروژه",
        "en": "Project root path",
        "tr": "Proje kök yolu",
        "ar": "مسار جذر المشروع",
    },
    "cmd./index": {
        "fa": "ایندکس / جستجوی ریپو",
        "en": "Repo index / search",
        "tr": "Depo dizini / arama",
        "ar": "فهرسة / بحث المستودع",
    },
    "cmd./commit": {
        "fa": "پیشنهاد پیام کامیت",
        "en": "Suggest commit message",
        "tr": "Commit mesajı öner",
        "ar": "اقتراح رسالة commit",
    },
    "cmd./pr": {
        "fa": "پیشنهاد عنوان و متن PR",
        "en": "Suggest PR title and body",
        "tr": "PR başlığı ve gövdesi öner",
        "ar": "اقتراح عنوان ونص PR",
    },
    "cmd./config": {
        "fa": "تنظیمات کلیدی",
        "en": "Key CLI configuration",
        "tr": "Temel CLI ayarları",
        "ar": "إعدادات CLI الأساسية",
    },
    "cmd./reset": {
        "fa": "پاک‌کردن تاریخچهٔ این نشست",
        "en": "Clear chat history this session",
        "tr": "Bu oturumun sohbet geçmişini sil",
        "ar": "مسح سجل هذه الجلسة",
    },
    "cmd./diff": {
        "fa": "آخرین اختلاف ویرایش",
        "en": "Last edit diff",
        "tr": "Son düzenleme diff’i",
        "ar": "آخر فرق تعديل",
    },
    "cmd./clear": {
        "fa": "پاک‌کردن صفحه",
        "en": "Clear screen",
        "tr": "Ekranı temizle",
        "ar": "مسح الشاشة",
    },
    "cmd./clean": {
        "fa": "پاک‌کردن صفحه و تاریخچهٔ گفتگو",
        "en": "Clear screen and chat history",
        "tr": "Ekranı ve sohbet geçmişini temizle",
        "ar": "مسح الشاشة وسجل المحادثة",
    },
    "cmd./exit": {"fa": "خروج", "en": "Exit REPL", "tr": "Çıkış", "ar": "خروج"},
    "cmd./quit": {"fa": "خروج", "en": "Exit REPL", "tr": "Çıkış", "ar": "خروج"},
    "ok.cleared": {
        "fa": "صفحه پاک شد.",
        "en": "Screen cleared.",
        "tr": "Ekran temizlendi.",
        "ar": "مُسحت الشاشة.",
    },
    "ok.cleaned": {
        "fa": "صفحه و تاریخچهٔ گفتگو پاک شد.",
        "en": "Screen and chat history cleared.",
        "tr": "Ekran ve sohbet geçmişi temizlendi.",
        "ar": "مُسحت الشاشة وسجل المحادثة.",
    },
    "ok.project_set": {
        "fa": "پوشهٔ پروژه: {path}",
        "en": "Project folder: {path}",
        "tr": "Proje klasörü: {path}",
        "ar": "مجلد المشروع: {path}",
    },
    "warn.bad_project": {
        "fa": "پوشه معتبر نیست: {path}",
        "en": "Not a valid folder: {path}",
        "tr": "Geçerli bir klasör değil: {path}",
        "ar": "مجلد غير صالح: {path}",
    },
    "desk.project_box": {
        "fa": "پوشهٔ کار (پروژه)",
        "en": "Working folder (project)",
        "tr": "Çalışma klasörü (proje)",
        "ar": "مجلد العمل (المشروع)",
    },
    "desk.project_apply": {"fa": "اعمال", "en": "Apply", "tr": "Uygula", "ar": "تطبيق"},
    "desk.project_browse": {
        "fa": "انتخاب…",
        "en": "Browse…",
        "tr": "Gözat…",
        "ar": "استعراض…",
    },
    "desk.project_hint": {
        "fa": "خواندن، نوشتن و @ از این پوشه انجام می‌شود.",
        "en": "Reads, writes, and @ use this folder.",
        "tr": "Okuma, yazma ve @ bu klasörü kullanır.",
        "ar": "القراءة والكتابة و @ تستخدم هذا المجلد.",
    },
}

SLASH_HELP_FA = """\
دستورهای اسلش (داخل REPL):

  /help              فهرست دستورها
  /status            ورود، پلن، سهمیه، API، پروژه
  /model [id]        مدل جاری یا تنظیم مدل (~/.picode/config.json)
  /models            فهرست مدل‌های مجاز
  /permissions       مجوز فایل/شل/SSH/وب: ask | auto | deny
  /perm              همان /permissions
  /ssh               مدیریت اتصالات SSH (list|add|test|default|delete)
  /language [fa|en|tr|ar]  زبان رابط (پیش‌فرض fa)
  /login             ورود دوباره با مرورگر (PKCE)
  /update            بررسی به‌روزرسانی (یا /update install)
  /logout            خروج و پاک‌کردن توکن
  /read <path>       خواندن فایل پروژه
  /edit <path> …     پیشنهاد ویرایش AI (با احترام به /permissions)
  /apply             اعمال آخرین پیشنهاد /edit
  /discard           کنار گذاشتن پیشنهاد
  /run <cmd…>        اجرای شل (با احترام به shell_permissions)
  /compact           خلاصهٔ زمینه / توکن
  /context           همان /compact
  /cost              مصرف و سهمیه روزانه
  /usage             همان /cost
  /project [path]    نمایش یا تنظیم ریشهٔ پروژه
  /workspaces        فهرست فضای کار
  /ws <name>         تعویض فضای کار
  /index [query]     ساخت/جستجوی ایندکس (بدون آرگومان: بازسازی)
  /commit            پیشنهاد پیام کامیت از git
  /pr                پیشنهاد عنوان و متن PR
  /config            تنظیمات کلیدی
  /reset             پاک‌کردن تاریخچهٔ این نشست
  /diff              نمایش آخرین دیف بعد از /edit
  /clear             پاک‌کردن صفحه
  /clean             پاک‌کردن صفحه و تاریخچهٔ گفتگو
  /exit  یا  /quit   خروج

پیام بدون / گفتگو است. گفتگو مگر با /permissions deny در پوشهٔ پروژه فایل می‌سازد و ویرایش می‌کند.
با درخواست شما می‌تواند SSH و جستجوی وب را هم با ابزارهای گفتگو انجام دهد (مجوز جدا).
با @ هنگام نوشتن، فایل از پوشهٔ پروژه پیوست می‌شود.
"""

SLASH_HELP_EN = """\
Slash commands (inside REPL):

  /help              List commands
  /status            Auth, plan, quota, API, project
  /model [id]        Current model or set model (saved in ~/.picode/config.json)
  /models            List allowed models from API
  /permissions       File/shell/SSH/web mode: ask | auto | deny
  /perm              Alias for /permissions
  /ssh               Manage SSH connections (list|add|test|default|delete)
  /language [fa|en|tr|ar]  UI chrome language (default fa)
  /login             Sign in again via browser (PKCE)
  /update            Check PiCode update (or /update install)
  /logout            Sign out and clear token
  /read <path>       Read project file
  /edit <path> …     AI edit suggestion (respects /permissions)
  /apply              Apply last /edit suggestion
  /discard            Discard last /edit suggestion
  /run <cmd…>         Run shell (respects shell_permissions)
  /compact           Session context / token summary
  /context           Alias for /compact
  /cost              Usage and daily quota (from /me)
  /usage             Alias for /cost
  /project [path]    Show or set project root
  /workspaces        List workspaces
  /ws <name>         Switch workspace
  /index [query]     Build/search repo index (no arg: rebuild)
  /commit            Suggest commit message from git status/diff
  /pr                Suggest PR title and body
  /config            Key config (API, model, permissions)
  /reset             Clear chat history this session
  /diff              Show last diff after /edit
  /clear             Clear screen
  /clean             Clear screen and chat history
  /exit  or  /quit   Exit REPL

Messages without / are chat. Chat creates and edits files in the project folder unless file writes are turned off (/permissions deny).
On request, chat can also use SSH and web search tools (separate permissions).
Type @ while composing to attach a file from the project folder.
"""

SLASH_HELP_TR = """\
Slash komutları (REPL içinde):

  /help              Komut listesi
  /status            Oturum, plan, kota, API, proje
  /model [id]        Geçerli model veya model ayarla (~/.picode/config.json)
  /models            İzinli modeller
  /permissions       Dosya/shell/SSH/web: ask | auto | deny
  /perm              /permissions kısayolu
  /ssh               SSH bağlantıları (list|add|test|default|delete)
  /language [fa|en|tr|ar]  Arayüz dili (varsayılan fa)
  /login             Tarayıcıyla yeniden giriş (PKCE)
  /update            Güncelleme kontrolü (veya /update install)
  /logout            Çıkış ve token temizleme
  /read <path>       Proje dosyasını oku
  /edit <path> …     AI düzenleme önerisi (/permissions’a uyar)
  /apply             Son /edit önerisini uygula
  /discard           Öneriyi iptal et
  /run <cmd…>        Shell çalıştır (shell_permissions’a uyar)
  /compact           Oturum bağlamı / token özeti
  /context           /compact kısayolu
  /cost              Kullanım ve günlük kota
  /usage             /cost kısayolu
  /project [path]    Proje kökünü göster veya ayarla
  /workspaces        Çalışma alanlarını listele
  /ws <name>         Çalışma alanı değiştir
  /index [query]     Depo dizini / arama (argümansız: yeniden oluştur)
  /commit            git’ten commit mesajı öner
  /pr                PR başlığı ve gövdesi öner
  /config            Temel ayarlar
  /reset             Bu oturumun sohbet geçmişini sil
  /diff              Son /edit sonrası diff
  /clear             Ekranı temizle
  /clean             Ekranı ve sohbet geçmişini temizle
  /exit  veya  /quit  Çıkış

/ olmadan mesaj sohbettir. /permissions deny olmadıkça sohbet proje klasöründe dosya oluşturur ve düzenler.
İstek üzerine sohbet SSH ve web arama araçlarını da kullanabilir (ayrı izinler).
Yazarken @ ile proje klasöründen dosya eklenir.
"""

SLASH_HELP_AR = """\
أوامر الشرطة المائلة (داخل REPL):

  /help              قائمة الأوامر
  /status            الدخول، الخطة، الحصة، API، المشروع
  /model [id]        النموذج الحالي أو تعيينه (~/.picode/config.json)
  /models            النماذج المسموحة
  /permissions       أذونات الملفات/الشل/SSH/الويب: ask | auto | deny
  /perm              اختصار /permissions
  /ssh               اتصالات SSH (list|add|test|default|delete)
  /language [fa|en|tr|ar]  لغة الواجهة (الافتراضي fa)
  /login             تسجيل الدخول عبر المتصفح (PKCE)
  /update            التحقق من التحديث (أو /update install)
  /logout            تسجيل الخروج ومسح الرمز
  /read <path>       قراءة ملف المشروع
  /edit <path> …     اقتراح تعديل AI (يحترم /permissions)
  /apply             تطبيق آخر اقتراح /edit
  /discard           تجاهل الاقتراح
  /run <cmd…>        تشغيل الشل (يحترم shell_permissions)
  /compact           ملخص سياق الجلسة / الرموز
  /context           اختصار /compact
  /cost              الاستخدام والحصة اليومية
  /usage             اختصار /cost
  /project [path]    عرض أو تعيين جذر المشروع
  /workspaces        قائمة مساحات العمل
  /ws <name>         تبديل مساحة العمل
  /index [query]     فهرسة / بحث المستودع (بدون وسيط: إعادة بناء)
  /commit            اقتراح رسالة commit من git
  /pr                اقتراح عنوان ونص PR
  /config            الإعدادات الأساسية
  /reset             مسح سجل هذه الجلسة
  /diff              عرض آخر diff بعد /edit
  /clear             مسح الشاشة
  /clean             مسح الشاشة وسجل المحادثة
  /exit  أو  /quit   خروج

الرسالة بلا / محادثة. ما لم يكن /permissions deny، تنشئ المحادثة الملفات وتعدّلها في مجلد المشروع.
عند الطلب يمكنها أيضًا استخدام أدوات SSH والبحث على الويب (أذونات منفصلة).
عند الكتابة، @ يرفق ملفًا من مجلد المشروع.
"""

_SLASH_HELP = {
    "fa": SLASH_HELP_FA,
    "en": SLASH_HELP_EN,
    "tr": SLASH_HELP_TR,
    "ar": SLASH_HELP_AR,
}

_UI_LANG_ALIASES = {
    "fa",
    "fa-ir",
    "persian",
    "farsi",
    "فارسی",
    "en",
    "en-us",
    "en-gb",
    "english",
    "tr",
    "tr-tr",
    "tr-istanbul",
    "turkish",
    "türkçe",
    "turkce",
    "ar",
    "ar-sa",
    "ar-eg",
    "arabic",
    "العربية",
}


def normalize_ui_lang(value: object) -> str:
    raw = str(value or "").strip().lower()
    if raw in ("fa", "fa-ir", "persian", "farsi", "فارسی"):
        return "fa"
    if raw in ("en", "en-us", "en-gb", "english"):
        return "en"
    if raw in ("tr", "tr-tr", "tr-istanbul", "turkish", "türkçe", "turkce"):
        return "tr"
    if raw in ("ar", "ar-sa", "ar-eg", "arabic", "العربية"):
        return "ar"
    return DEFAULT_UI_LANG


def get_ui_lang() -> str:
    from picode.api_client import load_config

    return normalize_ui_lang(load_config().get("ui_language"))


def set_ui_lang(lang: str) -> str:
    from picode.api_client import load_config, save_config

    token = str(lang or "").strip().lower()
    if token not in _UI_LANG_ALIASES:
        raise ValueError("Use fa, en, tr, or ar")
    normalized = normalize_ui_lang(token)
    cfg = load_config()
    cfg["ui_language"] = normalized
    save_config(cfg)
    return normalized


def is_rtl() -> bool:
    return get_ui_lang() in ("fa", "ar")


def t(key: str, **kwargs: Any) -> str:
    """Translate a chrome string for the active UI language."""
    lang = get_ui_lang()
    entry = _STRINGS.get(key) or {}
    text = entry.get(lang) or entry.get("en") or key
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, ValueError):
            return text
    return text


def slash_help_text() -> str:
    return _SLASH_HELP.get(get_ui_lang()) or SLASH_HELP_EN


def command_desc(name: str, fallback: str = "") -> str:
    return t(f"cmd.{name}") if f"cmd.{name}" in _STRINGS else fallback


def localized_commands() -> list[tuple[str, str]]:
    from picode.repl_input import SLASH_COMMANDS

    return [(name, command_desc(name, desc)) for name, desc in SLASH_COMMANDS]


def language_choices() -> list[tuple[str, str]]:
    """(code, label) for language pickers — labels follow active UI lang."""
    return [
        ("fa", t("desk.lang_fa")),
        ("en", t("desk.lang_en")),
        ("tr", t("desk.lang_tr")),
        ("ar", t("desk.lang_ar")),
    ]
