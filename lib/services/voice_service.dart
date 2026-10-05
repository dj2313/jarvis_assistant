import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import 'response_sanitizer.dart';

/// Voice layer tuned for J.A.R.V.I.S. — British male, measured cadence,
/// formal address ("Sir"), and task acknowledgements.
/// Uses Groq Whisper API (whisper-large-v3) for speech-to-text.
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isRecording = false;
  String _currentLocale = "en-GB";
  Timer? _recordTimer;

  String get currentLocale => _currentLocale;

  // Preferred JARVIS-style voices per platform (British male).
  static const List<String> _jarvisVoiceHints = [
    'daniel',
    'arthur',
    'ryan',
    'oliver',
    'fred',
    'en-gb',
    'english united kingdom',
    'male',
  ];

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Timer? _visualizerTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    try {
      await _updateTtsLanguage(_currentLocale);
      await _flutterTts.setSpeechRate(0.42);
      await _flutterTts.setPitch(0.82);
      await _flutterTts.setVolume(1.0);

      _flutterTts.setStartHandler(() => _startSimulatingVisuals());
      _flutterTts.setCompletionHandler(() => _stopSimulatingVisuals());
      _flutterTts.setCancelHandler(() => _stopSimulatingVisuals());
      _flutterTts.setErrorHandler((_) => _stopSimulatingVisuals());
    } catch (e) {
      debugPrint("Voice setup error: $e");
    }

    _isInitialized = true;
  }

  Future<void> setLanguage(String locale) async {
    _currentLocale = locale;
    await _updateTtsLanguage(locale);
  }

  Future<void> _updateTtsLanguage(String locale) async {
    try {
      await _flutterTts.setLanguage(locale);

      final voices = await _flutterTts.getVoices;
      List<dynamic>? validVoices = voices as List<dynamic>?;
      Map<String, String>? selectedVoice;

      if (validVoices != null) {
        final String langPrefix = locale.split('-').first.toLowerCase();

        for (final hint in _jarvisVoiceHints) {
          for (var voice in validVoices) {
            final String name = voice['name'].toString().toLowerCase();
            final String vLocale = voice['locale'].toString().toLowerCase();
            if (vLocale.startsWith(langPrefix) && name.contains(hint)) {
              selectedVoice = Map<String, String>.from(voice as Map);
              break;
            }
          }
          if (selectedVoice != null) break;
        }

        if (selectedVoice == null && langPrefix == 'en') {
          for (var voice in validVoices) {
            final String name = voice['name'].toString().toLowerCase();
            final String vLocale = voice['locale'].toString().toLowerCase();
            if (vLocale.contains('gb') && name.contains('male')) {
              selectedVoice = Map<String, String>.from(voice as Map);
              break;
            }
          }
        }

        if (selectedVoice == null) {
          for (var voice in validVoices) {
            final String name = voice['name'].toString().toLowerCase();
            final String vLocale = voice['locale'].toString().toLowerCase();
            if (vLocale.startsWith(langPrefix) && name.contains('male')) {
              selectedVoice = Map<String, String>.from(voice as Map);
              break;
            }
          }
        }
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
        debugPrint("JARVIS voice selected: ${selectedVoice['name']}");
      }
    } catch (e) {
      debugPrint("Error updating TTS language: $e");
    }
  }

  /// Start recording audio via device microphone.
  /// The recording is sent to Groq Whisper API when stopListening is called.
  Future<bool> startListening({
    required Function(String) onResult,
    required Function(String) onStatus,
    Function(double)? onSoundLevel,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/jarvis_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        _isRecording = true;
        onStatus('listening');

        // Monitor amplitude for visual feedback
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
          (amp) {
            if (_isRecording && onSoundLevel != null) {
              final normalized =
                  ((amp.current + 50) / 50).clamp(0.0, 1.0);
              onSoundLevel(normalized);
            }
          },
        );

        // Auto-stop after 30 seconds
        _recordTimer = Timer(const Duration(seconds: 30), () async {
          if (_isRecording) {
            await stopListening();
            // stopListening() already transcribed via Whisper
            final text = consumeLastTranscription();
            if (text.isNotEmpty) {
              onResult(text);
            }
            onStatus('notListening');
          }
        });

        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Recording start error: $e");
      onStatus('error');
      return false;
    }
  }

  /// Stop recording and transcribe via Groq Whisper API.
  /// Returns the transcribed text.
  Future<String> stopListening() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (!_isRecording) return "";

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        final text = await _transcribeWithWhisper(path);
        if (text.isNotEmpty) {
          debugPrint("Whisper transcription: $text");
          _lastTranscription = text;
        }
        try {
          await File(path).delete();
        } catch (_) {}
        return text;
      }
    } catch (e) {
      debugPrint("Recording stop error: $e");
      _isRecording = false;
    }
    return "";
  }

  /// Transcribe audio file using Groq Whisper API (whisper-large-v3).
  Future<String> _transcribeWithWhisper(String filePath) async {
    String apiKey = "";
    try {
      apiKey = Config.groqApiKey;
    } catch (e) {
      debugPrint("Whisper: Missing GROQ_API_KEY");
      return "";
    }

    if (apiKey.isEmpty) {
      debugPrint("Whisper: Empty GROQ_API_KEY");
      return "";
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint("Whisper: Audio file not found at $filePath");
        return "";
      }

      final bytes = await file.readAsBytes();
      final uri = Uri.parse(
          'https://api.groq.com/openai/v1/audio/transcriptions');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = Config.sttModel
        ..fields['language'] = _currentLocale.split('-').first
        ..fields['response_format'] = 'text'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'audio.wav',
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final text = response.body.trim();
        debugPrint("Whisper STT success: ${text.length} chars");
        return text;
      } else {
        debugPrint(
          "Whisper API error: ${response.statusCode} - ${response.body}",
        );
        return "";
      }
    } catch (e) {
      debugPrint("Whisper transcription error: $e");
      return "";
    }
  }

  /// Holds the last Whisper transcription for polling-based callers.
  String _lastTranscription = "";

  /// Poll and consume the last transcription result.
  String consumeLastTranscription() {
    final result = _lastTranscription;
    _lastTranscription = "";
    return result;
  }

  /// Speak with JARVIS-style text cleanup and measured delivery.
  Future<void> speak(String text, {bool isTaskAck = false}) async {
    String cleanText = ResponseSanitizer.clean(text);
    cleanText = cleanText.replaceAll(RegExp(r'\{[^{}]*\}'), '').trim();

    if (cleanText.isEmpty) return;

    if (isTaskAck) {
      cleanText = _applyJarvisPhrasing(cleanText);
    }

    _startSimulatingVisuals();
    await _flutterTts.speak(cleanText);
  }

  /// Short JARVIS acknowledgement before executing a command.
  Future<void> speakAcknowledgement() async {
    const acks = [
      "Right away, Sir.",
      "Certainly, Sir.",
      "At once, Sir.",
      "Understood, Sir.",
      "Processing your request, Sir.",
    ];
    final ack = acks[Random().nextInt(acks.length)];
    await speak(ack);
  }

  String _applyJarvisPhrasing(String text) {
    if (!text.toLowerCase().contains('sir') &&
        !text.toLowerCase().contains("ma'am")) {
      if (text.endsWith('.')) {
        return '${text.substring(0, text.length - 1)}, Sir.';
      }
      return '$text, Sir.';
    }
    return text;
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _stopSimulatingVisuals();
  }

  void _startSimulatingVisuals() {
    _visualizerTimer?.cancel();
    _visualizerTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final double fakeAmp = 0.25 + (Random().nextDouble() * 0.55);
      _amplitudeController.add(fakeAmp);
    });
  }

  void _stopSimulatingVisuals() {
    _visualizerTimer?.cancel();
    _visualizerTimer = null;
    _amplitudeController.add(0.0);
  }

  void dispose() {
    _recordTimer?.cancel();
    _visualizerTimer?.cancel();
    _amplitudeController.close();
    _flutterTts.stop();
    _recorder.dispose();
  }
}
