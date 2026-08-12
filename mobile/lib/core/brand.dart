/// PiGPT brand constants — aligned with web brand.ts / Brand Bible.
class PigptBrand {
  static const webName = 'pigpt';
  static const cliName = 'picode';
  static const webDisplay = 'PiGPT';
  static const cliDisplay = 'PiCode';
  static const taglineFa = 'پلتفرم هوش مصنوعی فارسی';
  /// Real product mark (same asset as pigpt.ir SPA `brand-pi.png`).
  static const logoAsset = 'assets/brand/brand-pi.png';
  static const logoAssetHiRes = 'assets/brand/brand-pi-512.png';
  static const apiBase = 'https://pigpt.ir';
  static const apiPrefix = '/api/v1';
  static const privacyUrl = 'https://pigpt.ir/privacy';
  static const webUrl = 'https://pigpt.ir';
  /// Custom-scheme OAuth return (must match Android intent-filter + API allowlist).
  static const oauthCallback = 'pigpt://auth/callback';
  /// Optional https App Link return (assetlinks.json on pigpt.ir).
  static const oauthAppLinkCallback = 'https://pigpt.ir/app/auth/callback';
  static const downloadsUrl = 'https://pigpt.ir/downloads/picode/';
  static const installUnix =
      'curl -fsSL https://pigpt.ir/install-picode.sh | bash';
  static const installWindows =
      'irm https://pigpt.ir/install-picode.ps1 | iex';
  static const installWindowsAlt =
      'powershell -ExecutionPolicy Bypass -Command "irm https://pigpt.ir/install-picode.ps1 | iex"';
  static const clientHeaderPrefix = 'flutter';

  static String poweredBy(String model) =>
      '$webDisplay · قدرت‌گرفته از $model';

  static const loadingWriting = 'PiGPT در حال نوشتن…';
  static const loadingAgent = 'ایجنت PiGPT در حال کار…';
  static const readyWith = 'آماده‌شده با PiGPT';
}
