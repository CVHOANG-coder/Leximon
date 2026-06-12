import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/context_sentence.dart';
import '../models/vocab_topic.dart';
import '../models/vocab_word.dart';

/// Loads the sample vocabulary data (topics.json / all_vocabulary.json)
/// bundled as assets, with in-memory caching.
class VocabularyRepository {
  VocabularyRepository._();
  static final VocabularyRepository instance = VocabularyRepository._();

  static const _topicsAsset =
      'lib/data/sample/topics_with_stage_difficulty.json';
  static const _vocabularyAsset = 'lib/data/sample/all_vocabulary.json';

  List<VocabTopic>? _topics;
  Map<int, List<VocabWord>>? _wordsByTopic;
  Map<int, Map<String, List<ContextSentence>>>? _sentencesByTopic;

  Future<List<VocabTopic>> loadTopics() async {
    if (_topics != null) return _topics!;
    final raw = await rootBundle.loadString(_topicsAsset);
    _topics = [
      for (final e in _decodeTopics(raw)) VocabTopic.fromJson(e),
    ];
    return _topics!;
  }

  /// File topics có thể là mảng trần `[...]` (topics.json) hoặc đối tượng bọc
  /// `{ "version": ..., "topics": [...] }` (topics_with_stage_difficulty.json).
  static List<Map<String, dynamic>> _decodeTopics(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? decoded['topics'] as List<dynamic>
        : decoded as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<VocabTopic?> topicById(int id) async {
    final topics = await loadTopics();
    for (final t in topics) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<List<VocabWord>> wordsForTopic(int topicId) async {
    if (_wordsByTopic == null) {
      final raw = await rootBundle.loadString(_vocabularyAsset);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final topics = (map['topics'] as List<dynamic>).cast<Map<String, dynamic>>();
      _wordsByTopic = {
        for (final t in topics)
          t['topicId'] as int: [
            for (final w
                in (t['words'] as List<dynamic>).cast<Map<String, dynamic>>())
              VocabWord.fromJson(w),
          ],
      };
    }
    return _wordsByTopic![topicId] ?? const [];
  }

  /// Gom toàn bộ `contextSentences` trong các chặng của một chủ đề,
  /// nhóm theo từ đáp án (chữ thường) để tra cứu nhanh khi tạo câu hỏi.
  Future<Map<String, List<ContextSentence>>> sentencesForTopic(
    int topicId,
  ) async {
    if (_sentencesByTopic == null) {
      final raw = await rootBundle.loadString(_topicsAsset);
      _sentencesByTopic = {
        for (final t in _decodeTopics(raw)) t['id'] as int: _parseSentences(t),
      };
    }
    return _sentencesByTopic![topicId] ?? const {};
  }

  static Map<String, List<ContextSentence>> _parseSentences(
    Map<String, dynamic> topic,
  ) {
    final byAnswer = <String, List<ContextSentence>>{};
    final stages =
        (topic['stages'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    for (final stage in stages) {
      final raw = stage['contextSentences'] as List<dynamic>?;
      if (raw == null) continue;
      for (final e in raw.cast<Map<String, dynamic>>()) {
        final c = ContextSentence.fromJson(e);
        if (c.sentence.isEmpty || c.answer.isEmpty) continue;
        byAnswer.putIfAbsent(c.answer.toLowerCase(), () => []).add(c);
      }
    }
    return byAnswer;
  }
}
