import 'package:flutter/material.dart';

import '../../core/offset_mapper.dart';

/// Wynik trafienia w słowo/zdanie — przekazywany do czytnika w celu pokazania
/// dymka nad właściwym miejscem.
class HitResult {
  final Rect globalRect;
  final TokenSpan? token;
  final SentenceSpan sentence;
  const HitResult({
    required this.globalRect,
    required this.token,
    required this.sentence,
  });
}

/// Renderuje akapit i wykrywa stuknięcia w pojedyncze słowa (pojedyncze
/// stuknięcie) oraz w całe zdanie (podwójne stuknięcie) za pomocą TextPainter.
class TappableParagraph extends StatefulWidget {
  final MappedParagraph paragraph;
  final TextStyle style;
  final void Function(HitResult hit) onWordTap;
  final void Function(HitResult hit) onSentenceTap;

  const TappableParagraph({
    super.key,
    required this.paragraph,
    required this.style,
    required this.onWordTap,
    required this.onSentenceTap,
  });

  @override
  State<TappableParagraph> createState() => _TappableParagraphState();
}

class _TappableParagraphState extends State<TappableParagraph> {
  final GlobalKey _paintKey = GlobalKey();
  TextPainter? _painter;
  double _lastWidth = -1;

  TextPainter _ensurePainter(double maxWidth) {
    if (_painter != null && _lastWidth == maxWidth) return _painter!;
    final tp = TextPainter(
      text: TextSpan(text: widget.paragraph.text, style: widget.style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: maxWidth);
    _painter = tp;
    _lastWidth = maxWidth;
    return tp;
  }

  int _charAt(Offset localPos) {
    final painter = _painter;
    if (painter == null) return -1;
    return painter.getPositionForOffset(localPos).offset;
  }

  Rect _globalRectFor(int start, int end) {
    final painter = _painter!;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    final renderBox =
        _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (boxes.isEmpty || renderBox == null) {
      return Rect.zero;
    }
    final local = boxes.first.toRect();
    final topLeft = renderBox.localToGlobal(local.topLeft);
    return topLeft & Size(local.width, local.height);
  }

  void _handleSingleTap(Offset localPos) {
    final char = _charAt(localPos);
    if (char < 0) return;
    final sentence = widget.paragraph.sentenceAt(char);
    if (sentence == null) return;
    final token = widget.paragraph.tokenAt(char);
    if (token == null) return; // trafiono interpunkcję/spację — ignoruj
    widget.onWordTap(HitResult(
      globalRect: _globalRectFor(token.start, token.end),
      token: token,
      sentence: sentence,
    ));
  }

  void _handleDoubleTap(Offset localPos) {
    final char = _charAt(localPos);
    if (char < 0) return;
    final sentence = widget.paragraph.sentenceAt(char);
    if (sentence == null) return;
    widget.onSentenceTap(HitResult(
      globalRect: _globalRectFor(sentence.start, sentence.end),
      token: null,
      sentence: sentence,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = _ensurePainter(constraints.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _handleSingleTap(d.localPosition),
          onDoubleTapDown: (d) => _handleDoubleTap(d.localPosition),
          onDoubleTap: () {}, // wymagane, by onDoubleTapDown działało
          child: CustomPaint(
            key: _paintKey,
            size: Size(constraints.maxWidth, painter.height),
            painter: _ParagraphPainter(painter),
          ),
        );
      },
    );
  }
}

class _ParagraphPainter extends CustomPainter {
  final TextPainter painter;
  _ParagraphPainter(this.painter);

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _ParagraphPainter old) =>
      old.painter != painter;
}
