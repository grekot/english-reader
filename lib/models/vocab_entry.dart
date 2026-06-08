/// Zapisane słowo do powtórki (fiszka).
class VocabEntry {
  /// Słowo w formie z tekstu.
  final String word;

  /// Polskie tłumaczenie kontekstowe.
  final String? translation;

  /// Forma podstawowa (lemat).
  final String? lemma;

  /// Id tekstu, z którego pochodzi.
  final String? textId;

  /// Zdanie-kontekst, w którym wystąpiło słowo.
  final String? context;

  /// Znacznik czasu dodania (ISO 8601).
  final String addedAt;

  const VocabEntry({
    required this.word,
    this.translation,
    this.lemma,
    this.textId,
    this.context,
    required this.addedAt,
  });

  /// Klucz deduplikacji (słowo + lemat, bez rozróżniania wielkości liter).
  String get key => '${word.toLowerCase()}|${(lemma ?? '').toLowerCase()}';

  Map<String, dynamic> toJson() => {
        'word': word,
        if (translation != null) 'translation': translation,
        if (lemma != null) 'lemma': lemma,
        if (textId != null) 'textId': textId,
        if (context != null) 'context': context,
        'addedAt': addedAt,
      };

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      word: json['word'] as String,
      translation: json['translation'] as String?,
      lemma: json['lemma'] as String?,
      textId: json['textId'] as String?,
      context: json['context'] as String?,
      addedAt: json['addedAt'] as String? ?? '',
    );
  }
}
