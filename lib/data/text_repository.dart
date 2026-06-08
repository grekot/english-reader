import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/text_document.dart';
import '../services/github_service.dart';

/// Repozytorium tekstów: katalog (index.json) + pojedyncze teksty.
///
/// Strategia offline-first:
/// - katalog: próba sieci, w razie błędu cache, a w ostateczności wbudowany
///   sample;
/// - tekst: jeśli jest w cache, użyj cache; inaczej pobierz z sieci i zapisz.
class TextRepository {
  final GithubService _github;
  TextRepository(this._github);

  static const _bundledSampleAsset = 'assets/sample/alice-ch01.json';

  Future<Directory> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cache = Directory('${dir.path}/texts_cache');
    if (!await cache.exists()) await cache.create(recursive: true);
    return cache;
  }

  Future<File> _cacheFile(String id) async {
    final dir = await _cacheDir();
    return File('${dir.path}/$id.json');
  }

  Future<File> _indexCacheFile() async {
    final dir = await _cacheDir();
    return File('${dir.path}/index.json');
  }

  /// Pobiera katalog tekstów. Zwraca listę wpisów.
  Future<List<CatalogEntry>> loadCatalog({bool forceRefresh = false}) async {
    final indexFile = await _indexCacheFile();
    String? raw;

    try {
      raw = await _github.fetchIndex();
      await indexFile.writeAsString(raw);
    } catch (_) {
      // brak sieci — spróbuj cache
      if (await indexFile.exists()) {
        raw = await indexFile.readAsString();
      }
    }

    // ostateczny fallback: wbudowany sample (pierwsze uruchomienie offline)
    if (raw == null) {
      final sample = await _loadBundledSample();
      return [
        CatalogEntry(
          id: sample.id,
          title: sample.title,
          author: sample.author,
          level: sample.level,
          tags: sample.tags,
          file: _bundledSampleAsset,
        ),
      ];
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final texts = (map['texts'] as List<dynamic>? ?? const [])
        .map((e) => CatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return texts;
  }

  /// Wczytuje pełny dokument tekstu po wpisie katalogu.
  Future<TextDocument> loadDocument(CatalogEntry entry) async {
    // tekst lokalny (wczytany z pliku na urządzeniu)
    if (entry.isLocal) {
      return _parse(await File(entry.file).readAsString());
    }
    // wbudowany sample
    if (entry.file == _bundledSampleAsset) {
      return _loadBundledSample();
    }

    final cacheFile = await _cacheFile(entry.id);
    if (await cacheFile.exists()) {
      try {
        final cached = await cacheFile.readAsString();
        // Cache jest aktualny tylko, gdy zgadza się z sha256 z katalogu.
        // Brak sha256 w katalogu => ufamy cache (offline / brak weryfikacji).
        final fresh = entry.sha256 == null ||
            sha256.convert(utf8.encode(cached)).toString() == entry.sha256;
        if (fresh) return _parse(cached);
      } catch (_) {/* uszkodzony cache — pobierz ponownie */}
    }

    // Cache nieaktualny/uszkodzony lub brak — pobierz świeżą wersję.
    final raw = await _github.fetchTextFile(entry.file);
    await cacheFile.writeAsString(raw);
    return _parse(raw);
  }

  Future<TextDocument> _loadBundledSample() async {
    final raw = await rootBundle.loadString(_bundledSampleAsset);
    return _parse(raw);
  }

  TextDocument _parse(String raw) =>
      TextDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

final textRepositoryProvider = Provider<TextRepository>((ref) {
  return TextRepository(ref.read(githubServiceProvider));
});

/// Provider katalogu tekstów (auto-odświeżany przy invalidacji).
final catalogProvider = FutureProvider<List<CatalogEntry>>((ref) {
  return ref.read(textRepositoryProvider).loadCatalog();
});

/// Provider pełnego dokumentu dla danego wpisu katalogu.
final documentProvider =
    FutureProvider.family<TextDocument, CatalogEntry>((ref, entry) {
  return ref.read(textRepositoryProvider).loadDocument(entry);
});
