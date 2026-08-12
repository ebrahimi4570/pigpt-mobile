class ApiPaths {
  static const authMethods = '/auth/methods';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const resendVerification = '/auth/resend-verification';
  static const verifyEmail = '/auth/verify-email';
  static const googleStart = '/auth/google/start';
  static const cliDeviceConfirm = '/auth/cli/device/confirm';

  static const me = '/me';
  static const meSettings = '/me/settings';
  static const meModelPrefs = '/me/model-prefs';
  static const meLogoutAll = '/me/logout-all';
  static const meExport = '/me/export';

  static const models = '/models';
  static const chatTemplates = '/chat/templates';
  static const conversations = '/conversations';
  static const conversationsSearch = '/conversations/search';
  static const conversationsArchiveAll = '/conversations/archive-all';
  static const uploads = '/uploads';

  static String conversation(String id) => '/conversations/$id';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static String conversationRegenerate(String id) =>
      '/conversations/$id/regenerate';
  static String messageEdit(String id, String messageId) =>
      '/conversations/$id/messages/$messageId/edit';
  static String conversationShare(String id) => '/conversations/$id/share';

  static const agentMissions = '/agent/missions';
  static String agentMission(String id) => '/agent/missions/$id';
  static String agentMissionNext(String id) => '/agent/missions/$id/next';
  static String agentMissionComplete(String id) =>
      '/agent/missions/$id/complete';
  static String agentMissionConfirm(String id) =>
      '/agent/missions/$id/confirm';
  static String agentMissionToolFile(String id) =>
      '/agent/missions/$id/tools/file';
  static String agentMissionToolImage(String id) =>
      '/agent/missions/$id/tools/image';
  static String agentMissionToolQuickStart(String id) =>
      '/agent/missions/$id/tools/quick-start';

  static const quickStartCards = '/quick-start/cards';
  static String quickStartCard(String id) => '/quick-start/cards/$id';
  static const quickStartHistory = '/quick-start/history';
  static const quickStartRun = '/quick-start/run';
  static String quickStartJob(String id) => '/quick-start/jobs/$id';

  static const billingPlans = '/billing/plans';
  static const billingPlansCompare = '/billing/plans/compare';
  static const billingTokenPackages = '/billing/token-packages';
  static const billingWallet = '/billing/wallet';
  static const billingTokenLedger = '/billing/token-ledger';
  static const billingPayments = '/billing/payments';
  static const billingPaymentsMe = '/billing/payments/me';

  static const proRouter = '/pro/router';
  static const proQualityGate = '/pro/quality-gate';

  static const studiosImagePresets = '/studios/image/presets';
  static const studiosImageGenerate = '/studios/image/generate';
  static const studiosWritingTemplates = '/studios/writing/templates';
  static const studiosWritingRun = '/studios/writing/run';
  static const studiosMediaFlags = '/studios/media/flags';
  static const studiosMediaOcr = '/studios/media/ocr';
  static const studiosMediaTts = '/studios/media/tts';
  static const studiosMediaStt = '/studios/media/stt';
  static const studiosDataAnalyzeCsv = '/studios/data/analyze-csv';
  static const studiosCodingReview = '/studios/coding/review';
  static const studiosCodingScaffold = '/studios/coding/scaffold';
  static const studiosEduQuiz = '/studios/edu/quiz';
  static const studiosEduInterview = '/studios/edu/interview';
  static const studiosGallery = '/studios/gallery';

  static const supportTickets = '/support/tickets';
  static const referral = '/referral';
  static const usage = '/usage';
  static const capabilities = '/capabilities';
}
