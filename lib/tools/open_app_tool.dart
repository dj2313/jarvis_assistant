import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';

class OpenAppTool extends FridayTool {
  static const Map<String, String> _appNames = {
    'spotify': 'com.spotify.music',
    'youtube': 'com.google.android.youtube',
    'whatsapp': 'com.whatsapp',
    'telegram': 'org.telegram.messenger',
    'instagram': 'com.instagram.android',
    'twitter': 'com.twitter.android',
    'x': 'com.twitter.android',
    'chrome': 'com.android.chrome',
    'google': 'com.google.android.googlequicksearchbox',
    'maps': 'com.google.android.apps.maps',
    'camera': 'com.android.camera',
    'calculator': 'com.android.calculator2',
    'calendar': 'com.google.android.calendar',
    'clock': 'com.google.android.deskclock',
    'settings': 'com.android.settings',
    'files': 'com.google.android.apps.nbu.files',
    'gmail': 'com.google.android.gm',
    'photos': 'com.google.android.apps.photos',
    'netflix': 'com.netflix.mediaclient',
    'zoom': 'us.zoom.videomeetings',
    'teams': 'com.microsoft.teams',
    'slack': 'com.Slack',
    'discord': 'com.discord',
    'snapchat': 'com.snapchat',
    'facebook': 'com.facebook.katana',
    'messenger': 'com.facebook.orca',
    'tiktok': 'com.zhiliaoapp.musically',
    'duolingo': 'com.duolingo',
    'evernote': 'com.evernote',
  };

  @override
  String get name => 'open_app';

  @override
  String get description =>
      'Open an application on the user\'s Android device. Use this when the user asks '
      'to open, launch, start, or run an app. Supported apps include WhatsApp, Telegram, '
      'YouTube, Spotify, Chrome, Maps, Gmail, and many more. On Android it uses a native '
      'launcher intent; on other platforms it falls back to a package URI.';

  @override
  int get riskLevel => 1;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'app_name': {
        'type': 'string',
        'description':
            'The app to open, e.g. "whatsapp", "youtube", "spotify", "chrome". '
            'Full list: ${_appNames.keys.join(", ")}.',
      },
    },
    'required': ['app_name'],
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
    final appName = (args['app_name'] as String?)?.toLowerCase().trim();

    if (appName == null || appName.isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'App name is required',
        errorCode: 'MISSING_APP_NAME',
      );
    }

    final packageName = _resolvePackage(appName);
    if (packageName == null) {
      return ToolResult.failure(
        toolName: name,
        message:
            'App "$appName" is not in the supported apps list. '
            'Supported: ${_appNames.keys.join(", ")}.',
        errorCode: 'UNSUPPORTED_APP',
      );
    }

    try {
      final launched = await _launchByPackage(packageName);
      if (launched) {
        return ToolResult.success(
          toolName: name,
          message: 'Opened $appName successfully.',
          data: {'app_name': appName, 'package': packageName},
        );
      }
      return ToolResult.failure(
        toolName: name,
        message:
            'Cannot launch $appName ($packageName). The app may not be installed.',
        errorCode: 'LAUNCH_FAILED',
      );
    } on PlatformException catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Platform error launching $appName: ${e.message ?? e.code}',
        errorCode: 'PLATFORM_ERROR',
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Failed to open $appName: $e',
        errorCode: 'LAUNCH_ERROR',
      );
    }
  }

  String? _resolvePackage(String appName) {
    if (_appNames.containsKey(appName)) return _appNames[appName];
    if (_appNames.containsValue(appName)) return appName;
    return null;
  }

  /// Launch by known package name. Prefers the native method channel
  /// (reliable on Android 10+), falls back to url_launcher `package:` URI.
  Future<bool> _launchByPackage(String packageName) async {
    final channel = _methodChannel;
    if (channel != null) {
      try {
        final bool? ok = await channel.invokeMethod<bool>('launchApp', {
          'package': packageName,
        });
        if (ok == true) return true;
      } on PlatformException {
        // fall through to url_launcher fallback
      }
    }

    // Cross-platform fallback: url_launcher with package: URI.
    final uri = Uri.parse('package:$packageName');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  static const String _channelName = 'friday_automation';

  /// The native method channel is only available when the host
  /// platform code has been registered. On Android we expect
  /// `friday_automation` (see MainActivity.kt).
  MethodChannel? get _methodChannel {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const MethodChannel(_channelName);
    }
    return null;
  }
}
