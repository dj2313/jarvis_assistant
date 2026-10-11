import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:friday_assistant/services/token_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenManager tm;

  setUp(() async {
    tm = TokenManager();
    // Install the mock store before resetForTesting() touches getInstance().
    SharedPreferences.setMockInitialValues({});
    await tm.resetForTesting();
  });

  group('cold start', () {
    test('fresh install starts with full allowance', () async {
      SharedPreferences.setMockInitialValues({});
      await tm.resetForTesting();
      await tm.initialize();

      expect(tm.canMakeChatRequest(), isTrue);
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT);
      expect(tm.getRemainingTokens(), TokenManager.MAX_TOKENS_PER_DAY);
    });

    test('same-day usage SURVIVES an app restart (initialize does not wipe)',
        () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'chats_used_today': 40,
        'tokens_used_today': 12000,
        'last_reset_date': now.toIso8601String(),
      });
      await tm.resetForTesting();
      await tm.initialize();

      // Regression: initialize() used to run the rollover check before
      // loadSavedState(), wiping persisted counters on every cold start.
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT - 40);
      expect(tm.getRemainingTokens(), TokenManager.MAX_TOKENS_PER_DAY - 12000);
    });
  });

  group('midnight rollover', () {
    test('yesterday usage resets at initialize (new calendar day)', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'chats_used_today': 99,
        'tokens_used_today': 49999,
        'last_reset_date': yesterday.toIso8601String(),
      });
      await tm.resetForTesting();
      await tm.initialize();

      // Regression: old condition required 2+ days, so limits stuck around
      // an extra day instead of resetting at midnight.
      expect(tm.canMakeChatRequest(), isTrue);
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT);
      expect(tm.getRemainingTokens(), TokenManager.MAX_TOKENS_PER_DAY);
    });
  });

  group('manual reset ("Reset Daily Limits" button)', () {
    test('resetLimits restores allowance, syncs date, and persists', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'chats_used_today': 100,
        'tokens_used_today': 50000,
        'last_reset_date': now.toIso8601String(),
      });
      await tm.resetForTesting();
      await tm.initialize();
      expect(tm.canMakeChatRequest(), isFalse);

      tm.resetLimits();

      expect(tm.canMakeChatRequest(), isTrue);
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT);
      expect(tm.getRemainingTokens(), TokenManager.MAX_TOKENS_PER_DAY);

      // The reset must survive re-initialization (next app launch/request).
      await tm.initialize();
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT);
      expect(tm.canMakeChatRequest(), isTrue);
    });

    test('usage stats reflect reset immediately', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'chats_used_today': 100,
        'tokens_used_today': 40000,
        'last_reset_date': now.toIso8601String(),
      });
      await tm.resetForTesting();
      await tm.initialize();

      tm.resetLimits();

      final stats = tm.getUsageStats();
      expect(stats['chats_used'], 0);
      expect(stats['tokens_used'], 0);
      expect(stats['chats_remaining'], TokenManager.DAILY_CHAT_LIMIT);
      expect(
        stats['tokens_remaining'],
        TokenManager.MAX_TOKENS_PER_DAY,
      );
    });
  });

  group('usage counting', () {
    test('recordTokenUsage counts tokens only, not chats', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'last_reset_date': now.toIso8601String(),
      });
      await tm.resetForTesting();
      await tm.initialize();

      // Simulate a 3-round tool loop for ONE user message.
      tm.recordTokenUsage(300);
      tm.recordTokenUsage(400);
      tm.recordTokenUsage(250);
      tm.recordChat();

      // Regression: chats used to increment per round (3 extra).
      expect(tm.getRemainingChats(), TokenManager.DAILY_CHAT_LIMIT - 1);
      expect(tm.getRemainingTokens(), TokenManager.MAX_TOKENS_PER_DAY - 950);
    });

    test('limits actually block when exhausted', () async {
      SharedPreferences.setMockInitialValues({});
      await tm.resetForTesting();
      await tm.initialize();

      for (var i = 0; i < TokenManager.DAILY_CHAT_LIMIT; i++) {
        tm.recordChat();
      }
      expect(tm.canMakeChatRequest(), isFalse);
      expect(tm.getStatusMessage(), contains('limit reached'));

      // And the button unblocks it.
      tm.resetLimits();
      expect(tm.canMakeChatRequest(), isTrue);
    });
  });
}
