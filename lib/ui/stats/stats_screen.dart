import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lookups_repository.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../data/stats_repository.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(statsControllerProvider); // odśwież po zmianie czasu
    final stats = ref.read(statsControllerProvider.notifier);
    final goalMin = ref.watch(
        settingsControllerProvider.select((s) => s.dailyGoalMinutes));
    final progress = ref.watch(progressProvider);
    final lookups = ref.watch(lookupsControllerProvider);

    final todayMin = stats.todaySeconds / 60.0;
    final goalFrac = goalMin > 0 ? (todayMin / goalMin).clamp(0.0, 1.0) : 0.0;
    final completed = progress.values.where((v) => v >= 1.0).length;
    final inProgress =
        progress.values.where((v) => v > 0 && v < 1.0).length;
    final lookupCount =
        lookups.values.fold<int>(0, (a, b) => a + b.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Statystyki')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dzienny cel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: goalFrac,
                          strokeWidth: 7,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        Text('${(goalFrac * 100).round()}%',
                            style: const TextStyle(fontSize: 12)),
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
                        const SizedBox(height: 4),
                        Text('${todayMin.toStringAsFixed(0)} / $goalMin min dziś'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Kafelki
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: [
              _stat(context, Icons.local_fire_department, '${stats.streak}',
                  'dni z rzędu'),
              _stat(context, Icons.menu_book, '$completed', 'ukończonych'),
              _stat(context, Icons.auto_stories, '$inProgress', 'w trakcie'),
              _stat(context, Icons.translate, '$lookupCount', 'sprawdzonych słów'),
              _stat(context, Icons.calendar_today, '${stats.activeDays}',
                  'dni z nauką'),
              _stat(context, Icons.timer, '${(stats.totalSeconds / 60).round()}',
                  'minut łącznie'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
