import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/settings_repository.dart';
import '../about/about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tryb ciemny'),
            value: settings.darkMode,
            onChanged: ctrl.setDarkMode,
          ),
          const Divider(),
          ListTile(
            title: const Text('Rozmiar czcionki'),
            subtitle: Slider(
              min: 12,
              max: 32,
              divisions: 20,
              label: settings.fontSize.round().toString(),
              value: settings.fontSize,
              onChanged: ctrl.setFontSize,
            ),
            trailing: Text('${settings.fontSize.round()}'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Czas dymka słowa'),
            subtitle: Slider(
              min: 1,
              max: 10,
              divisions: 9,
              label: '${settings.bubbleSeconds} s',
              value: settings.bubbleSeconds.toDouble(),
              onChanged: (v) => ctrl.setBubbleSeconds(v.round()),
            ),
            trailing: Text('${settings.bubbleSeconds} s'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Czas dymka zdania'),
            subtitle: Slider(
              min: 2,
              max: 20,
              divisions: 18,
              label: '${settings.sentenceBubbleSeconds} s',
              value: settings.sentenceBubbleSeconds.toDouble(),
              onChanged: (v) => ctrl.setSentenceBubbleSeconds(v.round()),
            ),
            trailing: Text('${settings.sentenceBubbleSeconds} s'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Dzienny cel czytania'),
            subtitle: Slider(
              min: 5,
              max: 60,
              divisions: 11,
              label: '${settings.dailyGoalMinutes} min',
              value: settings.dailyGoalMinutes.toDouble(),
              onChanged: (v) => ctrl.setDailyGoalMinutes(v.round()),
            ),
            trailing: Text('${settings.dailyGoalMinutes} min'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Tempo lektora'),
            subtitle: Slider(
              min: 0.2,
              max: 0.8,
              divisions: 12,
              label: settings.ttsRate.toStringAsFixed(2),
              value: settings.ttsRate,
              onChanged: ctrl.setTtsRate,
            ),
            trailing: Text(settings.ttsRate.toStringAsFixed(2)),
          ),
          const Divider(),
          ListTile(
            title: const Text('Język wymowy (TTS)'),
            trailing: DropdownButton<String>(
              value: settings.ttsLanguage,
              items: const [
                DropdownMenuItem(value: 'en-US', child: Text('Angielski (US)')),
                DropdownMenuItem(value: 'en-GB', child: Text('Angielski (UK)')),
              ],
              onChanged: (v) {
                if (v != null) ctrl.setTtsLanguage(v);
              },
            ),
          ),
          const Divider(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.hasData
                  ? '${snap.data!.version} (build ${snap.data!.buildNumber})'
                  : '…';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('O aplikacji'),
                subtitle: Text('Wersja $v · linki · dziennik błędów'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
