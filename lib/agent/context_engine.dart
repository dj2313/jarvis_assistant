import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'agent_models.dart';
import '../services/location_service.dart';

abstract class ContextProvider {
  Future<Map<String, dynamic>> getContext();
  String get providerName;
}

class TimeContextProvider implements ContextProvider {
  @override
  String get providerName => 'time';

  @override
  Future<Map<String, dynamic>> getContext() async {
    final now = DateTime.now();
    return {
      'current_time': '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      'date': '${now.day}/${now.month}/${now.year}',
      'timezone': now.timeZoneName,
      'is_weekend': now.weekday >= 6,
      'hour': now.hour,
    };
  }
}

class BatteryContextProvider implements ContextProvider {
  final Battery _battery = Battery();

  @override
  String get providerName => 'battery';

  @override
  Future<Map<String, dynamic>> getContext() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return {
        'battery_percent': level,
        'is_charging':
            state == BatteryState.charging ||
            state == BatteryState.full ||
            state == BatteryState.connectedNotCharging,
        'status': state.name,
      };
    } catch (e) {
      debugPrint('BatteryContextProvider error: $e');
      return {
        'battery_percent': 0,
        'is_charging': false,
        'status': 'unavailable',
      };
    }
  }
}

class NetworkContextProvider implements ContextProvider {
  final Connectivity _connectivity = Connectivity();

  @override
  String get providerName => 'network';

  @override
  Future<Map<String, dynamic>> getContext() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      final isConnected = result != ConnectivityResult.none;
      final type = _mapConnectivityResult(result);
      return {
        'network_type': type,
        'is_connected': isConnected,
        'signal_strength': 0,
      };
    } catch (e) {
      debugPrint('NetworkContextProvider error: $e');
      return {
        'network_type': 'unknown',
        'is_connected': false,
        'signal_strength': 0,
      };
    }
  }

  String _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.bluetooth:
        return 'bluetooth';
      case ConnectivityResult.vpn:
        return 'vpn';
      case ConnectivityResult.satellite:
        return 'satellite';
      case ConnectivityResult.other:
        return 'other';
      case ConnectivityResult.none:
        return 'none';
    }
  }
}

class LocationContextProvider implements ContextProvider {
  final LocationService _locationService;

  LocationContextProvider({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  @override
  String get providerName => 'location';

  @override
  Future<Map<String, dynamic>> getContext() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return {};
    return {
      'location': '${position.latitude},${position.longitude}',
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }
}

class ContextEngine {
  final List<ContextProvider> _providers;

  ContextEngine({List<ContextProvider>? providers})
    : _providers = providers ?? _defaultProviders();

  static List<ContextProvider> _defaultProviders() => [
    TimeContextProvider(),
    BatteryContextProvider(),
    NetworkContextProvider(),
    LocationContextProvider(),
  ];

  Future<ContextSnapshot> getSnapshot({bool includeLocation = false}) async {
    final now = DateTime.now();

    // Run all providers in parallel — the old sequential loop stacked every
    // provider's latency (battery + network + up to 30s of GPS) on the
    // critical path before the LLM call could even start.
    final active = _providers
        .where((p) => p.providerName != 'location' || includeLocation)
        .toList();

    final results = await Future.wait(
      active.map((provider) => _safeContext(provider)),
    );

    int batteryPercent = 0;
    String networkType = 'unknown';
    String? location;
    DateTime? nextCalendarEvent;

    for (final result in results) {
      if (result == null) continue;
      final (provider, context) = result;
      switch (provider) {
        case 'battery':
          batteryPercent = context['battery_percent'] ?? 0;
          break;
        case 'network':
          networkType = context['network_type'] ?? 'unknown';
          break;
        case 'location':
          location = context['location'];
          break;
        case 'calendar':
          final eventStr = context['next_event'];
          if (eventStr != null) {
            nextCalendarEvent = DateTime.tryParse(eventStr);
          }
          break;
      }
    }

    return ContextSnapshot(
      now: now,
      timezone: now.timeZoneName,
      batteryPercent: batteryPercent,
      networkType: networkType,
      location: location,
      nextCalendarEvent: nextCalendarEvent,
    );
  }

  /// Fetch one provider's context without letting it fail or stall the
  /// snapshot. Location gets a short budget here: this snapshot is only
  /// conversational context — the navigate tool does its own full
  /// (30s, last-known-fallback) fetch when real coordinates are needed.
  Future<(String, Map<String, dynamic>)?> _safeContext(
    ContextProvider provider,
  ) async {
    try {
      final future = provider.getContext();
      final Map<String, dynamic> context;
      if (provider.providerName == 'location') {
        context = await future.timeout(const Duration(seconds: 5));
      } else {
        context = await future.timeout(const Duration(seconds: 3));
      }
      return (provider.providerName, context);
    } catch (e) {
      debugPrint('ContextProvider ${provider.providerName} failed: $e');
      return null;
    }
  }

  void addProvider(ContextProvider provider) {
    _providers.add(provider);
  }

  void removeProvider(String providerName) {
    _providers.removeWhere((p) => p.providerName == providerName);
  }
}
