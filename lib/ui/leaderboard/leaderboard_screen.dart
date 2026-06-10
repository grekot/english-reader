import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification.dart';
import '../../data/family_repository.dart';
import '../../data/gamification_repository.dart';
import '../../data/lookups_repository.dart';
import '../../data/progress_repository.dart';
import '../../data/stats_repository.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  Future<List<ScoreRow>>? _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(familyControllerProvider) != null) {
      _refresh();
    }
  }

  ({int xp, int level, int streak, int minutes, int completed, int lookups, int quiz})
      _snapshot() {
    final stats = ref.read(statsControllerProvider.notifier);
    final progress = ref.read(progressProvider);
    final lookups = ref.read(lookupsControllerProvider);
    final quizCorrect = ref.read(quizScoreProvider);
    final readingSeconds = stats.totalSeconds;
    final completed = progress.values.where((v) => v >= 1.0).length;
    final lookupCount = lookups.values.fold<int>(0, (a, b) => a + b.length);
    final xp = computeXp(
      readingSeconds: readingSeconds,
      lookups: lookupCount,
      completedTexts: completed,
      quizCorrect: quizCorrect,
    ).total;
    return (
      xp: xp,
      level: levelForXp(xp),
      streak: stats.streak,
      minutes: readingSeconds ~/ 60,
      completed: completed,
      lookups: lookupCount,
      quiz: quizCorrect,
    );
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opuść ranking rodzinny?'),
        content: const Text(
            'Twój wynik zostanie usunięty z rankingu rodziny, a aplikacja '
            'poprosi o nazwę i kod ponownie. Twoje statystyki na urządzeniu '
            'pozostaną nienaruszone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Opuść'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final messenger = ScaffoldMessenger.of(context);
    final family = ref.read(familyControllerProvider);
    var deleted = false;
    if (family != null) {
      try {
        deleted =
            await ref.read(leaderboardServiceProvider).deleteScore(family.deviceId);
      } catch (_) {/* nawet jeśli sieć padnie, wychodzimy lokalnie */}
    }
    await ref.read(familyControllerProvider.notifier).leave();
    if (mounted) setState(() => _future = null);
    if (!deleted && mounted) {
      messenger.showSnackBar(const SnackBar(
        duration: Duration(seconds: 5),
        content: Text(
            'Opuszczono lokalnie, ale wpisu nie udało się usunąć z chmury. '
            'Sprawdź połączenie lub politykę „delete" w Supabase.'),
      ));
    }
  }

  Future<void> _refresh() async {
    final family = ref.read(familyControllerProvider);
    if (family == null) return;
    final service = ref.read(leaderboardServiceProvider);
    final s = _snapshot();
    final future = () async {
      // Najpierw wyślij swój wynik, potem pobierz ranking.
      await service.uploadScore(
        family,
        xp: s.xp,
        level: s.level,
        streak: s.streak,
        readingMinutes: s.minutes,
        completed: s.completed,
        lookups: s.lookups,
        quizCorrect: s.quiz,
      );
      return service.fetch(family.familyCode);
    }();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking rodzinny'),
        actions: [
          if (family != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież',
              onPressed: _refresh,
            ),
        ],
      ),
      body: family == null ? _setupForm() : _leaderboard(family),
    );
  }

  Widget _setupForm() {
    return _JoinForm(
      busy: _busy,
      onJoin: (name, code) async {
        setState(() => _busy = true);
        await ref.read(familyControllerProvider.notifier).join(name, code);
        setState(() => _busy = false);
        _refresh();
      },
    );
  }

  Widget _leaderboard(FamilySettings family) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ScoreRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nie udało się pobrać rankingu:\n${snap.error}\n\n'
                    'Sprawdź połączenie. Jeśli to pierwsze użycie, upewnij się, '
                    'że tabela reading_scores istnieje w Supabase.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ]);
          }
          final rows = snap.data ?? const <ScoreRow>[];
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Rodzina: ${family.familyCode}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Brak wyników. Pociągnij, by odświeżyć.')),
                ),
              for (var i = 0; i < rows.length; i++)
                _row(i + 1, rows[i], rows[i].deviceId == family.deviceId),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Opuść ranking rodzinny'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: _leave,
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _row(int rank, ScoreRow s, bool isMe) {
    final scheme = Theme.of(context).colorScheme;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$rank.',
    };
    return Card(
      color: isMe ? scheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Text(medal, style: const TextStyle(fontSize: 22)),
        title: Text(
          isMe ? '${s.displayName} (Ty)' : s.displayName,
          style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Text(
            'Poziom ${s.level} · 🔥 ${s.streak} dni · ${s.readingMinutes} min · ${s.completed} tekstów'),
        trailing: Text('${s.xp} XP',
            style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _JoinForm extends StatefulWidget {
  final bool busy;
  final Future<void> Function(String name, String code) onJoin;
  const _JoinForm({required this.busy, required this.onJoin});

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  final _name = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.groups, size: 64),
          const SizedBox(height: 12),
          Text('Dołącz do rankingu rodzinnego',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Podaj swoją nazwę oraz wspólny kod rodziny. Wszyscy domownicy, '
            'którzy wpiszą ten sam kod, zobaczą wspólny ranking.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Twoja nazwa',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Kod rodziny (np. kowalscy2026)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () {
                    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Podaj nazwę i kod rodziny.')),
                      );
                      return;
                    }
                    widget.onJoin(_name.text, _code.text);
                  },
            child: widget.busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Dołącz'),
          ),
        ],
      ),
    );
  }
}
