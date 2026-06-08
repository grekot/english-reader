/// Modele danych tekstu czytanego w aplikacji.
///
/// Plik tekstu (JSON) ma strukturę:
///   document -> paragraphs[] -> sentences[] -> tokens[]
/// gdzie `en` zdania jest autorytatywnym tekstem do wyświetlenia, a `tokens`
/// to uporządkowana lista słów do stuknięcia (każde `w` jest podłańcuchem `en`).
library;

/// Pojedyncze słowo do stuknięcia.
class Token {
  /// Słowo dokładnie tak, jak występuje w tekście `en` zdania.
  final String w;

  /// Kontekstowe polskie tłumaczenie (null = brak — np. słowo funkcyjne).
  final String? t;

  /// Angielska forma podstawowa (lemat), np. "go" dla "went".
  final String? lemma;

  const Token({required this.w, this.t, this.lemma});

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      w: json['w'] as String,
      t: json['t'] as String?,
      lemma: json['lemma'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'w': w,
        if (t != null) 't': t,
        if (lemma != null) 'lemma': lemma,
      };
}

/// Zdanie: oryginał (`en`), tłumaczenie całości (`pl`) i tokeny.
class Sentence {
  final String en;
  final String pl;
  final List<Token> tokens;

  const Sentence({required this.en, required this.pl, required this.tokens});

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      en: json['en'] as String,
      pl: json['pl'] as String? ?? '',
      tokens: (json['tokens'] as List<dynamic>? ?? const [])
          .map((e) => Token.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Akapit: lista zdań.
class Paragraph {
  final List<Sentence> sentences;

  const Paragraph({required this.sentences});

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    return Paragraph(
      sentences: (json['sentences'] as List<dynamic>? ?? const [])
          .map((e) => Sentence.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Cały dokument tekstu.
class TextDocument {
  final int schemaVersion;
  final String id;
  final String title;
  final String? author;
  final String? source;
  final String? level;
  final List<String> tags;
  final String? createdAt;
  final List<Paragraph> paragraphs;

  const TextDocument({
    required this.schemaVersion,
    required this.id,
    required this.title,
    this.author,
    this.source,
    this.level,
    this.tags = const [],
    this.createdAt,
    required this.paragraphs,
  });

  factory TextDocument.fromJson(Map<String, dynamic> json) {
    return TextDocument(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String,
      title: json['title'] as String? ?? json['id'] as String,
      author: json['author'] as String?,
      source: json['source'] as String?,
      level: json['level'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      createdAt: json['createdAt'] as String?,
      paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
          .map((e) => Paragraph.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Wpis katalogu (z `index.json`) — metadane tekstu bez pełnej treści.
class CatalogEntry {
  final String id;
  final String title;
  final String? author;
  final String? level;
  final List<String> tags;
  final String file;
  final String? sha256;

  const CatalogEntry({
    required this.id,
    required this.title,
    this.author,
    this.level,
    this.tags = const [],
    required this.file,
    this.sha256,
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    return CatalogEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['id'] as String,
      author: json['author'] as String?,
      level: json['level'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      file: json['file'] as String,
      sha256: json['sha256'] as String?,
    );
  }
}
