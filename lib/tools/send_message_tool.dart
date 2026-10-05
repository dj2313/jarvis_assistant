import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';

class SendMessageTool extends FridayTool {
  static const Map<String, String> _packageNames = {
    'whatsapp': 'com.whatsapp',
    'telegram': 'org.telegram.messenger',
    'instagram': 'com.instagram.android',
    'twitter': 'com.twitter.android',
    'gmail': 'com.google.android.gm',
  };

  static const Map<String, String> _contacts = {
    'john': '+1234567890',
    'mary': '@maryusername',
    'mom': '+1987654321',
    'dad': '+1876543210',
  };

  @override
  String get name => 'send_message';

  @override
  String get description =>
      "Send a message via an app (WhatsApp, Telegram, SMS, email, Instagram DMs). "
      "Prefers opening a deep-link with the message pre-filled in the compose field; "
      'the user then taps SEND. The tool returns whether a matching deep link could be '
      'constructed and launched. Use ONLY after the user has explicitly requested '
      "sending a message to a recipient via a specific app.";

  @override
  int get riskLevel => 3;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'app': {
        'type': 'string',
        'description':
            'The messaging platform (whatsapp, telegram, sms, email, instagram)',
      },
      'recipient': {
        'type': 'string',
        'description':
            'The recipient phone number (E.164 with +), username, or email address',
      },
      'message': {'type': 'string', 'description': 'The message body to send'},
      'subject': {
        'type': 'string',
        'description': 'Optional subject line (for email only)',
      },
    },
    'required': ['app', 'recipient', 'message'],
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
    final app = (args['app'] as String?)?.toLowerCase().trim();
    final recipient = (args['recipient'] as String?)?.trim();
    final message = (args['message'] as String?)?.trim();
    final subject = (args['subject'] as String?)?.trim();

    if (app == null || app.isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'App is required (e.g. whatsapp, telegram, sms, email)',
        errorCode: 'MISSING_APP',
      );
    }
    if (recipient == null || recipient.isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'Recipient is required',
        errorCode: 'MISSING_RECIPIENT',
      );
    }
    if (message == null || message.isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'Message body is required',
        errorCode: 'MISSING_MESSAGE',
      );
    }

    final resolvedRecipient = _resolveContact(recipient);
    final uri = _buildDeepLink(app, resolvedRecipient, message, subject);

    if (uri == null) {
      return ToolResult.failure(
        toolName: name,
        message:
            'Could not build a deep link for app "$app". Supported: whatsapp, '
            'telegram, sms, email, instagram.',
        errorCode: 'UNSUPPORTED_APP',
      );
    }

    try {
      if (!await canLaunchUrl(uri)) {
        return ToolResult.failure(
          toolName: name,
          message:
              'The app "$app" does not appear to be installed on this device.',
          errorCode: 'APP_NOT_INSTALLED',
        );
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);

      final preview = message.length > 60
          ? '${message.substring(0, 60)}...'
          : message;
      return ToolResult.success(
        toolName: name,
        message:
            'Opened $app with a pre-filled message to "$resolvedRecipient". '
            'Please tap SEND in the app to confirm.',
        data: {
          'app': app,
          'recipient': resolvedRecipient,
          'message_preview': preview,
          'deep_link': uri.toString(),
          'note': 'Manual send required by the user.',
        },
      );
    } on PlatformException catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Failed to launch $app: ${e.message ?? e.code}',
        errorCode: 'LAUNCH_ERROR',
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Failed to send message: $e',
        errorCode: 'SEND_ERROR',
      );
    }
  }

  String _resolveContact(String recipient) {
    final key = recipient.toLowerCase().trim();
    if (_contacts.containsKey(key)) {
      return _contacts[key]!;
    }
    return recipient;
  }

  Uri? _buildDeepLink(
    String app,
    String recipient,
    String message,
    String? subject,
  ) {
    final encoded = Uri.encodeComponent(message);
    final encodedSubject = subject != null
        ? Uri.encodeComponent(subject)
        : Uri.encodeComponent('Message from FRIDAY');

    switch (app) {
      case 'whatsapp':
        // wa.me link pre-fills the message; number must be in E.164 without +
        final phone = recipient.replaceAll('+', '').replaceAll('-', '');
        return Uri.https('wa.me', '/$phone', {'text': message});
      case 'telegram':
        if (recipient.startsWith('@')) {
          final user = recipient.substring(1);
          return Uri.https('t.me', '/$user', {'text': message});
        }
        return Uri(
          scheme: 'tg',
          host: 'resolve',
          queryParameters: {'text': message},
        );
      case 'sms':
        return Uri(
          scheme: 'sms',
          path: recipient,
          queryParameters: {'body': message, 'subject': encodedSubject},
        );
      case 'email':
        return Uri(
          scheme: 'mailto',
          path: recipient,
          queryParameters: {'subject': encodedSubject, 'body': encoded},
        );
      case 'instagram':
        // Instagram does not allow pre-filled DM text via public deep link.
        // Open the direct thread; user completes the message.
        final clean = recipient.startsWith('@')
            ? recipient.substring(1)
            : recipient;
        final pkg = _packageNames['instagram'];
        if (pkg != null) {
          return Uri(
            scheme: 'instagram',
            host: 'user',
            queryParameters: {'username': clean, 'message': message},
          );
        }
        return Uri.https('instagram.com', '/direct/inbox/');
      default:
        return null;
    }
  }
}
