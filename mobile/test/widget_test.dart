import 'package:flutter_test/flutter_test.dart';
import 'package:pigpt_mobile/core/brand.dart';
import 'package:pigpt_mobile/core/models.dart';
import 'package:pigpt_mobile/core/starter_prompts.dart';
import 'package:pigpt_mobile/core/studio_catalog.dart';
import 'package:pigpt_mobile/core/api_client.dart';

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

  test('SSE event parse token', () {
    final e = SseEvent.parse('event: token\ndata: {"text":"سلام"}');
    expect(e, isNotNull);
    expect(e!.event, 'token');
    expect(e.data['text'], 'سلام');
  });
}
