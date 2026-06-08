import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Obsługa syntezatora mowy (wymowa angielskich słów/zdań).
///
/// Na Androidzie działa natywnie; na Windows korzysta z SAPI i może mieć
/// ograniczony zestaw głosów — w razie braku wsparcia `available` = false,
/// a UI ukrywa przycisk odtwarzania.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _available = false;
  bool _initialized = false;

  bool get available => _available;

  Future<void> init(String language) async {
    try {
      final languages = await _tts.getLanguages;
      _available = languages is List && languages.isNotEmpty;
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (_) {/* ignoruj */}
  }

  Future<void> speak(String text) async {
    if (!_initialized) await init('en-US');
    if (!_available) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {/* ignoruj */}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {/* ignoruj */}
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
