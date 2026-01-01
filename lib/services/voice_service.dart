import 'dart:async';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  String _currentLocale = "en-GB";

  String get currentLocale => _currentLocale;

  // Stream for visual feedback (Simulated amplitude during TTS)
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Timer? _visualizerTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check Permissions
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
      return;
    }

    // Initialize TTS
    try {
      await _updateTtsLanguage(_currentLocale);
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for 'Butler' feel
      await _flutterTts.setPitch(0.8); // Deeper
      await _flutterTts.setVolume(1.0);

      // TTS Handlers
      _flutterTts.setStartHandler(() {
        _startSimulatingVisuals();
      });

      _flutterTts.setCompletionHandler(() {
        _stopSimulatingVisuals();
      });

      _flutterTts.setCancelHandler(() {
        _stopSimulatingVisuals();
      });

      _flutterTts.setErrorHandler((msg) {
        _stopSimulatingVisuals();
      });
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

      // Attempt to find a specific Male voice for the new locale
      final voices = await _flutterTts.getVoices;
      List<dynamic>? validVoices = voices as List<dynamic>?;

      Map<String, String>? selectedVoice;

      if (validVoices != null) {
        // 1. Try specified locale Male
        for (var voice in validVoices) {
          final String name = voice['name'].toString().toLowerCase();
          final String vLocale = voice['locale'].toString().toLowerCase();
          // Filter by the base language code (e.g. 'en' or 'fr')
          if (vLocale.startsWith(locale.split('-').first.toLowerCase()) &&
              name.contains('male')) {
            selectedVoice = Map<String, String>.from(voice as Map);
            break;
          }
        }

        // 2. Fallback: Any Male
        if (selectedVoice == null) {
          for (var voice in validVoices) {
            final String name = voice['name'].toString().toLowerCase();
            if (name.contains('male')) {
              selectedVoice = Map<String, String>.from(voice as Map);
              break;
            }
          }
        }
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
      }
    } catch (e) {
      debugPrint("Error updating TTS language: $e");
    }
  }

  Future<bool> startListening({
    required Function(String) onResult,
    required Function(String) onStatus,
    Function(double)? onSoundLevel,
  }) async {
    if (!_isInitialized) await initialize();

    bool available = await _speech.initialize(
      onStatus: (status) => onStatus(status),
      onError: (errorNotification) {
        onStatus('error');
        debugPrint('Voice Error: ${errorNotification.errorMsg}');
      },
    );

    if (available) {
      _speech.listen(
        onResult: (result) => onResult(result.recognizedWords),
        onSoundLevelChange: onSoundLevel,
        localeId: _currentLocale, // Use the current locale for recognition
        pauseFor: const Duration(
          seconds: 3,
        ), // 3s pause triggers "end of command"
        listenFor: const Duration(seconds: 30),
        cancelOnError: false,
        partialResults: true,
      );
      return true;
    } else {
      return false;
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      // Ensure visuals start if startHandler misses
      _startSimulatingVisuals();
      await _flutterTts.speak(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _stopSimulatingVisuals();
  }

  // --- Visual Sync Logic ---
  void _startSimulatingVisuals() {
    _visualizerTimer?.cancel();
    _visualizerTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // Generate a random amplitude between 0.2 and 1.0
      // This makes the Orb pulse 'alive' while speaking
      final double fakeAmp = 0.2 + (Random().nextDouble() * 0.8);
      _amplitudeController.add(fakeAmp);
    });
  }

  void _stopSimulatingVisuals() {
    _visualizerTimer?.cancel();
    _visualizerTimer = null;
    _amplitudeController.add(0.0); // Return to idle
  }

  void dispose() {
    _amplitudeController.close();
    _visualizerTimer?.cancel();
    _flutterTts.stop();
  }
}
