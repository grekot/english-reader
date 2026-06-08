import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offset_mapper.dart';
import '../../data/progress_repository.dart';
import '../../data/recent_repository.dart';
import '../../data/settings_repository.dart';
import '../../data/text_repository.dart';
import '../../data/vocab_repository.dart';
import '../../models/text_document.dart';
import '../../models/vocab_entry.dart';
import '../../services/tts_service.dart';
import 'bubble.dart';
import 'tappable_text.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final CatalogEntry entry;
  const ReaderScreen({super.key, required this.entry});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final BubbleManager _bubble = BubbleManager();
  final ScrollController _scroll = ScrollController();
  Timer? _saveDebounce;
  bool _restoredOffset = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Zapisz tekst jako ostatnio otwarty (do listy "Ostatnio używane").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentControllerProvider.notifier).markOpened(widget.entry.id);
    });
  }

  @override
  void dispose() {
    _bubble.hide();
    _saveDebounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final offset = _scroll.offset;
      if (max <= 0) return; // tekst mieści się na ekranie — patrz przycisk ✓
      ref
          .read(progressProvider.notifier)
          .saveScroll(widget.entry.id, offset, offset / max);
    });
  }

  void _restoreOffset() {
    if (_restoredOffset) return;
    _restoredOffset = true;
    final saved =
        ref.read(progressProvider.notifier).scrollOffset(widget.entry.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (saved > 0) {
        _scroll.jumpTo(saved.clamp(0, max));
      }
    });
  }

  /// Interakcja (kliknięcie słowa/zdania) podnosi postęp do głębokości danego
  /// zdania w tekście — sprawdzenie zdania nr N implikuje przeczytanie do N.
  void _registerInteraction(int globalSentenceIndex, int totalSentences) {
    if (totalSentences <= 0) return;
    final frac = (globalSentenceIndex + 1) / totalSentences;
    ref.read(progressProvider.notifier).reachFraction(widget.entry.id, frac);
  }

  void _showWordBubble(HitResult hit) {
    final token = hit.token!.token;
    final settings = ref.read(settingsControllerProvider);
    final tts = ref.read(ttsServiceProvider);
    final vocab = ref.read(vocabControllerProvider.notifier);
    final saved = vocab.contains(token.w, token.lemma);

    _bubble.show(
      context,
      anchor: hit.globalRect,
      seconds: settings.bubbleSeconds,
      child: WordBubbleContent(
        word: token.w,
        translation: token.t,
        lemma: token.lemma,
        ttsAvailable: tts.available,
        alreadySaved: saved,
        onSpeak: () => tts.speak(token.w),
        onSave: () {
          vocab.add(VocabEntry(
            word: token.w,
            translation: token.t,
            lemma: token.lemma,
            textId: widget.entry.id,
            context: hit.sentence.sentence.en,
            addedAt: DateTime.now().toIso8601String(),
          ));
          _showWordBubble(hit); // odśwież dymek (gwiazdka -> zapisane)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zapisano "${token.w}" do fiszek'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  void _showSentenceBubble(HitResult hit) {
    final settings = ref.read(settingsControllerProvider);
    final tts = ref.read(ttsServiceProvider);
    final sentence = hit.sentence.sentence;
    _bubble.show(
      context,
      anchor: hit.globalRect,
      seconds: settings.sentenceBubbleSeconds,
      child: SentenceBubbleContent(
        translation: sentence.pl,
        ttsAvailable: tts.available,
        onSpeak: () => tts.speak(sentence.en),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final docAsync = ref.watch(documentProvider(widget.entry));
    final scheme = Theme.of(context).colorScheme;
    final isRead =
        (ref.watch(progressProvider)[widget.entry.id] ?? 0) >= 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(isRead ? Icons.check_circle : Icons.check_circle_outline),
            color: isRead ? Colors.green : null,
            tooltip:
                isRead ? 'Przeczytane — kliknij, by odznaczyć' : 'Oznacz jako przeczytane',
            onPressed: () => ref
                .read(progressProvider.notifier)
                .setRead(widget.entry.id, !isRead),
          ),
        ],
      ),
      body: docAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Nie udało się wczytać tekstu:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (doc) {
          _restoreOffset();
          final style = TextStyle(
            fontSize: settings.fontSize,
            height: 1.6,
            color: scheme.onSurface,
          );
          // Globalny indeks zdań: baza dla każdego akapitu + łączna liczba zdań.
          final sentenceBase = <int>[];
          var acc = 0;
          for (final p in doc.paragraphs) {
            sentenceBase.add(acc);
            acc += p.sentences.length;
          }
          final totalSentences = acc;
          return GestureDetector(
            // stuknięcie poza tekstem chowa dymek
            behavior: HitTestBehavior.translucent,
            onTap: _bubble.hide,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              itemCount: doc.paragraphs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final mapped = MappedParagraph.build(doc.paragraphs[i]);
                final base = sentenceBase[i];
                return TappableParagraph(
                  paragraph: mapped,
                  style: style,
                  onWordTap: (hit) {
                    _showWordBubble(hit);
                    _registerInteraction(
                        base + hit.sentence.sentenceIndex, totalSentences);
                  },
                  onSentenceTap: (hit) {
                    _showSentenceBubble(hit);
                    _registerInteraction(
                        base + hit.sentence.sentenceIndex, totalSentences);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
