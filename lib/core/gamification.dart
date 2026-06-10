import 'package:flutter/material.dart';

/// Logika grywalizacji: punkty (XP), poziomy i odznaki — liczone lokalnie
/// na podstawie danych, które aplikacja już zbiera. Zaprojektowane tak, by
/// `XpBreakdown` dało się w przyszłości wysłać do wspólnego rankingu rodzinnego.

/// Ile XP trzeba na jeden poziom.
const int kXpPerLevel = 100;

/// Wagi punktów za poszczególne aktywności.
const int kXpPerReadingMinute = 1;
const int kXpPerLookup = 2;
const int kXpPerCompletedText = 20;
const int kXpPerQuizCorrect = 5;

class XpBreakdown {
  final int reading;
  final int lookups;
  final int completed;
  final int quiz;

  const XpBreakdown({
    required this.reading,
    required this.lookups,
    required this.completed,
    required this.quiz,
  });

  int get total => reading + lookups + completed + quiz;
}

XpBreakdown computeXp({
  required int readingSeconds,
  required int lookups,
  required int completedTexts,
  required int quizCorrect,
}) {
  return XpBreakdown(
    reading: (readingSeconds ~/ 60) * kXpPerReadingMinute,
    lookups: lookups * kXpPerLookup,
    completed: completedTexts * kXpPerCompletedText,
    quiz: quizCorrect * kXpPerQuizCorrect,
  );
}

int levelForXp(int xp) => 1 + xp ~/ kXpPerLevel;

/// Postęp 0..1 w obrębie bieżącego poziomu.
double levelProgress(int xp) => (xp % kXpPerLevel) / kXpPerLevel;

int xpIntoLevel(int xp) => xp % kXpPerLevel;

/// Migawka osiągnięć użytkownika (wejście do reguł odznak).
class StatsSnapshot {
  final int streak;
  final int lookups;
  final int completedTexts;
  final int readingMinutes;
  final int quizCorrect;
  final int xp;

  const StatsSnapshot({
    required this.streak,
    required this.lookups,
    required this.completedTexts,
    required this.readingMinutes,
    required this.quizCorrect,
    required this.xp,
  });
}

class BadgeDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(StatsSnapshot s) earned;

  const BadgeDef(this.id, this.title, this.description, this.icon, this.earned);
}

/// Definicje odznak. Kolejność = kolejność wyświetlania.
final List<BadgeDef> kBadges = [
  BadgeDef('first-steps', 'Pierwsze kroki', 'Zdobądź 10 XP',
      Icons.flag, (s) => s.xp >= 10),
  BadgeDef('reader-30', 'Czytelnik', 'Czytaj łącznie 30 minut',
      Icons.menu_book, (s) => s.readingMinutes >= 30),
  BadgeDef('marathon', 'Maratończyk', 'Czytaj łącznie 2 godziny',
      Icons.directions_run, (s) => s.readingMinutes >= 120),
  BadgeDef('words-50', 'Ciekawski', 'Sprawdź 50 słów',
      Icons.search, (s) => s.lookups >= 50),
  BadgeDef('words-200', 'Słownik', 'Sprawdź 200 słów',
      Icons.translate, (s) => s.lookups >= 200),
  BadgeDef('finisher-5', 'Mól książkowy', 'Ukończ 5 tekstów',
      Icons.auto_stories, (s) => s.completedTexts >= 5),
  BadgeDef('streak-7', 'Tydzień nauki', 'Utrzymaj serię 7 dni',
      Icons.local_fire_department, (s) => s.streak >= 7),
  BadgeDef('streak-30', 'Żelazna wola', 'Utrzymaj serię 30 dni',
      Icons.whatshot, (s) => s.streak >= 30),
  BadgeDef('quiz-master', 'Quizmistrz', 'Zalicz 20 poprawnych odpowiedzi',
      Icons.emoji_events, (s) => s.quizCorrect >= 20),
  BadgeDef('level-5', 'Poziom 5', 'Osiągnij 5. poziom',
      Icons.military_tech, (s) => levelForXp(s.xp) >= 5),
];
