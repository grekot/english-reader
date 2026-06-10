import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'github_service.dart';

/// Informacje o dostępnej aktualizacji.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String? apkUrl; // asset .apk (Android)
  final String pageUrl; // strona wydania (Windows / fallback)
  final String? releaseNotes;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.apkUrl,
    required this.pageUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  final GithubService _github;
  UpdateService(this._github);

  /// Sprawdza, czy dostępna jest nowsza wersja. Zwraca null, gdy brak.
  Future<UpdateInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;

    final release = await _github.fetchLatestRelease();
    if (release == null) return null; // brak opublikowanych wydań
    final tag = (release['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) return null;
    if (!_isNewer(tag, current)) return null;

    String? apkUrl;
    final assets = release['assets'] as List<dynamic>? ?? const [];
    for (final a in assets) {
      final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }

    return UpdateInfo(
      currentVersion: current,
      latestVersion: tag,
      apkUrl: apkUrl,
      pageUrl: release['html_url'] as String? ?? '',
      releaseNotes: release['body'] as String?,
    );
  }

  /// Porównanie wersji w stylu semver (a > b?).
  bool _isNewer(String a, String b) {
    List<int> parse(String v) => v
        .split(RegExp(r'[.+-]'))
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  bool get supportsInAppInstall => Platform.isAndroid;

  /// Rozwija przekierowania (GitHub `browser_download_url` → 302 do
  /// objects.githubusercontent.com), zwracając finalny, bezpośredni URL.
  /// Część klientów HTTP na Androidzie nie podąża za tym przekierowaniem,
  /// co psuło pobieranie — dlatego robimy to sami.
  Future<String> resolveDownloadUrl(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      var current = url;
      for (var i = 0; i < 6; i++) {
        final req = await client.getUrl(Uri.parse(current));
        req.followRedirects = false;
        final res = await req.close();
        final code = res.statusCode;
        if (code >= 300 && code < 400) {
          final loc = res.headers.value(HttpHeaders.locationHeader);
          unawaited(res.drain());
          if (loc == null || loc.isEmpty) break;
          current = Uri.parse(current).resolve(loc).toString();
        } else {
          unawaited(res.drain());
          break;
        }
      }
      return current;
    } catch (_) {
      return url; // w razie błędu spróbuj oryginalnego URL
    } finally {
      client.close(force: true);
    }
  }

  /// Uruchamia pobranie i instalację APK (tylko Android). Plik zapisywany jest
  /// pod unikalną nazwą per wersja, by nigdy nie zainstalować starego pliku.
  Stream<OtaEvent> installApk(String apkUrl, {required String version}) {
    final safe = version.replaceAll(RegExp(r'[^0-9A-Za-z.]'), '');
    return OtaUpdate()
        .execute(apkUrl, destinationFilename: 'english-reader-$safe.apk');
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref.read(githubServiceProvider));
});
