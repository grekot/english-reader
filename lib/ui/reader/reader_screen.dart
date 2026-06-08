import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offset_mapper.dart';
import '../../data/lookups_repository.dart';
import '../../data/progress_repository.dart';
import '../../data/recent_repository.dart';
import '../../data/settings_repository.dart';
import '../../data/stats_repository.dart';
import '../glossary/glossary_screen.dart';
import '../quiz/quiz_screen.dart';
import '../../data/text_repository.dart';
import '../../data/vocab_repository.dart';
import '../../models/text_document.dart';
import '../../models/vocab_entry.dart';
import '../../services/read_aloud.dart';
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
  final Stopwatch _readWatch = Stopwatch()..start();
  Timer? _saveDebounce;
  bool _restoredOffset = false;

  // Tryb dwujęzyczny (pokaż tłumaczenie pod akapitem)
  bool _interlinear = false;

  // Czytanie na głos
  final ReadAloudPlayer _player = ReadAloudPlayer();
  bool _playing = false;
  int _hlPara = -1;
  (int, int)? _hl;
  List<MappedParagraph>? _mapped;
  TextDocument? _mappedDoc;
  List<GlobalKey> _paraKeys = const [];

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
    // Dolicz czas spędzony na czytaniu do statystyk dnia.
    _readWatch.stop();
    ref.read(statsControllerProvider.notifier).addReadingTime(_readWatch.elapsed);
    _player.stop();
    _bubble.hide();
    _saveDebounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Buduje (i zapamiętuje) zmapowane akapity dla bieżącego dokumentu.
  List<MappedParagraph> _ensureMapped(TextDocument doc) {
    if (_mappedDoc != doc || _mapped == null) {
      _mapped = doc.paragraphs.map(MappedParagraph.build).toList();
      _mappedDoc = doc;
      _paraKeys = List.generate(doc.paragraphs.length, (_) => GlobalKey());
    }
    return _mapped!;
  }

  Future<void> _toggleReadAloud(TextDocument doc) async {
    if (_playing) {
      await _player.stop();
      setState(() {
        _playing = false;
        _hlPara = -1;
        _hl = null;
      });
      return;
    }
    final mapped = _ensureMapped(doc);
    final settings = ref.read(settingsControllerProvider);
    _bubble.hide();
    _player.onParagraph = (i) {
      setState(() {
        _hlPara = i;
        _hl = null;
      });
      _ensureParaVisible(i);
    };
    _player.onWord = (i, start, end) {
      if (!mounted) return;
      setState(() {
        _hlPara = i;
        _hl = (start, end);
      });
    };
    _player.onDone = () {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _hlPara = -1;
        _hl = null;
      });
    };
    setState(() => _playing = true);
    await _player.start(
      [for (final m in mapped) m.text],
      language: settings.ttsLanguage,
      rate: settings.ttsRate,
    );
  }

  void _ensureParaVisible(int i) {
    if (i < 0 || i >= _paraKeys.length) return;
    final ctx = _paraKeys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.1, duration: const Duration(milliseconds: 300));
    }
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
    // Zapisz do glosariusza tekstu (słowa sprawdzone).
    ref
        .read(lookupsControllerProvider.notifier)
        .record(widget.entry.id, token.w, token.t, token.lemma);
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
            icon: Icon(_interlinear ? Icons.translate : Icons.g_translate),
            color: _interlinear ? Colors.green : null,
            tooltip: _interlinear
                ? 'Ukryj tłumaczenia zdań'
                : 'Pokaż tłumaczenia zdań (dwujęzycznie)',
            onPressed: () => setState(() => _interlinear = !_interlinear),
          ),
          IconButton(
            icon: Icon(_playing ? Icons.stop : Icons.volume_up),
            tooltip: _playing ? 'Zatrzymaj czytanie' : 'Czytaj na głos',
            onPressed: docAsync.value == null
                ? null
                : () => _toggleReadAloud(docAsync.value!),
          ),
          IconButton(
            icon: const Icon(Icons.quiz),
            tooltip: 'Quiz',
            onPressed: docAsync.value == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            QuizMenuScreen(doc: docAsync.value!),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Glosariusz (sprawdzone słowa)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GlossaryScreen(
                  textId: widget.entry.id,
                  textTitle: widget.entry.title,
                ),
              ),
            ),
          ),
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
          final mappedList = _ensureMapped(doc);
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
              itemCount: mappedList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final base = sentenceBase[i];
                final paragraph = TappableParagraph(
                  key: _paraKeys[i],
                  paragraph: mappedList[i],
                  style: style,
                  highlight: _hlPara == i ? _hl : null,
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
                if (!_interlinear) return paragraph;
                final pl = doc.paragraphs[i].sentences
                    .map((s) => s.pl)
                    .join(' ');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    paragraph,
                    const SizedBox(height: 6),
                    Text(
                      pl,
                      style: TextStyle(
                        fontSize: settings.fontSize - 2,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
