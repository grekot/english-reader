import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lookups_repository.dart';
import '../../data/vocab_repository.dart';
import '../../models/vocab_entry.dart';
import '../../services/tts_service.dart';

/// Glosariusz: słowa sprawdzone (stuknięte) w danym tekście.
class GlossaryScreen extends ConsumerWidget {
  final String textId;
  final String textTitle;
  const GlossaryScreen({super.key, required this.textId, required this.textTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(lookupsControllerProvider)[textId] ?? const [];
    final tts = ref.read(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Glosariusz')),
      body: words.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Brak sprawdzonych słów w tym tekście.\nStuknij słowo w czytniku, aby je tu zobaczyć.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: words.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final word = words[i];
                return ListTile(
                  title: Text(word.w),
                  subtitle: Text([
                    if (word.t != null) word.t!,
                    if (word.lemma != null &&
                        word.lemma!.toLowerCase() != word.w.toLowerCase())
                      '(${word.lemma})',
                  ].join('  ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tts.available)
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () => tts.speak(word.w),
                        ),
                      IconButton(
                        icon: const Icon(Icons.star_border),
                        tooltip: 'Zapisz do fiszek',
                        onPressed: () {
                          ref.read(vocabControllerProvider.notifier).add(
                                VocabEntry(
                                  word: word.w,
                                  translation: word.t,
                                  lemma: word.lemma,
                                  textId: textId,
                                  addedAt: DateTime.now().toIso8601String(),
                                ),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Zapisano "${word.w}" do fiszek'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
