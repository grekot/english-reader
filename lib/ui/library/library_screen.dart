import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_repository.dart';
import '../../data/imported_repository.dart';
import '../../data/recent_repository.dart';
import '../../data/text_repository.dart';
import '../../models/text_document.dart';
import '../manage/management_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../update/update_checker.dart';
import '../vocab/vocab_screen.dart';
import 'text_list_screen.dart';

/// Poprawna polska odmiana rzeczownika "tekst" przez liczebnik.
String _plTexts(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (n == 1) return '1 tekst';
  if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) {
    return '$n teksty';
  }
  return '$n tekstów';
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final recentIds = ref.watch(recentControllerProvider);
    final favoriteIds = ref.watch(favoritesControllerProvider);
    final imported = ref.watch(importedControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.file_open),
        label: const Text('Wczytaj plik'),
        onPressed: () => _importFile(context, ref),
      ),
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
          if (Platform.isWindows)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Zarządzanie tekstami',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManagementScreen()),
              ),
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
          data: (entries) => _buildCategories(
            context,
            entries: [...entries, ...imported],
            recentIds: recentIds,
            favoriteIds: favoriteIds,
          ),
        ),
      ),
    );
  }

  /// Wczytuje tekst z pliku JSON z pamięci urządzenia i otwiera go.
  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Nie udało się otworzyć pliku: $e')));
      return;
    }
    if (res == null) return; // anulowano
    final bytes = res.files.single.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Nie udało się odczytać pliku.')));
      return;
    }
    try {
      final entry =
          await ref.read(importedControllerProvider.notifier).importBytes(bytes);
      messenger.showSnackBar(SnackBar(
        content: Text('Wczytano: ${entry.title}'),
        duration: const Duration(seconds: 1),
      ));
      navigator.push(
        MaterialPageRoute(builder: (_) => ReaderScreen(entry: entry)),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Niepoprawny plik tekstu: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Błąd importu: $e')));
    }
  }

  Widget _buildCategories(
    BuildContext context, {
    required List<CatalogEntry> entries,
    required List<String> recentIds,
    required Set<String> favoriteIds,
  }) {
    final byId = {for (final e in entries) e.id: e};

    // Ostatnio używane — w kolejności od najnowszych, tylko istniejące.
    final recent = [
      for (final id in recentIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    // Ulubione.
    final favorites = entries.where((e) => favoriteIds.contains(e.id)).toList();

    // Kategorie — w kolejności pierwszego wystąpienia, z licznikami.
    final categories = <String, int>{};
    for (final e in entries) {
      categories[e.category] = (categories[e.category] ?? 0) + 1;
    }

    void open(String title, List<CatalogEntry> list, {String? empty}) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            TextListScreen(title: title, entries: list, emptyMessage: empty),
      ));
    }

    return ListView(
      children: [
        // Zawsze pierwsza: ostatnio używane.
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Ostatnio używane'),
          subtitle: Text(_plTexts(recent.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open('Ostatnio używane', recent,
              empty: 'Nic jeszcze nie czytałeś.'),
        ),
        // Ulubione.
        ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: const Text('Ulubione'),
          subtitle: Text(_plTexts(favorites.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open('Ulubione', favorites,
              empty: 'Brak ulubionych. Dodaj gwiazdką na liście tekstów.'),
        ),
        const Divider(),
        // Kategorie.
        for (final entry in categories.entries)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(entry.key),
            subtitle: Text(_plTexts(entry.value)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(
              entry.key,
              entries.where((e) => e.category == entry.key).toList(),
            ),
          ),
      ],
    );
  }
}
