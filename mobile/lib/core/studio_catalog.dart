import '../core/models.dart';

/// Studio catalog mirrored from web `nav.ts` (consumer only — no admin).
class StudioCatalog {
  static const categories = <StudioCategoryDef>[
    StudioCategoryDef(
      id: 'content',
      label: 'تولید محتوا',
      description: 'تصویر، نوشتار و اسناد — از ایده تا خروجی آماده انتشار.',
      accent: 'teal',
      tools: [
        StudioToolDef(
          id: 'image',
          href: '/app/image',
          label: 'استودیوی تصویر',
          blurb: 'تولید، ماسک، بچ و کیت برند روی بوم کار.',
          capability: 'image_studio',
          categoryId: 'content',
          routeName: 'studio-image',
        ),
        StudioToolDef(
          id: 'writing',
          href: '/app/writing',
          label: 'استودیوی نوشتن',
          blurb: 'قالب‌ها، SEO و پیش‌نویس قابل ویرایش.',
          capability: 'writing_studio',
          categoryId: 'content',
          routeName: 'studio-writing',
        ),
        StudioToolDef(
          id: 'documents',
          href: '/app/documents',
          label: 'اسناد و دانش',
          blurb: 'آپلود، پرسش با استناد و خروجی قابل چاپ.',
          capability: 'document_rag',
          categoryId: 'content',
          routeName: 'studio-documents',
        ),
        StudioToolDef(
          id: 'algorithms',
          href: '/app/algorithms',
          label: 'الگوریتم‌ها',
          blurb: 'ویزارد صنعت، پایپلاین ایده و بهینه‌سازی پرامپت.',
          capability: 'algorithms_studio',
          categoryId: 'content',
          secondary: true,
          routeName: 'studio-algorithms',
        ),
      ],
    ),
    StudioCategoryDef(
      id: 'media',
      label: 'رسانه',
      description: 'OCR، صدا و ویرایش چندرسانه‌ای.',
      accent: 'sky',
      tools: [
        StudioToolDef(
          id: 'media',
          href: '/app/media',
          label: 'استودیوی رسانه',
          blurb: 'OCR، TTS، STT و ویرایش تصویر.',
          capability: 'media_studio',
          categoryId: 'media',
          routeName: 'studio-media',
        ),
      ],
    ),
    StudioCategoryDef(
      id: 'data-code',
      label: 'داده و کد',
      description: 'تحلیل داده، کدنویسی و اتوماسیون گردش‌کار.',
      accent: 'cyan',
      tools: [
        StudioToolDef(
          id: 'analytics',
          href: '/app/analytics',
          label: 'داده و گزارش',
          blurb: 'CSV، پیوت و گزارش.',
          capability: 'analytics_studio',
          categoryId: 'data-code',
          routeName: 'studio-analytics',
        ),
        StudioToolDef(
          id: 'coding',
          href: '/app/coding',
          label: 'کدنویسی',
          blurb: 'بازبینی کد و اسکفولد سبک.',
          capability: 'coding_studio',
          categoryId: 'data-code',
          routeName: 'studio-coding',
        ),
        StudioToolDef(
          id: 'automation',
          href: '/app/automation',
          label: 'اتوماسیون',
          blurb: 'ورکفلو سطح کاربر.',
          capability: 'automation_studio',
          categoryId: 'data-code',
          routeName: 'studio-automation',
        ),
      ],
    ),
    StudioCategoryDef(
      id: 'business',
      label: 'کسب‌وکار',
      description: 'عملیات فروش، پشتیبانی، آموزش و رشد تیم.',
      accent: 'emerald',
      tools: [
        StudioToolDef(
          id: 'biz',
          href: '/app/biz',
          label: 'کسب‌وکار ایران',
          blurb: 'فاکتور، پشتیبانی و گزارش روزانه.',
          capability: 'biz_studio',
          categoryId: 'business',
          routeName: 'studio-biz',
        ),
        StudioToolDef(
          id: 'assistant',
          href: '/app/assistant',
          label: 'دستیار پروژه‌ای',
          blurb: 'پروژه‌ها و چندایجنت روی یک موضوع.',
          capability: 'assistant_studio',
          categoryId: 'business',
          routeName: 'studio-assistant',
        ),
        StudioToolDef(
          id: 'edu',
          href: '/app/edu',
          label: 'آموزش',
          blurb: 'آزمون و شبیه‌سازی مصاحبه.',
          capability: 'edu_studio',
          categoryId: 'business',
          secondary: true,
          routeName: 'studio-edu',
        ),
        StudioToolDef(
          id: 'growth',
          href: '/app/growth',
          label: 'ایمنی و رشد',
          blurb: 'فیلتر ایمنی، A/B و گالری.',
          capability: 'growth_studio',
          categoryId: 'business',
          secondary: true,
          routeName: 'studio-growth',
        ),
        StudioToolDef(
          id: 'workspace',
          href: '/app/workspace',
          label: 'فضای کاری سازمان',
          blurb: 'نقش، سهمیه و دعوت تیم.',
          capability: 'workspace_studio',
          categoryId: 'business',
          secondary: true,
          routeName: 'studio-workspace',
        ),
      ],
    ),
  ];

  static List<StudioToolDef> get allTools =>
      categories.expand((c) => c.tools).toList();

  /// Primary hub tools (same as web PRIMARY_HREFS).
  static const primaryIds = {'image', 'writing', 'media'};
}
