import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification.dart';
import '../../data/gamification_repository.dart';
import '../../data/lookups_repository.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../data/stats_repository.dart';
import '../leaderboard/leaderboard_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(statsControllerProvider);
    final stats = ref.read(statsControllerProvider.notifier);
    final goalMin =
        ref.watch(settingsControllerProvider.select((s) => s.dailyGoalMinutes));
    final progress = ref.watch(progressProvider);
    final lookups = ref.watch(lookupsControllerProvider);
    final quizCorrect = ref.watch(quizScoreProvider);

    final readingSeconds = stats.totalSeconds;
    final readingMinutes = readingSeconds ~/ 60;
    final completed = progress.values.where((v) => v >= 1.0).length;
    final inProgress = progress.values.where((v) => v > 0 && v < 1.0).length;
    final lookupCount = lookups.values.fold<int>(0, (a, b) => a + b.length);

    final xp = computeXp(
      readingSeconds: readingSeconds,
      lookups: lookupCount,
      completedTexts: completed,
      quizCorrect: quizCorrect,
    );
    final level = levelForXp(xp.total);
    final snapshot = StatsSnapshot(
      streak: stats.streak,
      lookups: lookupCount,
      completedTexts: completed,
      readingMinutes: readingMinutes,
      quizCorrect: quizCorrect,
      xp: xp.total,
    );

    final todayMin = stats.todaySeconds / 60.0;
    final goalFrac = goalMin > 0 ? (todayMin / goalMin).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Statystyki')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Ranking rodzinny'),
              subtitle: const Text('Rywalizuj z domownikami'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _levelCard(context, level, xp),
          const SizedBox(height: 8),
          _goalCard(context, todayMin, goalMin, goalFrac),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            children: [
              _stat(context, Icons.local_fire_department, '${stats.streak}',
                  'dni z rzędu'),
              _stat(context, Icons.menu_book, '$completed', 'ukończonych'),
              _stat(context, Icons.auto_stories, '$inProgress', 'w trakcie'),
              _stat(context, Icons.translate, '$lookupCount', 'sprawdzonych słów'),
              _stat(context, Icons.quiz, '$quizCorrect', 'trafnych odpowiedzi'),
              _stat(context, Icons.timer, '$readingMinutes', 'minut łącznie'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Odznaki', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _badges(context, snapshot),
        ],
      ),
    );
  }

  Widget _levelCard(BuildContext context, int level, XpBreakdown xp) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primary,
                  child: Text('$level',
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Poziom $level',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${xp.total} XP łącznie'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: levelProgress(xp.total),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${xpIntoLevel(xp.total)} / $kXpPerLevel XP do poziomu ${level + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _xpPart('📖 czytanie', xp.reading),
                _xpPart('🔤 słówka', xp.lookups),
                _xpPart('✅ ukończone', xp.completed),
                _xpPart('🎯 quizy', xp.quiz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _xpPart(String label, int value) =>
      Text('$label: $value XP', style: const TextStyle(fontSize: 12));

  Widget _goalCard(
      BuildContext context, double todayMin, int goalMin, double goalFrac) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: goalFrac, strokeWidth: 6),
                  Text('${(goalFrac * 100).round()}%',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dzienny cel',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('${todayMin.toStringAsFixed(0)} / $goalMin min dziś'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _badges(BuildContext context, StatsSnapshot snapshot) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.82,
      children: [
        for (final b in kBadges)
          () {
            final v = b.value(snapshot);
            final tier = b.tierFor(v);
            final color = tierColor(tier) ?? scheme.outlineVariant;
            return InkWell(
              onTap: () => _showBadge(context, b, snapshot),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(b.icon, size: 36, color: color),
                  const SizedBox(height: 4),
                  Text(
                    b.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: tier == BadgeTier.none
                          ? scheme.onSurface.withValues(alpha: 0.45)
                          : scheme.onSurface,
                      fontWeight: tier == BadgeTier.none
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  Text(
                    tier == BadgeTier.none ? '—' : kTierLabels[tier]!,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }

  void _showBadge(BuildContext context, TieredBadge b, StatsSnapshot snapshot) {
    final v = b.value(snapshot);
    final tier = b.tierFor(v);
    final next = b.nextThreshold(v);
    final names = ['Brąz', 'Srebro', 'Złoto'];
    final tierColors = [
      tierColor(BadgeTier.bronze)!,
      tierColor(BadgeTier.silver)!,
      tierColor(BadgeTier.gold)!,
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(b.icon, color: tierColor(tier) ?? Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(b.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.description),
            const SizedBox(height: 12),
            Text('Masz: $v ${b.unit}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (next != null)
              Text(
                'Aktualny poziom: ${tier == BadgeTier.none ? "brak" : kTierLabels[tier]}. '
                'Do następnego: jeszcze ${next - v} ${b.unit}.',
              )
            else
              const Text('Zdobyto najwyższy poziom — Złoto! 🏆'),
            const Divider(height: 24),
            for (var i = 0; i < b.thresholds.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      v >= b.thresholds[i]
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: v >= b.thresholds[i] ? tierColors[i] : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('${names[i]} — ${b.thresholds[i]} ${b.unit}'),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
