import 'package:equatable/equatable.dart';

/// A vocabulary topic from lib/data/sample/topics_with_stage_difficulty.json.
class VocabTopic extends Equatable {
  const VocabTopic({
    required this.id,
    required this.name,
    required this.title,
    required this.wordCount,
    this.stages = const [],
  });

  final int id;
  final String name;
  final String title;
  final int wordCount;

  /// Kế hoạch chặng đã được biên soạn sẵn trong JSON (Học / Ôn / Ôn cuối),
  /// kèm `recommendedQuestionCount` cho từng chặng.
  final List<VocabStage> stages;

  factory VocabTopic.fromJson(Map<String, dynamic> json) => VocabTopic(
        id: json['id'] as int,
        name: json['name'] as String,
        title: json['title'] as String,
        wordCount: json['wordCount'] as int,
        stages: [
          for (final s in (json['stages'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
            VocabStage.fromJson(s),
        ],
      );

  @override
  List<Object?> get props => [id, name, title, wordCount, stages];
}

/// Một chặng trong kế hoạch học của chủ đề.
///
/// `type` là một trong `learn` / `review` / `final_review`. Với `final_review`
/// JSON không liệt kê [words] (ôn toàn bộ chủ đề) nên danh sách sẽ rỗng.
class VocabStage extends Equatable {
  const VocabStage({
    required this.stage,
    required this.type,
    required this.title,
    required this.wordCount,
    required this.words,
    required this.recommendedQuestionCount,
  });

  final int stage;
  final String type;
  final String title;
  final int wordCount;

  /// Các từ (dạng chuỗi) thuộc chặng; rỗng với `final_review`.
  final List<String> words;

  /// Số câu hỏi mục tiêu cho chặng, lấy thẳng từ JSON.
  final int recommendedQuestionCount;

  bool get isFinalReview => type == 'final_review';
  bool get isLearn => type == 'learn';

  factory VocabStage.fromJson(Map<String, dynamic> json) => VocabStage(
        stage: json['stage'] as int,
        type: json['type'] as String,
        title: json['title'] as String? ?? '',
        wordCount: json['wordCount'] as int? ?? 0,
        words: [
          for (final w in (json['words'] as List<dynamic>? ?? const []))
            w as String,
        ],
        recommendedQuestionCount: json['recommendedQuestionCount'] as int? ?? 0,
      );

  @override
  List<Object?> get props =>
      [stage, type, title, wordCount, words, recommendedQuestionCount];
}
