import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'policy_engine.dart';

class PendingConfirmation {
  final String token;
  final String toolName;
  final Map<String, dynamic> args;
  final PolicyDecision decision;
  final DateTime createdAt;
  final Completer<bool> completer;

  PendingConfirmation({
    required this.token,
    required this.toolName,
    required this.args,
    required this.decision,
  }) : createdAt = DateTime.now(),
       completer = Completer<bool>();

  bool get isExpired => DateTime.now().difference(createdAt).inSeconds > 60;

  Future<bool> get result => completer.future;
}

class PermissionGuard {
  final Map<String, PendingConfirmation> _pending = {};
  final Duration confirmationTimeout;

  PermissionGuard({this.confirmationTimeout = const Duration(seconds: 60)});

  String createConfirmation({
    required String toolName,
    required Map<String, dynamic> args,
    required PolicyDecision decision,
  }) {
    final token = const Uuid().v4();
    final confirmation = PendingConfirmation(
      token: token,
      toolName: toolName,
      args: args,
      decision: decision,
    );

    _pending[token] = confirmation;
    debugPrint('PermissionGuard: Created confirmation $token for $toolName');

    // Auto-expire after timeout
    Timer(confirmationTimeout, () {
      if (_pending.containsKey(token) &&
          !_pending[token]!.completer.isCompleted) {
        debugPrint('PermissionGuard: Confirmation $token expired');
        _pending[token]!.completer.complete(false);
        _pending.remove(token);
      }
    });

    return token;
  }

  bool approve(String token) {
    final confirmation = _pending.remove(token);
    if (confirmation == null) {
      debugPrint('PermissionGuard: Token $token not found');
      return false;
    }

    if (confirmation.isExpired) {
      debugPrint('PermissionGuard: Token $token expired');
      return false;
    }

    if (!confirmation.completer.isCompleted) {
      confirmation.completer.complete(true);
      debugPrint('PermissionGuard: Token $token approved');
      return true;
    }

    return false;
  }

  bool cancel(String token) {
    final confirmation = _pending.remove(token);
    if (confirmation == null) return false;

    if (!confirmation.completer.isCompleted) {
      confirmation.completer.complete(false);
      debugPrint('PermissionGuard: Token $token cancelled');
      return true;
    }

    return false;
  }

  Future<bool> waitForConfirmation(String token) async {
    final confirmation = _pending[token];
    if (confirmation == null) return false;

    try {
      return await confirmation.result.timeout(confirmationTimeout);
    } on TimeoutException {
      _pending.remove(token);
      return false;
    }
  }

  PendingConfirmation? get(String token) {
    return _pending[token];
  }

  List<PendingConfirmation> get pendingConfirmations =>
      _pending.values.where((c) => !c.isExpired).toList();

  int get pendingCount => _pending.length;

  void clear() {
    for (final confirmation in _pending.values) {
      if (!confirmation.completer.isCompleted) {
        confirmation.completer.complete(false);
      }
    }
    _pending.clear();
  }

  void removeExpired() {
    final expiredTokens = _pending.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final token in expiredTokens) {
      final confirmation = _pending.remove(token);
      if (confirmation != null && !confirmation.completer.isCompleted) {
        confirmation.completer.complete(false);
      }
    }
  }
}
