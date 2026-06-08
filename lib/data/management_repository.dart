import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offset_mapper.dart';
import '../core/providers.dart';

const _kRepoPathKey = 'texts_repo_path';

/// Wpis tekstu w trybie zarządzania: dane z index.json + wynik walidacji.
class ManageEntry {
  final Map<String, dynamic> raw;
  final List<String> issues;

  ManageEntry(this.raw, this.issues);

  bool get valid => issues.isEmpty;
  String get id => raw['id'] as String? ?? '';
  String get title => raw['title'] as String? ?? id;
  String? get author => raw['author'] as String?;
  String? get level => raw['level'] as String?;
  String get category => raw['category'] as String? ?? 'Ogólne';
  String get file => raw['file'] as String? ?? '';
}

/// Operacje na lokalnym repozytorium tekstów (folder na dysku):
/// wczytanie katalogu, walidacja tekstów, zapis metadanych + sha256.
class ManagementService {
  final Ref ref;
  ManagementService(this.ref);

  String? get repoPath =>
      ref.read(sharedPreferencesProvider).getString(_kRepoPathKey);

  Future<void> setRepoPath(String path) =>
      ref.read(sharedPreferencesProvider).setString(_kRepoPathKey, path);

  File _indexFile(String repoPath) => File('$repoPath/index.json');

  /// Wczytuje wpisy z index.json i waliduje każdy tekst.
  Future<List<ManageEntry>> load(String repoPath) async {
    final idxFile = _indexFile(repoPath);
    if (!await idxFile.exists()) {
      throw const FileSystemException('Brak index.json w wybranym folderze');
    }
    final idx = jsonDecode(await idxFile.readAsString()) as Map<String, dynamic>;
    final texts = (idx['texts'] as List<dynamic>? ?? const []);
    final result = <ManageEntry>[];
    for (final e in texts) {
      final entry = e as Map<String, dynamic>;
      result.add(ManageEntry(entry, await _validate(repoPath, entry)));
    }
    return result;
  }

  /// Sprawdza poprawność tekstu: istnienie pliku, poprawność JSON oraz czy
  /// każde słowo `w` da się dopasować kolejno w `en`.
  Future<List<String>> _validate(
      String repoPath, Map<String, dynamic> entry) async {
    final rel = entry['file'] as String? ?? '';
    final f = File('$repoPath/$rel');
    if (!await f.exists()) return ['Brak pliku: $rel'];
    final issues = <String>[];
    try {
      final doc = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final paras = doc['paragraphs'] as List<dynamic>? ?? const [];
      var sentenceNo = 0;
      for (final p in paras) {
        final sentences =
            (p as Map<String, dynamic>)['sentences'] as List<dynamic>? ?? const [];
        for (final s in sentences) {
          sentenceNo++;
          final sent = s as Map<String, dynamic>;
          final en = sent['en'] as String? ?? '';
          if (en.isEmpty) issues.add('Zdanie $sentenceNo: brak "en".');
          if ((sent['pl'] as String? ?? '').isEmpty) {
            issues.add('Zdanie $sentenceNo: brak "pl".');
          }
          var cursor = 0;
          for (final t in (sent['tokens'] as List<dynamic>? ?? const [])) {
            final w = (t as Map<String, dynamic>)['w'] as String? ?? '';
            final pos = findWordOccurrence(en, w, cursor);
            if (pos < 0) {
              issues.add('Zdanie $sentenceNo: słowo "$w" nie pasuje do tekstu.');
            } else {
              cursor = pos + w.length;
            }
          }
        }
      }
      if (sentenceNo == 0) issues.add('Tekst nie zawiera zdań.');
    } on FormatException catch (e) {
      issues.add('Błąd JSON: ${e.message}');
    }
    return issues;
  }

  String _sha256OfFile(File f) {
    final bytes = f.readAsBytesSync();
    // Normalizacja końców linii do LF — spójnie z reindex.py i aplikacją.
    final norm = utf8.decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return sha256.convert(utf8.encode(norm)).toString();
  }

  /// Zapisuje zmienione metadane wpisu i przelicza sha256 wszystkich tekstów.
  Future<void> saveMetadata(
    String repoPath,
    String id, {
    required String title,
    String? author,
    String? level,
    required String category,
  }) async {
    final idxFile = _indexFile(repoPath);
    final idx = jsonDecode(await idxFile.readAsString()) as Map<String, dynamic>;
    final texts = (idx['texts'] as List<dynamic>);

    for (final e in texts) {
      final entry = e as Map<String, dynamic>;
      if (entry['id'] == id) {
        entry['title'] = title;
        if (author != null && author.isNotEmpty) {
          entry['author'] = author;
        } else {
          entry.remove('author');
        }
        if (level != null && level.isNotEmpty) {
          entry['level'] = level;
        } else {
          entry.remove('level');
        }
        entry['category'] = category;
      }
      // Przelicz sha256 z aktualnego pliku.
      final f = File('$repoPath/${entry['file']}');
      if (await f.exists()) entry['sha256'] = _sha256OfFile(f);
    }

    final now = DateTime.now();
    idx['updatedAt'] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    const encoder = JsonEncoder.withIndent('  ');
    await idxFile.writeAsString('${encoder.convert(idx)}\n');
  }
}

final managementServiceProvider =
    Provider<ManagementService>((ref) => ManagementService(ref));
