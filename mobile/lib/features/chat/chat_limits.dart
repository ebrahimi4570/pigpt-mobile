/// Same window + capacity as web SPA and `/opt/pigpt` API.
/// Never fetch/render a full transcript; always last [kChatMessagePageSize] from the end.
const kChatMessagePageSize = 40;

/// Per-conversation context cap (not daily wallet quota).
/// Estimated tokens = unicode length / 4, matching the API.
const kChatContextCapTokens = 32000;

const kChatFullFa = 'ظرفیت این گفتگو پر شده است. یک گفتگوی جدید شروع کنید.';
const kChatNearFullFa = 'ظرفیت این گفتگو تقریباً پر است.';

int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  return (text.runes.length / 4).ceil();
}
