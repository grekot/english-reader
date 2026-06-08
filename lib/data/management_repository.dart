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

  /// Czy suma kontrolna pliku różni się od zapisanej w index.json (plik zmieniony).
  final bool shaChanged;

  ManageEntry(this.raw, this.issues, {this.shaChanged = false});

  bool get valid => issues.isEmpty;
  String get id => raw['id'] as String? ?? '';
  String get title => raw['title'] as String? ?? id;
  String? get author => raw['author'] as String?;
  String? get level => raw['level'] as String?;
  String get category => raw['category'] as String? ?? 'Ogólne';
  String get file => raw['file'] as String? ?? '';
}

/// Wynik skanowania repozytorium: wpisy z index.json + pliki nieprzypisane.
class ManageScan {
  final List<ManageEntry> entries;

  /// Pliki .json w texts/, których nie ma w index.json (do dodania).
  final List<String> orphanFiles;

  ManageScan(this.entries, this.orphanFiles);

  bool get anyShaChanged => entries.any((e) => e.shaChanged);
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

  /// Zwraca folder zawierający index.json: wybrany, albo jego rodzic (gdy ktoś
  /// wskazał podfolder `texts`). null, gdy nie znaleziono.
  String? resolveRepoRoot(String chosen) {
    if (File('$chosen/index.json').existsSync()) return chosen;
    final parent = Directory(chosen).parent.path;
    if (File('$parent/index.json').existsSync()) return parent;
    return null;
  }

  File _indexFile(String repoPath) => File('$repoPath/index.json');

  /// Skanuje repozytorium: wpisy z index.json (z walidacją i statusem sumy)
  /// oraz pliki w texts/ nieobecne w katalogu.
  Future<ManageScan> scan(String repoPath) async {
    final idxFile = _indexFile(repoPath);
    if (!await idxFile.exists()) {
      throw const FileSystemException(
          'Brak index.json — wskaż główny folder repozytorium (ten, który '
          'zawiera index.json oraz podfolder texts/), a nie sam folder texts.');
    }
    final idx = jsonDecode(await idxFile.readAsString()) as Map<String, dynamic>;
    final texts = (idx['texts'] as List<dynamic>? ?? const []);
    final referenced = <String>{};
    final result = <ManageEntry>[];
    for (final e in texts) {
      final entry = e as Map<String, dynamic>;
      final rel = (entry['file'] as String? ?? '').replaceAll('\\', '/');
      referenced.add(rel);
      final issues = await _validate(repoPath, entry);
      var shaChanged = false;
      final f = File('$repoPath/${entry['file']}');
      if (await f.exists()) {
        shaChanged = entry['sha256'] != _sha256OfFile(f);
      }
      result.add(ManageEntry(entry, issues, shaChanged: shaChanged));
    }

    // Pliki .json w texts/ nieprzypisane do żadnego wpisu.
    final orphans = <String>[];
    final textsDir = Directory('$repoPath/texts');
    if (await textsDir.exists()) {
      await for (final f in textsDir.list()) {
        if (f is File && f.path.toLowerCase().endsWith('.json')) {
          final rel = 'texts/${f.uri.pathSegments.last}';
          if (!referenced.contains(rel)) orphans.add(rel);
        }
      }
    }
    orphans.sort();
    return ManageScan(result, orphans);
  }

  void _recomputeAllSha(String repoPath, Map<String, dynamic> idx) {
    for (final e in (idx['texts'] as List<dynamic>)) {
      final entry = e as Map<String, dynamic>;
      final f = File('$repoPath/${entry['file']}');
      if (f.existsSync()) entry['sha256'] = _sha256OfFile(f);
    }
  }

  Future<void> _stampAndWrite(File idxFile, Map<String, dynamic> idx) async {
    final now = DateTime.now();
    idx['updatedAt'] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const encoder = JsonEncoder.withIndent('  ');
    await idxFile.writeAsString('${encoder.convert(idx)}\n');
  }

  /// Dodaje (lub aktualizuje) wpis dla pliku tekstu i przelicza sumy.
  Future<void> addFile(String repoPath, String relFile,
      {String? category}) async {
    final f = File('$repoPath/$relFile');
    final doc = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final id = (doc['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Plik nie ma pola "id".');
    }
    final idxFile = _indexFile(repoPath);
    final idx = jsonDecode(await idxFile.readAsString()) as Map<String, dynamic>;
    final texts = (idx['texts'] as List<dynamic>);
    texts.removeWhere((e) => (e as Map<String, dynamic>)['id'] == id);
    final entry = <String, dynamic>{
      'id': id,
      'title': doc['title'] ?? id,
      'category': category ?? doc['category'] ?? 'Ogólne',
      'file': relFile.replaceAll('\\', '/'),
    };
    if (doc['author'] != null) entry['author'] = doc['author'];
    if (doc['level'] != null) entry['level'] = doc['level'];
    if (doc['tags'] != null) entry['tags'] = doc['tags'];
    texts.add(entry);
    _recomputeAllSha(repoPath, idx);
    await _stampAndWrite(idxFile, idx);
  }

  /// Przelicza sumy kontrolne wszystkich tekstów i zapisuje index.json.
  Future<void> refreshChecksums(String repoPath) async {
    final idxFile = _indexFile(repoPath);
    final idx = jsonDecode(await idxFile.readAsString()) as Map<String, dynamic>;
    _recomputeAllSha(repoPath, idx);
    await _stampAndWrite(idxFile, idx);
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
