import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';
import '../services/location_service.dart';

/// Returns the user's current geographic location.
class GetLocationTool extends FridayTool {
  final LocationService _locationService;

  GetLocationTool({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  @override
  String get name => 'get_location';

  @override
  String get description =>
      "Get the user's current GPS location (latitude, longitude) and a "
      'human-readable address/place name. Use this when the user asks '
      '"where am I", "my location", "what is my location", or any question '
      'that depends on where the device currently is.';

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
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        return ToolResult.failure(
          toolName: name,
          message:
              'Location is unavailable. GPS may be disabled or permissions not granted.',
          errorCode: 'LOCATION_UNAVAILABLE',
        );
      }

      final placeName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final latitude = position.latitude.toStringAsFixed(6);
      final longitude = position.longitude.toStringAsFixed(6);
      final message = placeName != null
          ? 'Current location: $placeName ($latitude, $longitude).'
          : 'Current location: $latitude, $longitude.';

      return ToolResult.success(
        toolName: name,
        message: message,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'place_name': placeName,
          'accuracy': position.accuracy,
        },
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Could not determine your location.',
        errorCode: 'LOCATION_ERROR',
      );
    }
  }

  /// Optional best-effort reverse geocoding via OpenStreetMap Nominatim.
  /// Returns null (the raw coordinates are still returned) on any failure.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': lat.toStringAsFixed(6),
          'lon': lng.toStringAsFixed(6),
          'format': 'json',
          'zoom': '16',
        },
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'friday_assistant/1.0'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'];
        if (displayName is String && displayName.trim().isNotEmpty) {
          return displayName.trim();
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
    return null;
  }
}
