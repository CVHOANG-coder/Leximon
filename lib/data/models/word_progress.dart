import 'package:equatable/equatable.dart';

/// Một từ người dùng đã học (bảng `word_progress`).
class WordProgress extends Equatable {
  const WordProgress({
    required this.topicId,
    required this.word,
    required this.correctCount,
    required this.wrongCount,
    required this.learnedAt,
    required this.lastSeenAt,
  });

  final int topicId;
  final String word;
  final int correctCount;
  final int wrongCount;
  final DateTime learnedAt;
  final DateTime lastSeenAt;

  factory WordProgress.fromMap(Map<String, dynamic> map) => WordProgress(
        topicId: map['topic_id'] as int,
        word: map['word'] as String,
        correctCount: map['correct_count'] as int,
        wrongCount: map['wrong_count'] as int,
        learnedAt:
            DateTime.fromMillisecondsSinceEpoch(map['learned_at'] as int),
        lastSeenAt:
            DateTime.fromMillisecondsSinceEpoch(map['last_seen_at'] as int),
      );

  @override
  List<Object?> get props => [topicId, word, correctCount, wrongCount];
}
