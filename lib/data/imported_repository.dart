import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../models/text_document.dart';

const _kImportedKey = 'imported_texts';
const _kImportedCategory = 'Wczytane z pliku';

/// Teksty wczytane z plików JSON z pamięci urządzenia.
///
/// Plik jest kopiowany do katalogu aplikacji, a metadane (z nagłówka pliku)
/// trzymane w SharedPreferences. Wpisy mają `isLocal = true`, więc czytnik
/// wczytuje je z dysku, a nie z sieci.
class ImportedController extends Notifier<List<CatalogEntry>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<CatalogEntry> build() {
    final raw = _prefs.getString(_kImportedKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list)
          CatalogEntry(
            id: e['id'] as String,
            title: e['title'] as String? ?? e['id'] as String,
            author: e['author'] as String?,
            level: e['level'] as String?,
            category: (e['category'] as String?) ?? _kImportedCategory,
            file: e['file'] as String,
            isLocal: true,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/imported');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _persist(List<CatalogEntry> entries) async {
    state = entries;
    final data = [
      for (final e in entries)
        {
          'id': e.id,
          'title': e.title,
          if (e.author != null) 'author': e.author,
          if (e.level != null) 'level': e.level,
          'category': e.category,
          'file': e.file,
        }
    ];
    await _prefs.setString(_kImportedKey, jsonEncode(data));
  }

  /// Importuje tekst z surowych bajtów pliku JSON. Zwraca utworzony wpis.
  /// Rzuca [FormatException], gdy plik nie jest poprawnym tekstem.
  Future<CatalogEntry> importBytes(Uint8List bytes) async {
    final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final id = (doc['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Plik nie ma pola "id".');
    }
    if (doc['paragraphs'] is! List) {
      throw const FormatException('Plik nie zawiera "paragraphs".');
    }

    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dir = await _dir();
    final file = File('${dir.path}/$safeId.json');
    await file.writeAsBytes(bytes);

    final entry = CatalogEntry(
      id: id,
      title: doc['title'] as String? ?? id,
      author: doc['author'] as String?,
      level: doc['level'] as String?,
      category: (doc['category'] as String?) ?? _kImportedCategory,
      file: file.path,
      isLocal: true,
    );

    final next = [entry, ...state.where((e) => e.id != id)];
    await _persist(next);
    return entry;
  }

  Future<void> remove(String id) async {
    for (final e in state) {
      if (e.id == id) {
        try {
          final f = File(e.file);
          if (await f.exists()) await f.delete();
        } catch (_) {/* ignoruj */}
        break;
      }
    }
    await _persist(state.where((e) => e.id != id).toList());
  }
}

final importedControllerProvider =
    NotifierProvider<ImportedController, List<CatalogEntry>>(
        ImportedController.new);
