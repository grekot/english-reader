import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import 'log_screen.dart';

/// Ekran „O aplikacji": wersja, opis, linki, status, dziennik błędów.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool supabaseOk;
    try {
      // Rzuca, jeśli Supabase nie został zainicjalizowany.
      Supabase.instance.client;
      supabaseOk = true;
    } catch (_) {
      supabaseOk = false;
    }

    final appRepo = 'https://github.com/${AppConfig.appOwner}/${AppConfig.appRepo}';
    final textsRepo =
        'https://github.com/${AppConfig.textsOwner}/${AppConfig.textsRepo}';

    return Scaffold(
      appBar: AppBar(title: const Text('O aplikacji')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const Icon(Icons.menu_book, size: 56),
                const SizedBox(height: 8),
                Text('Nauka angielskiego',
                    style: Theme.of(context).textTheme.titleLarge),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Text(
                    snap.hasData
                        ? 'Wersja ${snap.data!.version} (build ${snap.data!.buildNumber})'
                        : '…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Nauka angielskiego przez czytanie: stuknij słowo, by zobaczyć '
              'tłumaczenie, dwukrotnie zdanie — całe. Quizy, fiszki, statystyki '
              'i ranking rodzinny.',
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Repozytorium aplikacji'),
            subtitle: Text(appRepo),
            onTap: () => _open(appRepo),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Repozytorium tekstów'),
            subtitle: Text(textsRepo),
            onTap: () => _open(textsRepo),
          ),
          ListTile(
            leading: Icon(supabaseOk ? Icons.cloud_done : Icons.cloud_off,
                color: supabaseOk ? Colors.green : Colors.orange),
            title: const Text('Ranking (Supabase)'),
            subtitle: Text(supabaseOk ? 'Połączenie skonfigurowane' : 'Niedostępne'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Dziennik błędów'),
            subtitle: const Text('Podgląd błędów aplikacji (diagnostyka)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
