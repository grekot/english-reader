import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Cienka warstwa nad HTTP do pobierania danych z GitHub (raw + API wydań).
class GithubService {
  final http.Client _client;
  GithubService([http.Client? client]) : _client = client ?? http.Client();

  /// Pobiera surowy tekst pliku z repozytorium tekstów.
  Future<String> fetchRaw(String url) async {
    final res = await _client.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania ($url): HTTP ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<String> fetchIndex() => fetchRaw(AppConfig.indexUrl);

  Future<String> fetchTextFile(String relativePath) =>
      fetchRaw(AppConfig.textUrl(relativePath));

  /// Pobiera metadane najnowszego wydania aplikacji z GitHub API.
  Future<Map<String, dynamic>> fetchLatestRelease() async {
    final res = await _client.get(
      Uri.parse(AppConfig.latestReleaseApiUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode != 200) {
      throw Exception('Błąd pobierania wydania: HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}

final githubServiceProvider = Provider<GithubService>((ref) => GithubService());
