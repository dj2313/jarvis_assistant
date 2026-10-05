import 'package:flutter_test/flutter_test.dart';

import 'package:friday_assistant/tools/tool_bootstrap.dart';
import 'package:friday_assistant/tools/friday_tool.dart';
import 'package:friday_assistant/tools/current_time_tool.dart';
import 'package:friday_assistant/tools/weather_tool.dart';
import 'package:friday_assistant/agent/agent_models.dart';
import 'package:friday_assistant/services/response_sanitizer.dart';

void main() {
  test('buildDefaultTools registers unique, well-formed tools', () {
    final tools = buildDefaultTools();

    expect(tools.length, greaterThanOrEqualTo(7));

    final names = tools.map((t) => t.name).toSet();
    expect(names.length, tools.length, reason: 'Tool names must be unique');

    for (final FridayTool tool in tools) {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.riskLevel, inInclusiveRange(0, 3));
      expect(tool.inputSchema['type'], 'object');
      expect(tool.groqToolDefinition, isNotEmpty);
      expect(tool.groqToolDefinition.first['type'], 'function');
    }
  });

  test('critical and sensitive tools carry expected risk levels', () {
    final tools = buildDefaultTools();
    final byName = {for (final t in tools) t.name: t};

    expect(byName['navigate'], isNotNull);

    expect(
      byName['send_message']!.riskLevel,
      3,
      reason: 'Sending messages must require approval',
    );
    expect(
      byName['open_app']!.riskLevel,
      1,
      reason: 'Opening apps is reversible',
    );
    expect(byName['get_battery']!.riskLevel, 0);
    expect(byName['current_time']!.riskLevel, 0);
  });
  test('assistant output never exposes pseudo function markup', () {
    expect(
      ResponseSanitizer.clean('<function name:- >The weather is clear.'),
      'The weather is clear.',
    );
    expect(
      ResponseSanitizer.clean(
        '<function name="web_search">hidden call</function>Useful answer',
      ),
      'Useful answer',
    );
  });

  test('Qwen thinking delimiters are stripped from responses', () {
    final qwenOutput =
        '\n<think>\nHere is a thinking process.\nStep 1, Step 2.\n</?>\n\n'
        'The capital of France is Paris.';
    final cleaned = ResponseSanitizer.clean(qwenOutput);
    expect(cleaned, contains('Paris'));
    expect(cleaned, isNot(contains('thinking process')));
    expect(cleaned, isNot(contains('think')));
    expect(cleaned, isNot(contains('</')));
  });

  test('current_time tool returns a valid timestamp string', () async {
    final tool = CurrentTimeTool();
    final context = ToolContext(
      requestId: 'test-time',
    );

    final result = await tool.execute({'format': 'full'}, context);
    expect(result.success, isTrue, reason: result.message);
    expect(result.message, contains('at'));
    expect(result.data, isNotNull);
    expect(result.data!['year'], DateTime.now().year);
    expect(result.data!['month'], DateTime.now().month);
    expect(result.data!['day'], DateTime.now().day);

    // 12-hour format should contain AM or PM
    final result12h = await tool.execute({'format': '12h'}, context);
    expect(result12h.success, isTrue);
    final hasPeriod = result12h.message.contains('AM') ||
        result12h.message.contains('PM');
    expect(hasPeriod, isTrue, reason: result12h.message);
  });

  test('weather tool falls back gracefully when no location given', () async {
    final tool = WeatherTool();
    final context = ToolContext(
      requestId: 'test-weather',
    );

    final result = await tool.execute({}, context);
    // WeatherTool should return either success (network available) or a
    // graceful failure — never crash.
    expect(result.toolName, 'get_weather');
    if (result.success) {
      expect(result.message, contains('Weather at'));
    } else {
      expect(result.errorCode, isNotEmpty);
    }
  });

  test('weather tool with explicit coordinates returns a report', () async {
    final tool = WeatherTool();
    final context = ToolContext(requestId: 'test-weather-lat-lng');

    final result = await tool.execute(
      {'latitude': 28.6139, 'longitude': 77.2090},
      context,
    );

    expect(result.toolName, 'get_weather');
    expect(result.success, isTrue, reason: result.message);
  });
}
