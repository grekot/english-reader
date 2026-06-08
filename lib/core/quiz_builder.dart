import 'dart:math';

import '../models/text_document.dart';

/// Pojedyncze pytanie quizu (wielokrotnego wyboru).
class QuizQuestion {
  final String prompt;
  final List<String> options;
  final int answer;
  final String? hint;

  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    this.hint,
  });
}

/// Para słowo–tłumaczenie wyciągnięta z tekstu (do quizu słówek).
class _Pair {
  final String w;
  final String t;
  const _Pair(this.w, this.t);
}

List<_Pair> _collectPairs(TextDocument doc) {
  final seen = <String>{};
  final pairs = <_Pair>[];
  for (final p in doc.paragraphs) {
    for (final s in p.sentences) {
      for (final tok in s.tokens) {
        final t = tok.t;
        if (t == null || t.isEmpty || t.startsWith('(')) continue;
        if (!RegExp(r'[A-Za-z]').hasMatch(tok.w)) continue;
        final key = tok.w.toLowerCase();
        if (seen.add(key)) pairs.add(_Pair(tok.w, t));
      }
    }
  }
  return pairs;
}

/// Czy da się zbudować quiz słówek (potrzeba ≥3 różnych par).
bool canBuildWordQuiz(TextDocument doc) => _collectPairs(doc).length >= 3;

/// Quiz słówek: [enToPl]=true → pokaż angielskie, wybierz polskie; false → odwrotnie.
List<QuizQuestion> buildWordQuiz(
  TextDocument doc, {
  required bool enToPl,
  required Random rng,
  int max = 10,
}) {
  final pairs = _collectPairs(doc);
  if (pairs.length < 3) return [];

  String promptOf(_Pair p) => enToPl ? p.w : p.t;
  String answerOf(_Pair p) => enToPl ? p.t : p.w;

  final shuffled = [...pairs]..shuffle(rng);
  final selected = shuffled.take(max).toList();
  final questions = <QuizQuestion>[];

  for (final pair in selected) {
    final correct = answerOf(pair);
    // Dystraktory: inne odpowiedzi, różne od poprawnej i od siebie.
    final pool = pairs
        .where((p) => answerOf(p).toLowerCase() != correct.toLowerCase())
        .map(answerOf)
        .toSet()
        .toList()
      ..shuffle(rng);
    final distractors = pool.take(2).toList();
    if (distractors.length < 2) continue;

    final options = [correct, ...distractors]..shuffle(rng);
    questions.add(QuizQuestion(
      prompt: promptOf(pair),
      options: options,
      answer: options.indexOf(correct),
      hint: enToPl ? 'Wybierz tłumaczenie' : 'Wybierz angielskie słowo',
    ));
  }
  return questions;
}

/// Pytania do tekstu (zrozumienie) — wprost z pola `questions` w pliku.
List<QuizQuestion> buildComprehension(TextDocument doc) {
  return [
    for (final q in doc.questions)
      if (q.options.length >= 2)
        QuizQuestion(prompt: q.q, options: q.options, answer: q.answer),
  ];
}

/// Wszystkie zdania (en, pl) tekstu, w których oba pola są niepuste.
List<({String en, String pl})> _sentences(TextDocument doc) {
  final out = <({String en, String pl})>[];
  for (final p in doc.paragraphs) {
    for (final s in p.sentences) {
      if (s.en.isNotEmpty && s.pl.isNotEmpty) out.add((en: s.en, pl: s.pl));
    }
  }
  return out;
}

/// Czy da się wygenerować automatyczny quiz zrozumienia (≥3 zdania z tłumaczeniem).
bool canBuildAutoComprehension(TextDocument doc) => _sentences(doc).length >= 3;

/// Automatyczny quiz zrozumienia: pokaż zdanie po angielsku, wybierz poprawne
/// polskie tłumaczenie spośród trzech. Używany, gdy plik nie ma pola `questions`.
List<QuizQuestion> buildAutoComprehension(
  TextDocument doc, {
  required Random rng,
  int max = 8,
}) {
  final sentences = _sentences(doc);
  if (sentences.length < 3) return [];
  final selected = [...sentences]..shuffle(rng);
  final questions = <QuizQuestion>[];
  for (final s in selected.take(max)) {
    final pool = sentences
        .where((o) => o.pl != s.pl)
        .map((o) => o.pl)
        .toSet()
        .toList()
      ..shuffle(rng);
    if (pool.length < 2) continue;
    final options = [s.pl, ...pool.take(2)]..shuffle(rng);
    questions.add(QuizQuestion(
      prompt: s.en,
      options: options,
      answer: options.indexOf(s.pl),
      hint: 'Wybierz poprawne tłumaczenie zdania',
    ));
  }
  return questions;
}
