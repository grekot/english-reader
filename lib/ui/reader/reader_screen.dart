import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offset_mapper.dart';
import '../../data/progress_repository.dart';
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
      final fraction = max > 0 ? offset / max : 0.0;
      ref
          .read(progressRepositoryProvider)
          .save(widget.entry.id, offset, fraction);
    });
  }

  void _restoreOffset() {
    if (_restoredOffset) return;
    _restoredOffset = true;
    final saved = ref.read(progressRepositoryProvider).scrollOffset(widget.entry.id);
    if (saved > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(saved.clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
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
      seconds: settings.bubbleSeconds,
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                return TappableParagraph(
                  paragraph: mapped,
                  style: style,
                  onWordTap: _showWordBubble,
                  onSentenceTap: _showSentenceBubble,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
