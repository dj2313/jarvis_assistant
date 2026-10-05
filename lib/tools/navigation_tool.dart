import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent_models.dart';
import '../services/location_service.dart';
import 'friday_tool.dart';

class NavigationTool extends FridayTool {
  final LocationService _locationService;

  NavigationTool({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  @override
  String get name => 'navigate';

  @override
  String get description =>
      'Start turn-by-turn GPS navigation to a destination using the device maps app.';

  @override
  int get riskLevel => 1;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'destination': {
        'type': 'string',
        'description': 'The place, address, or coordinates to navigate to',
      },
      'travel_mode': {
        'type': 'string',
        'enum': ['driving', 'walking', 'bicycling', 'transit'],
        'description': 'Preferred travel mode',
      },
    },
    'required': ['destination'],
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
    final destination = args['destination']?.toString().trim() ?? '';
    if (destination.isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'Please provide a navigation destination.',
        errorCode: 'MISSING_DESTINATION',
      );
    }

    final mode = _validMode(args['travel_mode']?.toString());
    final position = await _locationService.getCurrentPosition();

    // Build URL with action=navigate for immediate turn-by-turn
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': mode,
      'action': 'navigate',
      if (position != null)
        'origin': '${position.latitude},${position.longitude}',
    });

    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Navigation launch error: $e');
    }

    // Fallback: try google.navigation: intent (Android)
    if (!launched && position != null) {
      final navUri = Uri.parse(
        'google.navigation:q=${Uri.encodeComponent(destination)}&mode=$mode',
      );
      try {
        launched = await launchUrl(navUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Navigation fallback launch error: $e');
      }
    }

    if (!launched) {
      return ToolResult.failure(
        toolName: name,
        message: 'I could not open a maps application on this device.',
        errorCode: 'MAPS_UNAVAILABLE',
      );
    }

    final originMsg = position != null
        ? ' from your current location'
        : ' (origin unknown — starting from default location)';

    return ToolResult.success(
      toolName: name,
      message: 'GPS navigation to $destination$originMsg has been initiated, Sir.',
      data: {
        'destination': destination,
        'travel_mode': mode,
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      },
    );
  }

  String _validMode(String? requestedMode) {
    const validModes = {'driving', 'walking', 'bicycling', 'transit'};
    return validModes.contains(requestedMode) ? requestedMode! : 'driving';
  }
}
