import 'package:flutter_tts/flutter_tts.dart';

class VocalService {
  final FlutterTts _tts = FlutterTts();

  VocalService() {
    _initTts();
  }

  Future<void> _initTts() async {
    // Setting up the "Butler" voice
    await _tts.setLanguage("en-GB"); // British English
    await _tts.setSpeechRate(0.5); // Refined, not too fast
    await _tts.setPitch(0.9); // Slightly deeper/sophisticated

    // Attempt to set a specific neural-like voice if available on the device
    // On many Androids, 'en-gb-x-rjs-network' is a great high-quality voice
    await _tts.setVoice({"name": "en-gb-x-rjs-network", "locale": "en-GB"});
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Clean the text: Remove any stray JSON if it leaked through
    String cleanText = text.replaceAll(RegExp(r'\{.*\}'), '').trim();

    if (cleanText.isNotEmpty) {
      await _tts.speak(cleanText);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
