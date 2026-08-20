import 'package:flutter_test/flutter_test.dart';
import 'package:pigpt_mobile/core/brand.dart';
import 'package:pigpt_mobile/core/models.dart';
import 'package:pigpt_mobile/core/starter_prompts.dart';
import 'package:pigpt_mobile/core/studio_catalog.dart';
import 'package:pigpt_mobile/core/api_client.dart';
import 'package:pigpt_mobile/core/speech.dart';
import 'package:pigpt_mobile/core/live_status.dart';
import 'package:pigpt_mobile/features/chat/chat_screens.dart';

void main() {
  test('brand constants', () {
    expect(PigptBrand.webDisplay, 'PiGPT');
    expect(PigptBrand.apiBase, 'https://pigpt.ir');
    expect(PigptBrand.poweredBy('gpt'), contains('PiGPT'));
  });

  test('starter prompts rotate', () {
    final a = StarterPrompts.pick(count: 4, seed: 1);
    final b = StarterPrompts.pick(count: 4, seed: 2);
    expect(a.length, 4);
    expect(a, isNot(equals(b)));
  });

  test('studio catalog has no admin and includes primary tools', () {
    final ids = StudioCatalog.allTools.map((t) => t.id).toSet();
    expect(ids.contains('image'), isTrue);
    expect(ids.contains('writing'), isTrue);
    expect(ids.contains('media'), isTrue);
    expect(ids.any((id) => id.contains('admin')), isFalse);
  });

  test('UserMe parses wallet fields', () {
    final me = UserMe.fromJson({
      'id': '1',
      'email': 'a@b.com',
      'balance': 10,
      'can_generate': false,
      'free_daily_remaining': 3,
      'free_daily_cap': 20,
    });
    expect(me.canGenerate, isFalse);
    expect(me.freeDailyRemaining, 3);
    expect(me.balance, 10);
  });

  test('UserMe prefers spendable_today and daily_unlimited', () {
    final me = UserMe.fromJson({
      'id': '1',
      'email': 'a@b.com',
      'wallet': {
        'balance': 458152,
        'spendable_today': 458152,
        'daily_tokens_remaining': 458152,
        'daily_unlimited': true,
      },
    });
    expect(me.balance, 458152);
    expect(me.spendableToday, 458152);
    expect(me.dailyTokensRemaining, 458152);
    expect(me.dailyUnlimited, isTrue);
  });

  test('ChatMessage parses attachment_ids', () {
    final m = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'user',
      'content': 'سلام',
      'attachment_ids': ['a1', 'a2'],
    });
    expect(m.attachmentIds, ['a1', 'a2']);
  });

  test('stripPoweredByFooter removes attribution lines', () {
    final raw = 'سلام دنیا\nPiGPT · قدرت‌گرفته از gpt-4';
    expect(stripPoweredByFooter(raw), 'سلام دنیا');
    expect(
      stripPoweredByFooter('پاسخ\nPiGPT قدرت گرفته از مدل gpt-4'),
      'پاسخ',
    );
    expect(stripPoweredByFooter('**bold**'), '**bold**');
  });

  test('speech plainText strips markdown urls and powered-by', () {
    expect(SpeechService.plainText('**سلام** https://x.com/a'), 'سلام');
    expect(
      SpeechService.plainText('متن\nPiGPT قدرت گرفته از مدل x'),
      'متن',
    );
  });

  test('SSE event parse token', () {
    final e = SseEvent.parse('event: token\ndata: {"text":"سلام"}');
    expect(e, isNotNull);
    expect(e!.event, 'token');
    expect(e.data['text'], 'سلام');
  });

  test('live status in-progress labels use در حال + مصدر', () {
    expect(const LiveStatus(phase: LivePhase.thinking).label, 'در حال فکر کردن');
    expect(const LiveStatus(phase: LivePhase.writing).label, 'در حال نوشتن');
    expect(const LiveStatus(phase: LivePhase.searching).label, 'در حال جستجو');
    expect(const LiveStatus(phase: LivePhase.listening).label, 'در حال گوش دادن');
    expect(
      const LiveStatus(phase: LivePhase.transcribing).label,
      'در حال تبدیل به متن',
    );
    expect(const LiveStatus(phase: LivePhase.waiting).label, 'در انتظار پاسخ');
    expect(const LiveStatus(phase: LivePhase.imaging).label, 'در حال ساخت تصویر');
    expect(const LiveStatus(phase: LivePhase.uploading).label, 'در حال آپلود');
    expect(const LiveStatus(phase: LivePhase.ready).label, 'آماده');
    expect(const LiveStatus(phase: LivePhase.ready).isActive, isFalse);
    expect(const LiveStatus(phase: LivePhase.thinking).isActive, isTrue);
  });
}
