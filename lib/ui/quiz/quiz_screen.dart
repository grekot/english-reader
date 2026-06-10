import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/quiz_builder.dart';
import '../../data/gamification_repository.dart';
import '../../models/text_document.dart';

/// Menu quizów dla tekstu: słówka (EN→PL, PL→EN) i pytania do tekstu.
class QuizMenuScreen extends StatelessWidget {
  final TextDocument doc;
  const QuizMenuScreen({super.key, required this.doc});

  void _start(BuildContext context, String title, List<QuizQuestion> qs) {
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Za mało materiału na ten quiz.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizRunnerScreen(title: title, questions: qs),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasWords = canBuildWordQuiz(doc);
    final hasAuthored = doc.questions.isNotEmpty;
    final canAuto = canBuildAutoComprehension(doc);
    final comprehensionAvailable = hasAuthored || canAuto;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Słówka: angielski → polski'),
            subtitle: const Text('Pokaż angielskie słowo, wybierz tłumaczenie'),
            enabled: hasWords,
            onTap: () => _start(context, 'Słówka EN → PL',
                buildWordQuiz(doc, enToPl: true, rng: Random())),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Słówka: polski → angielski'),
            subtitle: const Text('Pokaż polskie słowo, wybierz angielskie'),
            enabled: hasWords,
            onTap: () => _start(context, 'Słówka PL → EN',
                buildWordQuiz(doc, enToPl: false, rng: Random())),
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('Pytania do tekstu'),
            subtitle: Text(!comprehensionAvailable
                ? 'Za mało treści na ten quiz'
                : hasAuthored
                    ? 'Pytania z pliku (${doc.questions.length})'
                    : 'Pytania generowane automatycznie (zrozumienie zdań)'),
            enabled: comprehensionAvailable,
            onTap: () => _start(
              context,
              'Pytania do tekstu',
              hasAuthored
                  ? buildComprehension(doc)
                  : buildAutoComprehension(doc, rng: Random()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Przebieg quizu: kolejne pytania wielokrotnego wyboru z natychmiastową oceną.
class QuizRunnerScreen extends ConsumerStatefulWidget {
  final String title;
  final List<QuizQuestion> questions;
  const QuizRunnerScreen({super.key, required this.title, required this.questions});

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;

  void _choose(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == widget.questions[_index].answer) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      setState(() => _finished = true);
      // Nalicz XP za poprawne odpowiedzi (raz, po ukończeniu quizu).
      ref.read(quizScoreProvider.notifier).addCorrect(_score);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult(context);

    final q = widget.questions[_index];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title}  ${_index + 1}/${widget.questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / widget.questions.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    if (q.hint != null)
                      Text(q.hint!,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(q.prompt,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    for (var i = 0; i < q.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _optionButton(i, q, scheme),
                      ),
                    const SizedBox(height: 12),
                    if (_selected != null)
                      FilledButton(
                        onPressed: _next,
                        child: Text(_index + 1 >= widget.questions.length
                            ? 'Zakończ'
                            : 'Następne'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(int i, QuizQuestion q, ColorScheme scheme) {
    Color? bg;
    if (_selected != null) {
      if (i == q.answer) {
        bg = Colors.green.withValues(alpha: 0.25);
      } else if (i == _selected) {
        bg = Colors.red.withValues(alpha: 0.25);
      }
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        alignment: Alignment.centerLeft,
      ),
      onPressed: _selected == null ? () => _choose(i) : null,
      child: Text(q.options[i],
          style: TextStyle(fontSize: 16, color: scheme.onSurface)),
    );
  }

  Widget _buildResult(BuildContext context) {
    final total = widget.questions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(pct >= 60 ? Icons.emoji_events : Icons.school,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('$_score / $total  ($pct%)',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Gotowe'),
            ),
          ],
        ),
      ),
    );
  }
}
