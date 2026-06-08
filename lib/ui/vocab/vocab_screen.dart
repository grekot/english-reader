import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vocab_repository.dart';
import '../../models/vocab_entry.dart';
import '../../services/tts_service.dart';

/// Lista zapisanych słówek + prosty tryb powtórki (EN → odsłoń PL).
class VocabScreen extends ConsumerWidget {
  const VocabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabControllerProvider);
    final tts = ref.read(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiszki'),
        actions: [
          vocabAsync.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.play_circle),
                    tooltip: 'Powtórka',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReviewScreen(entries: list)),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: vocabAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Brak zapisanych słówek.\nStuknij słowo w tekście i naciśnij gwiazdkę, aby je dodać.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              return Dismissible(
                key: ValueKey('${e.key}-$i'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) =>
                    ref.read(vocabControllerProvider.notifier).remove(e),
                child: ListTile(
                  title: Text(e.word),
                  subtitle: Text([
                    if (e.translation != null) e.translation!,
                    if (e.lemma != null && e.lemma!.toLowerCase() != e.word.toLowerCase())
                      '(${e.lemma})',
                  ].join('  ')),
                  trailing: tts.available
                      ? IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () => tts.speak(e.word),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Prosty tryb powtórki: pokazuje EN, po stuknięciu odsłania PL.
class ReviewScreen extends ConsumerStatefulWidget {
  final List<VocabEntry> entries;
  const ReviewScreen({super.key, required this.entries});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _index = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final tts = ref.read(ttsServiceProvider);
    final e = widget.entries[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('Powtórka ${_index + 1}/${widget.entries.length}'),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _revealed = true),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.word,
                    style: Theme.of(context).textTheme.headlineMedium),
                if (tts.available)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => tts.speak(e.word),
                  ),
                const SizedBox(height: 24),
                if (_revealed) ...[
                  Text(e.translation ?? '—',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (e.context != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(e.context!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                ] else
                  const Text('Stuknij, aby odsłonić tłumaczenie'),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () {
            setState(() {
              _revealed = false;
              _index = (_index + 1) % widget.entries.length;
            });
          },
          child: const Text('Następne'),
        ),
      ),
    );
  }
}
