import 'package:equatable/equatable.dart';

/// A vocabulary topic from lib/data/sample/topics.json.
class VocabTopic extends Equatable {
  const VocabTopic({
    required this.id,
    required this.name,
    required this.title,
    required this.wordCount,
  });

  final int id;
  final String name;
  final String title;
  final int wordCount;

  factory VocabTopic.fromJson(Map<String, dynamic> json) => VocabTopic(
        id: json['id'] as int,
        name: json['name'] as String,
        title: json['title'] as String,
        wordCount: json['wordCount'] as int,
      );

  @override
  List<Object?> get props => [id, name, title, wordCount];
}
