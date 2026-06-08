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
