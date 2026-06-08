import 'package:flutter_tts/flutter_tts.dart';

/// Odtwarzacz „czytanie na głos" z podświetlaniem bieżącego słowa.
///
/// Czyta akapit po akapicie. Dla każdego wypowiadanego słowa zgłasza zakres
/// znaków [start, end) w tekście akapitu (mapowanym tak samo jak wyświetlany),
/// co pozwala podświetlić słowo. Używa własnej instancji FlutterTts, aby nie
/// kolidować z wymową pojedynczych słów w dymkach.
class ReadAloudPlayer {
  final FlutterTts _tts = FlutterTts();
  List<String> _paragraphs = const [];
  int _index = 0;
  bool _active = false;

  void Function(int paragraph, int start, int end)? onWord;
  void Function(int paragraph)? onParagraph;
  void Function()? onDone;

  bool get isActive => _active;

  Future<void> _configure(String language, double rate) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(1.0);
    _tts.setProgressHandler((text, start, end, word) {
      if (_active) onWord?.call(_index, start, end);
    });
    _tts.setCompletionHandler(() {
      if (!_active) return;
      _index++;
      if (_index < _paragraphs.length) {
        onParagraph?.call(_index);
        _speakCurrent();
      } else {
        _active = false;
        onDone?.call();
      }
    });
  }

  Future<void> start(
    List<String> paragraphs, {
    required String language,
    required double rate,
    int from = 0,
  }) async {
    await stop();
    _paragraphs = paragraphs;
    _index = from.clamp(0, paragraphs.length - 1);
    _active = true;
    await _configure(language, rate);
    onParagraph?.call(_index);
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_index < 0 || _index >= _paragraphs.length) return;
    final text = _paragraphs[_index];
    if (text.trim().isEmpty) {
      // puste — przejdź dalej
      _index++;
      if (_index < _paragraphs.length) {
        onParagraph?.call(_index);
        await _speakCurrent();
      } else {
        _active = false;
        onDone?.call();
      }
      return;
    }
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _active = false;
    try {
      await _tts.stop();
    } catch (_) {/* ignoruj */}
  }
}
