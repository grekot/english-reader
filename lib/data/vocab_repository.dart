import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/vocab_entry.dart';

/// Lista zapisanych słówek (fiszek) trzymana w pliku JSON w katalogu danych
/// aplikacji. Działa identycznie na Androidzie i Windows.
class VocabController extends AsyncNotifier<List<VocabEntry>> {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vocab.json');
  }

  @override
  Future<List<VocabEntry>> build() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VocabEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<VocabEntry> entries) async {
    state = AsyncData(entries);
    final file = await _file();
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Dodaje słowo, jeśli nie istnieje już taki sam wpis (po kluczu).
  Future<void> add(VocabEntry entry) async {
    final current = state.value ?? [];
    if (current.any((e) => e.key == entry.key)) return;
    await _save([entry, ...current]);
  }

  Future<void> remove(VocabEntry entry) async {
    final current = state.value ?? [];
    await _save(current.where((e) => e.key != entry.key).toList());
  }

  bool contains(String word, String? lemma) {
    final entry = VocabEntry(word: word, lemma: lemma, addedAt: '');
    return (state.value ?? []).any((e) => e.key == entry.key);
  }
}

final vocabControllerProvider =
    AsyncNotifierProvider<VocabController, List<VocabEntry>>(
        VocabController.new);
