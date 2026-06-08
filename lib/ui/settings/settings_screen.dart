import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';

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
            title: const Text('Czas znikania dymka'),
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
        ],
      ),
    );
  }
}
