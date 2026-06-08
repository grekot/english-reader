import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import '../../data/progress_repository.dart';
import '../../models/text_document.dart';
import '../reader/reader_screen.dart';

/// Lista tekstów (dla wybranej kategorii / ulubionych / ostatnio używanych).
class TextListScreen extends ConsumerWidget {
  final String title;
  final List<CatalogEntry> entries;
  final String? emptyMessage;

  const TextListScreen({
    super.key,
    required this.title,
    required this.entries,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesControllerProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(emptyMessage ?? 'Brak tekstów.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final frac = progress[entry.id] ?? 0;
                final isFav = favorites.contains(entry.id);
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
                  trailing: IconButton(
                    icon: Icon(isFav ? Icons.star : Icons.star_border,
                        color: isFav ? Colors.amber : null),
                    tooltip: isFav ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                    onPressed: () =>
                        ref.read(favoritesControllerProvider.notifier).toggle(entry.id),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(entry: entry),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
