import 'package:equatable/equatable.dart';

enum TopicStatus { inProgress, completed }

/// Tiến độ một chủ đề (bảng `topic_progress`).
class TopicProgress extends Equatable {
  const TopicProgress({
    required this.topicId,
    required this.status,
    required this.currentStage,
    required this.totalStages,
    required this.totalScore,
    required this.startedAt,
    this.completedAt,
  });

  final int topicId;
  final TopicStatus status;

  /// Chặng tiếp theo người dùng nên chơi (1-based).
  final int currentStage;
  final int totalStages;

  /// Tổng điểm cao nhất cộng dồn từ các chặng của chủ đề.
  final int totalScore;
  final DateTime startedAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TopicStatus.completed;

  factory TopicProgress.fromMap(Map<String, dynamic> map) => TopicProgress(
        topicId: map['topic_id'] as int,
        status: map['status'] == 'completed'
            ? TopicStatus.completed
            : TopicStatus.inProgress,
        currentStage: map['current_stage'] as int,
        totalStages: map['total_stages'] as int,
        totalScore: map['total_score'] as int,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int),
      );

  @override
  List<Object?> get props =>
      [topicId, status, currentStage, totalStages, totalScore];
}
