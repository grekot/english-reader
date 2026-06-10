import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/log_service.dart';

/// Podgląd dziennika błędów aplikacji (do diagnostyki).
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = LogService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dziennik błędów'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Kopiuj całość',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log.exportText()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skopiowano dziennik do schowka')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Wyczyść',
            onPressed: () => log.clear(),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<LogEntry>>(
        valueListenable: log.entries,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Brak zapisanych błędów. To dobrze 🙂\n'
                  'Tu pojawią się ewentualne błędy aplikacji.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final isError = e.level.toLowerCase().contains('error') ||
                  e.level.contains('OTA') ||
                  e.level.contains('Uncaught') ||
                  e.level.contains('Flutter');
              return ListTile(
                dense: true,
                leading: Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: isError ? Colors.red : null,
                  size: 20,
                ),
                title: Text(e.message,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                subtitle: Text(
                    '${e.level} · ${e.time.toString().substring(0, 19)}'),
              );
            },
          );
        },
      ),
    );
  }
}
