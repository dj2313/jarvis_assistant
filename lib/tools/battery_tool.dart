import 'package:battery_plus/battery_plus.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';

class BatteryTool extends FridayTool {
  final Battery _battery = Battery();

  @override
  String get name => 'get_battery';

  @override
  String get description =>
      'Get the current battery level and charging status of the device. Use this when the user asks about battery, power, or device status.';

  @override
  int get riskLevel => 0;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {},
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

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> args,
    ToolContext context,
  ) async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isCharging =
          state == BatteryState.charging ||
          state == BatteryState.full ||
          state == BatteryState.connectedNotCharging;

      return ToolResult.success(
        toolName: name,
        message:
            'Battery level: $level%, Status: ${isCharging ? 'Charging' : 'Discharging'}',
        data: {
          'battery_percent': level,
          'is_charging': isCharging,
          'status': state.name,
        },
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Could not read battery status.',
        errorCode: 'BATTERY_READ_ERROR',
      );
    }
  }
}
