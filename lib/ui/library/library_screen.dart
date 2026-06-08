import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/progress_repository.dart';
import '../../data/text_repository.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../update/update_checker.dart';
import '../vocab/vocab_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteka'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież teksty',
            onPressed: () => ref.invalidate(catalogProvider),
          ),
          IconButton(
            icon: const Icon(Icons.style),
            tooltip: 'Fiszki',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VocabScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.system_update),
            tooltip: 'Sprawdź aktualizacje',
            onPressed: () => checkForUpdateInteractive(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ustawienia',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(catalogProvider),
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('Błąd katalogu: $e')),
            ],
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Center(child: Text('Brak tekstów w katalogu.'));
            }
            final progress = ref.read(progressRepositoryProvider);
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final frac = progress.fraction(entry.id);
                return ListTile(
                  title: Text(entry.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.author != null) Text(entry.author!),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (entry.level != null) ...[
                            Chip(
                              label: Text(entry.level!),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: LinearProgressIndicator(
                              value: frac,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${(frac * 100).round()}%'),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(entry: entry),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
