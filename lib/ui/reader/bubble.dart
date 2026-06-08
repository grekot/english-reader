import 'dart:async';

import 'package:flutter/material.dart';

/// Zarządza pojedynczym dymkiem-nakładką (OverlayEntry) z auto-znikaniem.
class BubbleManager {
  OverlayEntry? _entry;
  Timer? _timer;
  int _seconds = 2;

  void show(
    BuildContext context, {
    required Rect anchor,
    required Widget child,
    required int seconds,
  }) {
    hide();
    _seconds = seconds;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => _PositionedBubble(
        anchor: anchor,
        onInteract: cancelTimer,
        child: child,
      ),
    );
    overlay.insert(_entry!);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: _seconds), hide);
  }

  /// Anuluje auto-znikanie (np. gdy użytkownik dotyka dymka).
  void cancelTimer() => _timer?.cancel();

  void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// Pozycjonuje dymek nad zakotwiczeniem (anchor), z przycięciem do ekranu.
class _PositionedBubble extends StatelessWidget {
  final Rect anchor;
  final Widget child;
  final VoidCallback onInteract;

  const _PositionedBubble({
    required this.anchor,
    required this.child,
    required this.onInteract,
  });

  static const double _maxWidth = 280;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;

    final centerX = anchor.center.dx;
    var left = centerX - _maxWidth / 2;
    left = left.clamp(8.0, (screen.width - _maxWidth - 8).clamp(8.0, screen.width));

    final spaceAbove = anchor.top - media.padding.top;
    final showAbove = spaceAbove > 90;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: showAbove ? null : anchor.bottom + _gap,
          bottom: showAbove ? (screen.height - anchor.top + _gap) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Listener(
              onPointerDown: (_) => onInteract(),
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Zawartość dymka dla słowa: tłumaczenie + lemat + akcje (TTS, zapis).
class WordBubbleContent extends StatelessWidget {
  final String word;
  final String? translation;
  final String? lemma;
  final bool ttsAvailable;
  final bool alreadySaved;
  final VoidCallback onSpeak;
  final VoidCallback onSave;

  const WordBubbleContent({
    super.key,
    required this.word,
    required this.translation,
    required this.lemma,
    required this.ttsAvailable,
    required this.alreadySaved,
    required this.onSpeak,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 6,
      color: scheme.inverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translation == null || translation!.isEmpty ? '—' : translation!,
              style: TextStyle(
                color: scheme.onInverseSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (lemma != null && lemma!.toLowerCase() != word.toLowerCase())
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'forma podstawowa: $lemma',
                  style: TextStyle(
                    color: scheme.onInverseSurface.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ttsAvailable)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.volume_up, color: scheme.onInverseSurface),
                    tooltip: 'Wymowa',
                    onPressed: onSpeak,
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    alreadySaved ? Icons.star : Icons.star_border,
                    color: scheme.onInverseSurface,
                  ),
                  tooltip: alreadySaved ? 'Zapisane' : 'Zapisz do fiszek',
                  onPressed: alreadySaved ? null : onSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Zawartość dymka dla zdania: pełne tłumaczenie.
class SentenceBubbleContent extends StatelessWidget {
  final String translation;
  final bool ttsAvailable;
  final VoidCallback onSpeak;

  const SentenceBubbleContent({
    super.key,
    required this.translation,
    required this.ttsAvailable,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 6,
      color: scheme.inverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                translation,
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            if (ttsAvailable)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.volume_up, color: scheme.onInverseSurface),
                tooltip: 'Przeczytaj zdanie',
                onPressed: onSpeak,
              ),
          ],
        ),
      ),
    );
  }
}
