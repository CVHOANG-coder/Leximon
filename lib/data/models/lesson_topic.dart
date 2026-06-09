import 'package:equatable/equatable.dart';

class LessonTopic extends Equatable {
  final String id;
  final String title;
  final String emoji;
  final int wordCount;

  const LessonTopic({
    required this.id,
    required this.title,
    required this.emoji,
    required this.wordCount,
  });

  @override
  List<Object?> get props => [id, title, emoji, wordCount];
}
