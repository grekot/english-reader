import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Pojedynczy wpis dziennika.
class LogEntry {
  final DateTime time;
  final String level;
  final String message;

  const LogEntry(this.time, this.level, this.message);

  Map<String, dynamic> toJson() =>
      {'t': time.toIso8601String(), 'l': level, 'm': message};

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now(),
        j['l'] as String? ?? 'info',
        j['m'] as String? ?? '',
      );
}

/// Prosty dziennik aplikacji: trzyma ostatnie wpisy w pamięci i zapisuje je
/// do pliku w katalogu danych. Przechwytuje też nieobsłużone wyjątki (ustawione
/// w main). Dostępny globalnie przez [LogService.instance].
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  static const int _maxEntries = 300;

  final ValueNotifier<List<LogEntry>> entries =
      ValueNotifier<List<LogEntry>>(const []);

  File? _file;
  bool _writing = false;
  bool _dirty = false;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/app_log.json');
      if (await _file!.exists()) {
        final raw = await _file!.readAsString();
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        entries.value = list;
      }
    } catch (_) {/* dziennik nie jest krytyczny */}
  }

  void log(String level, String message) {
    final entry = LogEntry(DateTime.now(), level, message);
    final next = [entry, ...entries.value];
    if (next.length > _maxEntries) next.removeRange(_maxEntries, next.length);
    entries.value = next;
    if (kDebugMode) debugPrint('[$level] $message');
    _persist();
  }

  void error(String message, [Object? error, StackTrace? stack]) {
    final buf = StringBuffer(message);
    if (error != null) buf.write('\n$error');
    if (stack != null) {
      final s = stack.toString();
      buf.write('\n${s.length > 800 ? s.substring(0, 800) : s}');
    }
    log('error', buf.toString());
  }

  Future<void> _persist() async {
    _dirty = true;
    if (_writing || _file == null) return;
    _writing = true;
    try {
      while (_dirty) {
        _dirty = false;
        await _file!.writeAsString(
            jsonEncode(entries.value.map((e) => e.toJson()).toList()));
      }
    } catch (_) {/* ignoruj */} finally {
      _writing = false;
    }
  }

  Future<void> clear() async {
    entries.value = const [];
    try {
      if (_file != null && await _file!.exists()) await _file!.delete();
    } catch (_) {/* ignoruj */}
  }

  String exportText() {
    return entries.value
        .map((e) => '${e.time.toIso8601String()} [${e.level}] ${e.message}')
        .join('\n');
  }
}
