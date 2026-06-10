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

enum BadgeTier { none, bronze, silver, gold }

const Map<BadgeTier, String> kTierLabels = {
  BadgeTier.none: 'Brak',
  BadgeTier.bronze: 'Brąz',
  BadgeTier.silver: 'Srebro',
  BadgeTier.gold: 'Złoto',
};

/// Kolor dla danego poziomu odznaki (null = niezdobyta).
Color? tierColor(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return const Color(0xFFCD7F32);
    case BadgeTier.silver:
      return const Color(0xFF9E9E9E);
    case BadgeTier.gold:
      return const Color(0xFFFFC107);
    case BadgeTier.none:
      return null;
  }
}

/// Odznaka wielopoziomowa (brąz → srebro → złoto) na danej metryce.
class TieredBadge {
  final String id;
  final String title;
  final IconData icon;
  final String unit; // np. "min", "słów"
  final String description;
  final int bronze;
  final int silver;
  final int gold;
  final int Function(StatsSnapshot s) value;

  const TieredBadge({
    required this.id,
    required this.title,
    required this.icon,
    required this.unit,
    required this.description,
    required this.bronze,
    required this.silver,
    required this.gold,
    required this.value,
  });

  BadgeTier tierFor(int v) {
    if (v >= gold) return BadgeTier.gold;
    if (v >= silver) return BadgeTier.silver;
    if (v >= bronze) return BadgeTier.bronze;
    return BadgeTier.none;
  }

  /// Następny próg do zdobycia (null = osiągnięto złoto).
  int? nextThreshold(int v) {
    if (v < bronze) return bronze;
    if (v < silver) return silver;
    if (v < gold) return gold;
    return null;
  }

  List<int> get thresholds => [bronze, silver, gold];
}

/// Definicje odznak. Kolejność = kolejność wyświetlania.
final List<TieredBadge> kBadges = [
  TieredBadge(
    id: 'reading',
    title: 'Czas czytania',
    icon: Icons.timer,
    unit: 'min',
    description: 'Łączny czas spędzony na czytaniu tekstów.',
    bronze: 30,
    silver: 120,
    gold: 600,
    value: (s) => s.readingMinutes,
  ),
  TieredBadge(
    id: 'words',
    title: 'Sprawdzone słowa',
    icon: Icons.translate,
    unit: 'słów',
    description: 'Liczba różnych słów, które sprawdziłeś (stuknąłeś).',
    bronze: 50,
    silver: 200,
    gold: 1000,
    value: (s) => s.lookups,
  ),
  TieredBadge(
    id: 'finished',
    title: 'Ukończone teksty',
    icon: Icons.auto_stories,
    unit: 'tekstów',
    description: 'Teksty oznaczone jako przeczytane (100%).',
    bronze: 3,
    silver: 10,
    gold: 30,
    value: (s) => s.completedTexts,
  ),
  TieredBadge(
    id: 'streak',
    title: 'Seria dni',
    icon: Icons.local_fire_department,
    unit: 'dni',
    description: 'Liczba kolejnych dni nauki bez przerwy.',
    bronze: 3,
    silver: 7,
    gold: 30,
    value: (s) => s.streak,
  ),
  TieredBadge(
    id: 'quiz',
    title: 'Quizy',
    icon: Icons.emoji_events,
    unit: 'odp.',
    description: 'Liczba poprawnych odpowiedzi w quizach.',
    bronze: 20,
    silver: 100,
    gold: 500,
    value: (s) => s.quizCorrect,
  ),
  TieredBadge(
    id: 'level',
    title: 'Poziom',
    icon: Icons.military_tech,
    unit: 'poz.',
    description: 'Twój poziom wynikający z łącznej liczby XP.',
    bronze: 5,
    silver: 10,
    gold: 25,
    value: (s) => levelForXp(s.xp),
  ),
];
