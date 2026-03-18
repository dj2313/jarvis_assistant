/// Routine Model - Represents an automated workflow
/// Uses efficient JSON serialization for Supabase storage

class RoutineAction {
  final String
  type; // 'weather', 'news', 'calendar', 'speak', 'notify', 'custom'
  final String label;
  final Map<String, dynamic> params;
  final int delaySeconds;

  const RoutineAction({
    required this.type,
    required this.label,
    this.params = const {},
    this.delaySeconds = 0,
  });

  // Lazy JSON parsing - only when needed
  factory RoutineAction.fromJson(Map<String, dynamic> json) {
    return RoutineAction(
      type: json['type'] as String? ?? 'custom',
      label: json['label'] as String? ?? 'Action',
      params: json['params'] as Map<String, dynamic>? ?? {},
      delaySeconds: json['delay_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'params': params,
    'delay_seconds': delaySeconds,
  };

  // Icon mapping for UI (cached)
  static const Map<String, String> _iconMap = {
    'weather': '🌤️',
    'news': '📰',
    'calendar': '📅',
    'speak': '🗣️',
    'notify': '🔔',
    'email': '📧',
    'focus': '🎯',
    'custom': '⚡',
  };

  String get icon => _iconMap[type] ?? '⚡';
}

class Routine {
  final String? id;
  final String name;
  final String? description;
  final String trigger; // 'time', 'manual', 'location', 'event'
  final Map<String, dynamic> triggerConfig;
  final List<RoutineAction> actions;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? lastRunAt;

  const Routine({
    this.id,
    required this.name,
    this.description,
    required this.trigger,
    this.triggerConfig = const {},
    required this.actions,
    this.isEnabled = true,
    this.createdAt,
    this.lastRunAt,
  });

  // Lazy factory with minimal parsing
  factory Routine.fromJson(Map<String, dynamic> json) {
    // Parse actions lazily
    final actionsList = json['actions'] as List<dynamic>? ?? [];

    return Routine(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? 'Untitled Routine',
      description: json['description'] as String?,
      trigger: json['trigger'] as String? ?? 'manual',
      triggerConfig: json['trigger_config'] as Map<String, dynamic>? ?? {},
      actions: actionsList
          .map((a) => RoutineAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      isEnabled: json['is_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastRunAt: json['last_run_at'] != null
          ? DateTime.tryParse(json['last_run_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'trigger': trigger,
    'trigger_config': triggerConfig,
    'actions': actions.map((a) => a.toJson()).toList(),
    'is_enabled': isEnabled,
  };

  // Copyable for immutable updates
  Routine copyWith({
    String? id,
    String? name,
    String? description,
    String? trigger,
    Map<String, dynamic>? triggerConfig,
    List<RoutineAction>? actions,
    bool? isEnabled,
    DateTime? lastRunAt,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trigger: trigger ?? this.trigger,
      triggerConfig: triggerConfig ?? this.triggerConfig,
      actions: actions ?? this.actions,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }

  // Computed properties (cached on first access via const)
  String get triggerIcon {
    switch (trigger) {
      case 'time':
        return '⏰';
      case 'location':
        return '📍';
      case 'event':
        return '📌';
      default:
        return '👆';
    }
  }

  String get triggerLabel {
    switch (trigger) {
      case 'time':
        final time = triggerConfig['time'] as String?;
        return time ?? 'Scheduled';
      case 'location':
        return triggerConfig['location'] as String? ?? 'Location';
      case 'event':
        return triggerConfig['event'] as String? ?? 'Event';
      default:
        return 'Manual';
    }
  }
}

/// Preset routines for quick setup
class RoutinePresets {
  static const List<Routine> presets = [
    Routine(
      name: 'Good Morning',
      description: 'Start your day with weather, news & calendar',
      trigger: 'time',
      triggerConfig: {'time': '07:00'},
      actions: [
        RoutineAction(type: 'weather', label: 'Check Weather'),
        RoutineAction(type: 'news', label: 'Top Headlines', delaySeconds: 2),
        RoutineAction(
          type: 'calendar',
          label: 'Today\'s Events',
          delaySeconds: 2,
        ),
      ],
    ),
    Routine(
      name: 'Focus Mode',
      description: 'Minimize distractions for deep work',
      trigger: 'manual',
      actions: [
        RoutineAction(
          type: 'focus',
          label: 'Enable DND',
          params: {'duration': 7200},
        ),
        RoutineAction(
          type: 'speak',
          label: 'Confirmation',
          params: {
            'text': 'Focus mode activated. I\'ll hold your notifications.',
          },
        ),
      ],
    ),
    Routine(
      name: 'Evening Recap',
      description: 'Review your day before winding down',
      trigger: 'time',
      triggerConfig: {'time': '21:00'},
      actions: [
        RoutineAction(type: 'calendar', label: 'Tomorrow\'s Preview'),
        RoutineAction(
          type: 'notify',
          label: 'Summary Notification',
          delaySeconds: 3,
        ),
      ],
    ),
  ];
}
