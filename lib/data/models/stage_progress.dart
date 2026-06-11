import 'package:equatable/equatable.dart';

/// Kết quả một chặng đã chơi (bảng `stage_progress`).
class StageProgress extends Equatable {
  const StageProgress({
    required this.topicId,
    required this.stage,
    required this.stageType,
    required this.bestScore,
    required this.totalQuestions,
    required this.stars,
    required this.attempts,
    required this.passed,
  });

  final int topicId;

  /// Số thứ tự chặng trong chủ đề (1-based).
  final int stage;

  /// learn | review | final_review.
  final String stageType;
  final int bestScore;
  final int totalQuestions;
  final int stars;
  final int attempts;
  final bool passed;

  factory StageProgress.fromMap(Map<String, dynamic> map) => StageProgress(
        topicId: map['topic_id'] as int,
        stage: map['stage'] as int,
        stageType: map['stage_type'] as String,
        bestScore: map['best_score'] as int,
        totalQuestions: map['total_questions'] as int,
        stars: map['stars'] as int,
        attempts: map['attempts'] as int,
        passed: (map['passed'] as int) != 0,
      );

  @override
  List<Object?> get props =>
      [topicId, stage, stageType, bestScore, totalQuestions, stars, attempts, passed];
}
