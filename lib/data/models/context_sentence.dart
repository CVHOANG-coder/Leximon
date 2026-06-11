import 'package:equatable/equatable.dart';

/// Câu có ngữ cảnh trong các chặng ôn tập của topics.json
/// (trường `contextSentences`): câu chứa chỗ trống `___`, từ đúng và bản dịch.
class ContextSentence extends Equatable {
  const ContextSentence({
    required this.sentence,
    required this.answer,
    required this.translation,
  });

  /// Ví dụ: "I write with a ___."
  final String sentence;

  /// Từ điền vào chỗ trống, ví dụ: "Pencil".
  final String answer;

  /// Bản dịch tiếng Việt của câu hoàn chỉnh.
  final String translation;

  factory ContextSentence.fromJson(Map<String, dynamic> json) =>
      ContextSentence(
        sentence: json['sentence'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
      );

  @override
  List<Object?> get props => [sentence, answer, translation];
}
