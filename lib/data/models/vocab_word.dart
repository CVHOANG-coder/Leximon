import 'package:equatable/equatable.dart';

/// One vocabulary entry from lib/data/sample/all_vocabulary.json.
class VocabWord extends Equatable {
  const VocabWord({
    required this.word,
    required this.pos,
    required this.phonetic,
    required this.meaning,
  });

  final String word;

  /// Part of speech, e.g. "n", "v", "n.phr".
  final String pos;
  final String phonetic;
  final String meaning;

  factory VocabWord.fromJson(Map<String, dynamic> json) => VocabWord(
        word: json['word'] as String? ?? '',
        pos: json['pos'] as String? ?? '',
        phonetic: json['phonetic'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
      );

  @override
  List<Object?> get props => [word, pos, phonetic, meaning];
}
