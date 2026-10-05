import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';

/// Returns current weather via the Open-Meteo API (free, no API key required).
/// The LLM supplies latitude/longitude (ideally from the user's location) or
/// the tool falls back to a default city if none is provided.
class WeatherTool extends FridayTool {
  final Future<double?> Function()? defaultLatitude;
  final Future<double?> Function()? defaultLongitude;

  WeatherTool({this.defaultLatitude, this.defaultLongitude});

  static const double _fallbackLat = 40.7128; // New York
  static const double _fallbackLng = -74.0060;

  @override
  String get name => 'get_weather';

  @override
  String get description =>
      "Get the current weather and temperature for a location using the "
      'Open-Meteo API. Use this when the user asks about the weather, '
      'temperature, conditions, rain, or wind. The model should supply '
      "'latitude' and 'longitude' (from the user's location if known). "
      'If no coordinates are provided, a default city is used.';

  @override
  int get riskLevel => 0;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'latitude': {
        'type': 'number',
        'description': 'Latitude of the location to check weather for.',
      },
      'longitude': {
        'type': 'number',
        'description': 'Longitude of the location to check weather for.',
      },
      'location_name': {
        'type': 'string',
        'description':
            'Optional human-readable location name for the report (e.g. "New York").',
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

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> args,
    ToolContext context,
  ) async {
    final double lat;
    final double lng;
    final bool usingFallback;
    if (args.containsKey('latitude') && args.containsKey('longitude')) {
      lat = (args['latitude'] as num).toDouble();
      lng = (args['longitude'] as num).toDouble();
      usingFallback = false;
    } else {
      lat = await defaultLatitude?.call() ?? _fallbackLat;
      lng = await defaultLongitude?.call() ?? _fallbackLng;
      usingFallback = (defaultLatitude == null && defaultLongitude == null);
    }

    final locationName =
        (args['location_name'] as String?)?.trim().isNotEmpty ?? false
            ? args['location_name'] as String
            : null;

    try {
      final uri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': lat.toStringAsFixed(4),
          'longitude': lng.toStringAsFixed(4),
          'current_weather': 'true',
          'temperature_unit': 'celsius',
          'windspeed_unit': 'kmh',
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ToolResult.failure(
          toolName: name,
          message: 'Weather service returned status ${response.statusCode}.',
          errorCode: 'WEATHER_HTTP_ERROR',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current =
          (data['current_weather'] as Map<String, dynamic>?) ?? {};

      final double temperature =
          (current['temperature'] as num?)?.toDouble() ?? 0.0;
      final double windSpeed =
          (current['windspeed'] as num?)?.toDouble() ?? 0.0;
      final int weatherCode =
          (current['weathercode'] as num?)?.toInt() ?? -1;

      final String condition = _describeWeather(weatherCode);

      final String place =
          locationName ?? 'the requested location';
      final String fallbackNote = usingFallback
          ? ' (Note: GPS location unavailable — using default location: New York.)'
          : '';
      final String summary = 'Weather at $place: '
          '$condition, $temperature°C, wind $windSpeed km/h.$fallbackNote';

      return ToolResult.success(
        toolName: name,
        message: summary,
        data: {
          'latitude': lat,
          'longitude': lng,
          'location_name': locationName,
          'temperature_celsius': temperature,
          'condition': condition,
          'weather_code': weatherCode,
          'wind_speed_kmh': windSpeed,
        },
      );
    } catch (e) {
      debugPrint('Weather tool error: $e');
      return ToolResult.failure(
        toolName: name,
        message: 'Could not retrieve weather at the moment.',
        errorCode: 'WEATHER_ERROR',
      );
    }
  }

  String _describeWeather(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mostly clear';
    if (code == 2 || code == 3) {
      return code == 2 ? 'Partly cloudy' : 'Overcast';
    }
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzling';
    if (code == 66 || code == 67) return 'Freezing rain';
    if (code >= 61 && code <= 65) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Unknown conditions';
  }
}
