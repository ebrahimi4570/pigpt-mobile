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
  static String billingInvoicePdf(String id) =>
      '/billing/payments/$id/invoice.pdf';

  static const chatTranscribe = '/chat/transcribe';
  static const messageDrafts = '/message-drafts';

  static const proRouter = '/pro/router';
  static const proQualityGate = '/pro/quality-gate';
  static const proImageBatch = '/pro/image/batch';
  static const proImageEdit = '/pro/image/edit';
  static const proBrandKit = '/pro/brand-kit';
  static const proWritingSeo = '/pro/writing/seo';
  static const proWritingDiff = '/pro/writing/diff';
  static const proWritingExport = '/pro/writing/export';

  static const studiosImagePresets = '/studios/image/presets';
  static const studiosImageGenerate = '/studios/image/generate';
  static const studiosImageJobs = '/studios/image/jobs';
  static const studiosWritingTemplates = '/studios/writing/templates';
  static const studiosWritingRun = '/studios/writing/run';
  static const studiosDocuments = '/studios/documents';
  static String studiosDocument(String id) => '/studios/documents/$id';
  static const studiosRagChat = '/studios/rag/chat';
  static const studiosMediaFlags = '/studios/media/flags';
  static const studiosMediaOcr = '/studios/media/ocr';
  static const studiosMediaTts = '/studios/media/tts';
  static const studiosMediaStt = '/studios/media/stt';
  static const studiosMediaImageEdit = '/studios/media/image-edit';
  static const studiosDataAnalyzeCsv = '/studios/data/analyze-csv';
  static const studiosCodingReview = '/studios/coding/review';
  static const studiosCodingScaffold = '/studios/coding/scaffold';
  static const studiosCodingOpenapi = '/studios/coding/openapi-mock';
  static const studiosEduQuiz = '/studios/edu/quiz';
  static const studiosEduInterview = '/studios/edu/interview';
  static const studiosAlgorithmsOptimize = '/studios/algorithms/optimize-prompt';
  static const studiosAlgorithmsScore = '/studios/algorithms/quality-score';
  static const studiosAlgorithmsIndustries = '/studios/algorithms/industries';
  static const studiosAlgorithmsWizard = '/studios/algorithms/wizard';
  static const studiosAlgorithmsPipeline = '/studios/algorithms/pipeline';
  static const studiosBizInvoice = '/studios/biz/invoice-text';
  static const studiosBizSupport = '/studios/biz/support';
  static const studiosBizDailyReport = '/studios/biz/daily-report';
  static const studiosBizChannels = '/studios/biz/channels';
  static const studiosAssistantRoles = '/studios/assistant/roles';
  static const studiosAssistantProjects = '/studios/assistant/projects';
  static const studiosAssistantMultiAgent = '/studios/assistant/multi-agent';
  static const studiosAssistantSchedule = '/studios/assistant/schedule';
  static const studiosSafetyFilter = '/studios/safety/filter';
  static const studiosSafetyAb = '/studios/safety/ab';
  static const studiosTeam = '/studios/team';
  static const studiosMarketplace = '/studios/marketplace';
  static const studiosGallery = '/studios/gallery';
  static String sharePublic(String token) => '/share/$token';
  static String supportTicket(String id) => '/support/tickets/$id';

  static const supportTickets = '/support/tickets';
  static const referral = '/referral';
  static const usage = '/usage';
  static const capabilities = '/capabilities';
}
