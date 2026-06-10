import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vocab_topic.dart';
import '../models/vocab_word.dart';

/// Loads the sample vocabulary data (topics.json / all_vocabulary.json)
/// bundled as assets, with in-memory caching.
class VocabularyRepository {
  VocabularyRepository._();
  static final VocabularyRepository instance = VocabularyRepository._();

  static const _topicsAsset = 'lib/data/sample/topics.json';
  static const _vocabularyAsset = 'lib/data/sample/all_vocabulary.json';

  List<VocabTopic>? _topics;
  Map<int, List<VocabWord>>? _wordsByTopic;

  Future<List<VocabTopic>> loadTopics() async {
    if (_topics != null) return _topics!;
    final raw = await rootBundle.loadString(_topicsAsset);
    final list = jsonDecode(raw) as List<dynamic>;
    _topics = [
      for (final e in list.cast<Map<String, dynamic>>()) VocabTopic.fromJson(e),
    ];
    return _topics!;
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
}
