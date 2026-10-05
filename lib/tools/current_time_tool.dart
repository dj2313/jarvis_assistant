import 'friday_tool.dart';
import '../agent/agent_models.dart';

class CurrentTimeTool extends FridayTool {
  @override
  String get name => 'current_time';

  @override
  String get description =>
      'Returns the current local time and date. Use this when the user asks about the current time, date, day, or wants to know what time it is.';

  @override
  int get riskLevel => 0;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'format': {
        'type': 'string',
        'description':
            'Optional time format: "12h" for 12-hour, "24h" for 24-hour, "date" for date only, "full" for date and time',
      },
    },
    'required': [],
  };

  @override
  List<Map<String, dynamic>> get groqToolDefinition => [
    {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': inputSchema,
      },
    },
  ];

  String _formatTime(DateTime now, String format) {
    switch (format) {
      case '12h':
        final hour = now.hour > 12
            ? now.hour - 12
            : (now.hour == 0 ? 12 : now.hour);
        final ampm = now.hour >= 12 ? 'PM' : 'AM';
        return '$hour:${now.minute.toString().padLeft(2, '0')} $ampm';
      case '24h':
        return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      case 'date':
        return '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year}';
      case 'full':
      default:
        return '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year} at ${_formatTime(now, '12h')}';
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> args,
    ToolContext context,
  ) async {
    final now = DateTime.now();
    final format = args['format'] as String? ?? 'full';

    final timeStr = _formatTime(now, format);

    return ToolResult.success(
      toolName: name,
      message: timeStr,
      data: {
        'time': now.toIso8601String(),
        'timezone': now.timeZoneName,
        'hour': now.hour,
        'minute': now.minute,
        'day': now.day,
        'month': now.month,
        'year': now.year,
        'dayOfWeek': _getDayName(now.weekday),
      },
    );
  }
}
