import 'package:flutter_test/flutter_test.dart';

import 'package:nauka_angielskiego/core/offset_mapper.dart';
import 'package:nauka_angielskiego/models/text_document.dart';

void main() {
  test('MappedParagraph mapuje stuknięcie na właściwy token', () {
    final paragraph = Paragraph(sentences: [
      const Sentence(
        en: 'Alice was very tired.',
        pl: 'Alicja była bardzo zmęczona.',
        tokens: [
          Token(w: 'Alice', t: 'Alicja', lemma: 'Alice'),
          Token(w: 'was', t: 'była', lemma: 'be'),
          Token(w: 'very', t: 'bardzo', lemma: 'very'),
          Token(w: 'tired', t: 'zmęczona', lemma: 'tired'),
        ],
      ),
    ]);

    final mapped = MappedParagraph.build(paragraph);

    // offset 0 wskazuje "Alice"
    expect(mapped.tokenAt(0)?.token.w, 'Alice');
    // "very" zaczyna się po "Alice was " (10 znaków)
    expect(mapped.tokenAt(10)?.token.w, 'very');
    // kropka na końcu nie jest tokenem
    expect(mapped.tokenAt(mapped.text.length - 1), isNull);
    // każdy offset trafia w to samo zdanie
    expect(mapped.sentenceAt(3)?.sentence.pl, 'Alicja była bardzo zmęczona.');
  });
}
