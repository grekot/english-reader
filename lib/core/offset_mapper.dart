import '../models/text_document.dart';

/// Zakres znaków [start, end) w renderowanym tekście akapitu wraz z odnośnikiem
/// do tokenu i indeksu zdania, którego dotyczy.
class TokenSpan {
  final int start;
  final int end;
  final int sentenceIndex;
  final Token token;

  const TokenSpan({
    required this.start,
    required this.end,
    required this.sentenceIndex,
    required this.token,
  });

  bool contains(int offset) => offset >= start && offset < end;
}

/// Zakres znaków zdania w renderowanym tekście akapitu.
class SentenceSpan {
  final int start;
  final int end;
  final int sentenceIndex;
  final Sentence sentence;

  const SentenceSpan({
    required this.start,
    required this.end,
    required this.sentenceIndex,
    required this.sentence,
  });

  bool contains(int offset) => offset >= start && offset < end;
}

/// Czy znak jest częścią słowa (litera/cyfra/apostrof/łącznik).
bool _isWordChar(String ch) {
  if (ch.isEmpty) return false;
  final code = ch.codeUnitAt(0);
  // apostrofy ' ’ oraz łącznik -
  if (code == 0x27 || code == 0x2019 || code == 0x2D) return true;
  return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch);
}

/// Przygotowany akapit: renderowany tekst + mapy zakresów znaków na tokeny i
/// zdania. Tworzony raz przy budowie widgetu; potem stuknięcie mapuje się
/// w czasie O(liczba tokenów).
class MappedParagraph {
  /// Pełny tekst akapitu do wyświetlenia (zdania `en` połączone spacją).
  final String text;
  final List<TokenSpan> tokenSpans;
  final List<SentenceSpan> sentenceSpans;

  const MappedParagraph._({
    required this.text,
    required this.tokenSpans,
    required this.sentenceSpans,
  });

  factory MappedParagraph.build(Paragraph paragraph) {
    final buffer = StringBuffer();
    final tokenSpans = <TokenSpan>[];
    final sentenceSpans = <SentenceSpan>[];

    for (var si = 0; si < paragraph.sentences.length; si++) {
      final sentence = paragraph.sentences[si];
      if (si > 0) buffer.write(' ');
      final sentenceStart = buffer.length;
      buffer.write(sentence.en);
      final sentenceEnd = buffer.length;

      sentenceSpans.add(SentenceSpan(
        start: sentenceStart,
        end: sentenceEnd,
        sentenceIndex: si,
        sentence: sentence,
      ));

      // Dopasuj tokeny kolejno wewnątrz `en` (offsety liczone od sentenceStart).
      final en = sentence.en;
      var cursor = 0;
      for (final token in sentence.tokens) {
        final localStart = _findWord(en, token.w, cursor);
        if (localStart < 0) continue; // niedopasowany token — pomijamy
        final localEnd = localStart + token.w.length;
        cursor = localEnd;
        tokenSpans.add(TokenSpan(
          start: sentenceStart + localStart,
          end: sentenceStart + localEnd,
          sentenceIndex: si,
          token: token,
        ));
      }
    }

    return MappedParagraph._(
      text: buffer.toString(),
      tokenSpans: tokenSpans,
      sentenceSpans: sentenceSpans,
    );
  }

  /// Znajduje wystąpienie `word` w `text` od pozycji `from`, preferując
  /// dopasowanie na granicy słowa (sąsiednie znaki nie są częścią słowa).
  static int _findWord(String text, String word, int from) {
    if (word.isEmpty) return -1;
    var index = text.indexOf(word, from);
    while (index >= 0) {
      final beforeOk =
          index == 0 || !_isWordChar(text[index - 1]);
      final afterIndex = index + word.length;
      final afterOk =
          afterIndex >= text.length || !_isWordChar(text[afterIndex]);
      if (beforeOk && afterOk) return index;
      index = text.indexOf(word, index + 1);
    }
    // Fallback: pierwsze dopasowanie bez granicy słowa.
    return text.indexOf(word, from);
  }

  /// Token zawierający dany offset (lub null, jeśli to interpunkcja/spacja).
  TokenSpan? tokenAt(int offset) {
    for (final span in tokenSpans) {
      if (span.contains(offset)) return span;
    }
    return null;
  }

  /// Zdanie zawierające dany offset.
  SentenceSpan? sentenceAt(int offset) {
    for (final span in sentenceSpans) {
      if (span.contains(offset)) return span;
    }
    // Jeśli offset wypadł na spację między zdaniami, dopasuj najbliższe.
    if (sentenceSpans.isEmpty) return null;
    return sentenceSpans.last;
  }
}
