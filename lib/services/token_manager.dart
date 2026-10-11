import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages API token usage and costs for Groq API
/// Enforces daily limits to prevent unexpected billing
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  // Limits - Adjust these based on your Groq free tier
  static const int DAILY_CHAT_LIMIT = 100;
  static const int MAX_TOKENS_PER_REQUEST = 512; // Reduced from 1024
  static const int MAX_TOKENS_PER_DAY = 50000; // Increased for development

  // Token tracking
  int _tokensUsedToday = 0;
  DateTime? _lastResetDate;
  int _chatsUsedToday = 0;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Load saved state BEFORE the rollover check. On cold start the in-memory
    // date is null, so checking first would wipe the persisted counters on
    // every app launch.
    loadSavedState();
    _checkAndResetDailyLimits();
  }

  void _checkAndResetDailyLimits() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Reset when the last reset happened before today's midnight (i.e. a
    // new calendar day has started).
    if (_lastResetDate == null || _lastResetDate!.isBefore(today)) {
      _resetDailyLimits();
      _lastResetDate = today;
    }
  }

  void _resetDailyLimits() {
    _tokensUsedToday = 0;
    _chatsUsedToday = 0;
    _prefs?.setInt('tokens_used_today', 0);
    _prefs?.setInt('chats_used_today', 0);
    _prefs?.setString('last_reset_date', DateTime.now().toIso8601String());
    debugPrint("🔄 Token & Chat limits reset for new day");
  }

  /// Check if user can make another chat request
  bool canMakeChatRequest() {
    _checkAndResetDailyLimits();
    return _chatsUsedToday < DAILY_CHAT_LIMIT;
  }

  /// Check if request fits within token limits
  bool canMakeTokenRequest(int estimatedTokens) {
    _checkAndResetDailyLimits();
    return (_tokensUsedToday + estimatedTokens) <= MAX_TOKENS_PER_DAY;
  }

  /// Get remaining chats for today
  int getRemainingChats() {
    _checkAndResetDailyLimits();
    return DAILY_CHAT_LIMIT - _chatsUsedToday;
  }

  /// Get remaining tokens for today
  int getRemainingTokens() {
    _checkAndResetDailyLimits();
    return MAX_TOKENS_PER_DAY - _tokensUsedToday;
  }

  /// Record token usage after an API call. Tokens are counted per LLM round
  /// (tool loops make several), but chats are counted once per user message
  /// via [recordChat] so the daily chat limit reflects real usage.
  void recordTokenUsage(int tokensUsed) {
    _tokensUsedToday += tokensUsed;

    _prefs?.setInt('tokens_used_today', _tokensUsedToday);

    debugPrint(
      "📊 Token Usage: $_tokensUsedToday/$MAX_TOKENS_PER_DAY tokens, "
      "Chats: $_chatsUsedToday/$DAILY_CHAT_LIMIT",
    );

    if (_tokensUsedToday >= MAX_TOKENS_PER_DAY - 1000) {
      debugPrint(
        "⚠️ Warning: Only ${getRemainingTokens()} tokens remaining today!",
      );
    }
  }

  /// Count one chat turn (one complete user request, regardless of how many
  /// LLM/tool rounds it took internally).
  void recordChat() {
    _chatsUsedToday += 1;

    _prefs?.setInt('chats_used_today', _chatsUsedToday);

    if (_chatsUsedToday >= DAILY_CHAT_LIMIT - 1) {
      debugPrint(
        "⚠️ Warning: Only ${getRemainingChats()} chat(s) remaining today!",
      );
    }
  }

  /// Load saved state from SharedPreferences
  void loadSavedState() {
    _tokensUsedToday = _prefs?.getInt('tokens_used_today') ?? 0;
    _chatsUsedToday = _prefs?.getInt('chats_used_today') ?? 0;
    final resetDateStr = _prefs?.getString('last_reset_date');
    if (resetDateStr != null) {
      _lastResetDate = DateTime.parse(resetDateStr);
    }
  }

  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    _checkAndResetDailyLimits();
    return {
      'chats_used': _chatsUsedToday,
      'chats_remaining': getRemainingChats(),
      'tokens_used': _tokensUsedToday,
      'tokens_remaining': getRemainingTokens(),
      'daily_chat_limit': DAILY_CHAT_LIMIT,
      'daily_token_limit': MAX_TOKENS_PER_DAY,
      'last_reset': _lastResetDate?.toIso8601String(),
    };
  }

  /// Estimate tokens for a message
  int estimateTokenCount(String text) {
    // Rough estimation: 1 token ≈ 4 characters for English text
    // Add overhead for conversation context
    final baseTokens = (text.length / 4).ceil();
    const contextOverhead = 100; // System prompt and context
    return baseTokens + contextOverhead;
  }

  /// Reset limits manually (for the "Reset Daily Limits" button)
  void resetLimits() {
    _resetDailyLimits();
    // Sync the in-memory rollover date too, otherwise the next
    /// _checkAndResetDailyLimits() pass can fight the manual reset.
    _lastResetDate = DateTime.now();
    debugPrint("🔄 Daily limits manually reset");
  }

  /// Test-only: force-clear all persisted and in-memory state so unit tests
  /// start from a known baseline.
  @visibleForTesting
  Future<void> resetForTesting() async {
    _tokensUsedToday = 0;
    _chatsUsedToday = 0;
    _lastResetDate = null;
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if service is available
  bool isServiceAvailable() {
    return canMakeChatRequest() && canMakeTokenRequest(MAX_TOKENS_PER_REQUEST);
  }

  /// Get status message for UI
  String getStatusMessage() {
    if (!canMakeChatRequest()) {
      return "Daily chat limit reached. Resets at midnight.";
    }
    if (!canMakeTokenRequest(MAX_TOKENS_PER_REQUEST)) {
      return "Daily token limit reached. Resets at midnight.";
    }

    final chatsLeft = getRemainingChats();
    final tokensLeft = getRemainingTokens();

    if (chatsLeft <= 1 || tokensLeft <= 1000) {
      return "⚠️ ${getRemainingChats()} chats, ${(tokensLeft / 1000).toStringAsFixed(1)}k tokens left today";
    }

    return "${getRemainingChats()} chats, ${(tokensLeft / 1000).toStringAsFixed(1)}k tokens remaining";
  }
}
