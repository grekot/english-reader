import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';

/// Sprawdza dostępność aktualizacji i prowadzi użytkownika przez instalację.
///
/// [silent] = true: nic nie pokazuje, gdy brak aktualizacji lub wystąpił błąd
/// (używane przy automatycznym sprawdzaniu na starcie).
Future<void> checkForUpdateInteractive(
  BuildContext context,
  WidgetRef ref, {
  bool silent = false,
}) async {
  final service = ref.read(updateServiceProvider);
  final messenger = ScaffoldMessenger.of(context);

  UpdateInfo? info;
  try {
    info = await service.checkForUpdate();
  } catch (e) {
    if (!silent) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nie udało się sprawdzić aktualizacji: $e')),
      );
    }
    return;
  }

  if (info == null) {
    if (!silent) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Masz najnowszą wersję aplikacji.')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Dostępna aktualizacja'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wersja ${info!.latestVersion} '
              '(masz ${info.currentVersion}).'),
          if (info.releaseNotes != null &&
              info.releaseNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(info.releaseNotes!.trim(),
                maxLines: 8, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Później'),
        ),
        if (service.supportsInAppInstall && info.apkUrl != null)
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _runAndroidInstall(
                  context, service, info!.apkUrl!, info.latestVersion);
            },
            child: const Text('Aktualizuj'),
          )
        else
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(info!.pageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Otwórz stronę pobierania'),
          ),
      ],
    ),
  );
}

Future<void> _runAndroidInstall(
  BuildContext context,
  UpdateService service,
  String apkUrl,
  String version,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Pobieranie aktualizacji…')),
  );
  // Rozwiń przekierowanie GitHub do bezpośredniego URL (stabilne pobieranie).
  final directUrl = await service.resolveDownloadUrl(apkUrl);
  try {
    service.installApk(directUrl, version: version).listen(
      (event) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            // event.value to procent — pokaż okazjonalnie
            break;
          case OtaStatus.INSTALLING:
            messenger.showSnackBar(
              const SnackBar(content: Text('Uruchamiam instalację…')),
            );
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
            messenger.showSnackBar(
              SnackBar(content: Text('Błąd aktualizacji: ${event.value}')),
            );
            break;
          default:
            break;
        }
      },
      onError: (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Błąd aktualizacji: $e')),
        );
      },
      cancelOnError: true,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Nie udało się rozpocząć aktualizacji: $e')),
    );
  }
}
