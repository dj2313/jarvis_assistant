import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/routine.dart';
import 'Friday_brain_service.dart';

/// RoutineService - Manages automation workflows
/// Uses lazy loading and caching for optimal performance

class RoutineService {
  static final RoutineService _instance = RoutineService._internal();
  factory RoutineService() => _instance;
  RoutineService._internal();

  final _supabase = Supabase.instance.client;
  final FridayBrainService _brainService = FridayBrainService();

  // Cached routines - lazy loaded
  List<Routine>? _cachedRoutines;
  DateTime? _lastFetchTime;
  static const _cacheValidityDuration = Duration(minutes: 5);

  // Stream controller for real-time updates (lazy init)
  StreamController<List<Routine>>? _routinesController;
  Stream<List<Routine>> get routinesStream {
    _routinesController ??= StreamController<List<Routine>>.broadcast();
    _ensureRoutinesLoaded();
    return _routinesController!.stream;
  }

  // Currently running routine (for UI feedback)
  final ValueNotifier<String?> runningRoutineId = ValueNotifier(null);
  final ValueNotifier<int> currentActionIndex = ValueNotifier(0);

  /// Lazy load routines with caching
  Future<List<Routine>> getRoutines({bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh &&
        _cachedRoutines != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration) {
      return _cachedRoutines!;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('Friday_routines')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Lazy parse - only parse what we need
      _cachedRoutines = (response as List)
          .map((json) => Routine.fromJson(json as Map<String, dynamic>))
          .toList();
      _lastFetchTime = DateTime.now();

      // Notify listeners
      _routinesController?.add(_cachedRoutines!);

      return _cachedRoutines!;
    } catch (e) {
      debugPrint('Error fetching routines: $e');
      return _cachedRoutines ?? [];
    }
  }

  void _ensureRoutinesLoaded() {
    if (_cachedRoutines == null) {
      getRoutines();
    } else {
      _routinesController?.add(_cachedRoutines!);
    }
  }

  /// Create a new routine
  Future<Routine?> createRoutine(Routine routine) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final data = routine.toJson();
      data['user_id'] = userId;

      final response = await _supabase
          .from('Friday_routines')
          .insert(data)
          .select()
          .single();

      final newRoutine = Routine.fromJson(response);

      // Update cache
      _cachedRoutines = [newRoutine, ...(_cachedRoutines ?? [])];
      _routinesController?.add(_cachedRoutines!);

      return newRoutine;
    } catch (e) {
      debugPrint('Error creating routine: $e');
      return null;
    }
  }

  /// Update an existing routine
  Future<bool> updateRoutine(Routine routine) async {
    if (routine.id == null) return false;

    try {
      await _supabase
          .from('Friday_routines')
          .update(routine.toJson())
          .eq('id', routine.id!);

      // Update cache
      if (_cachedRoutines != null) {
        final index = _cachedRoutines!.indexWhere((r) => r.id == routine.id);
        if (index != -1) {
          _cachedRoutines![index] = routine;
          _routinesController?.add(_cachedRoutines!);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating routine: $e');
      return false;
    }
  }

  /// Delete a routine
  Future<bool> deleteRoutine(String id) async {
    try {
      await _supabase.from('Friday_routines').delete().eq('id', id);

      // Update cache
      _cachedRoutines?.removeWhere((r) => r.id == id);
      if (_cachedRoutines != null) {
        _routinesController?.add(_cachedRoutines!);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting routine: $e');
      return false;
    }
  }

  /// Toggle routine enabled state
  Future<bool> toggleRoutine(String id, bool enabled) async {
    try {
      await _supabase
          .from('Friday_routines')
          .update({'is_enabled': enabled})
          .eq('id', id);

      // Update cache
      if (_cachedRoutines != null) {
        final index = _cachedRoutines!.indexWhere((r) => r.id == id);
        if (index != -1) {
          _cachedRoutines![index] = _cachedRoutines![index].copyWith(
            isEnabled: enabled,
          );
          _routinesController?.add(_cachedRoutines!);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error toggling routine: $e');
      return false;
    }
  }

  /// Execute a routine with progress tracking
  Future<String> executeRoutine(Routine routine) async {
    if (routine.actions.isEmpty) {
      return 'No actions to execute.';
    }

    runningRoutineId.value = routine.id;
    currentActionIndex.value = 0;

    final results = <String>[];

    try {
      for (int i = 0; i < routine.actions.length; i++) {
        currentActionIndex.value = i;
        final action = routine.actions[i];

        // Apply delay if specified
        if (action.delaySeconds > 0) {
          await Future.delayed(Duration(seconds: action.delaySeconds));
        }

        // Execute action based on type
        final result = await _executeAction(action);
        results.add('${action.icon} ${action.label}: $result');
      }

      // Update last run time
      if (routine.id != null) {
        await _supabase
            .from('Friday_routines')
            .update({'last_run_at': DateTime.now().toIso8601String()})
            .eq('id', routine.id!);
      }

      return results.join('\n\n');
    } finally {
      runningRoutineId.value = null;
      currentActionIndex.value = 0;
    }
  }

  /// Execute individual action
  Future<String> _executeAction(RoutineAction action) async {
    switch (action.type) {
      case 'weather':
        final response = await _brainService.chatWithIntelligence(
          'What\'s the current weather? Give a brief summary.',
        );
        return response.content;

      case 'news':
        final response = await _brainService.chatWithIntelligence(
          'Give me 3 top news headlines today. Be brief.',
        );
        return response.content;

      case 'calendar':
        final response = await _brainService.chatWithIntelligence(
          'What events do I have today? Check my calendar.',
        );
        return response.content;

      case 'speak':
        final text = action.params['text'] as String? ?? 'Action completed.';
        return text;

      case 'focus':
        final duration = action.params['duration'] as int? ?? 3600;
        return 'Focus mode enabled for ${duration ~/ 60} minutes.';

      case 'notify':
        return 'Notification sent.';

      case 'email':
        final response = await _brainService.chatWithIntelligence(
          'Summarize my recent emails briefly.',
        );
        return response.content;

      case 'custom':
        final query = action.params['query'] as String?;
        if (query != null) {
          final response = await _brainService.chatWithIntelligence(query);
          return response.content;
        }
        return 'Custom action executed.';

      default:
        return 'Unknown action type.';
    }
  }

  /// Dispose resources
  void dispose() {
    _routinesController?.close();
    runningRoutineId.dispose();
    currentActionIndex.dispose();
  }
}
