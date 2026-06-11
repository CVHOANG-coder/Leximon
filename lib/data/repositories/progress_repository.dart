import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/stage_progress.dart';
import '../models/topic_progress.dart';
import '../models/user_profile.dart';
import '../models/word_progress.dart';

/// Phần thưởng nhận được sau khi hoàn thành một chặng.
class StageReward {
  const StageReward({
    required this.xpGained,
    required this.coinsGained,
    required this.leveledUp,
    required this.profile,
    this.firstClear = false,
  });

  final int xpGained;
  final int coinsGained;
  final bool leveledUp;
  final bool firstClear;
  final UserProfile profile;
}

/// Đọc / ghi tiến độ học của người dùng vào SQLite (xem [AppDatabase]).
class ProgressRepository {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  // Quy tắc thưởng khi qua chặng.
  static const xpPerCorrectAnswer = 2;
  static const xpPerStar = 5;
  static const coinsPerStar = 5;
  static const firstClearCoinBonus = 10;

  Future<Database> get _db => AppDatabase.instance.database;

  // ── Hồ sơ người chơi ──────────────────────────────────────────────────────

  Future<UserProfile> getProfile() async {
    final db = await _db;
    final rows = await db.query('user_profile', where: 'id = 1');
    return UserProfile.fromMap(rows.first);
  }

  Future<bool> spendCoins(int amount) async {
    final db = await _db;
    final updated = await db.rawUpdate(
      'UPDATE user_profile SET coins = coins - ?, updated_at = ? '
      'WHERE id = 1 AND coins >= ?',
      [amount, DateTime.now().millisecondsSinceEpoch, amount],
    );
    return updated > 0;
  }

  // ── Tiến độ chủ đề / chặng ────────────────────────────────────────────────

  Future<TopicProgress?> getTopicProgress(int topicId) async {
    final db = await _db;
    final rows = await db.query(
      'topic_progress',
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
    return rows.isEmpty ? null : TopicProgress.fromMap(rows.first);
  }

  Future<List<TopicProgress>> getAllTopicProgress() async {
    final db = await _db;
    final rows = await db.query('topic_progress', orderBy: 'updated_at DESC');
    return [for (final r in rows) TopicProgress.fromMap(r)];
  }

  Future<List<StageProgress>> getStagesForTopic(int topicId) async {
    final db = await _db;
    final rows = await db.query(
      'stage_progress',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'stage ASC',
    );
    return [for (final r in rows) StageProgress.fromMap(r)];
  }

  /// Ghi nhận kết quả một lần chơi chặng. Gọi cả khi trượt (để đếm attempts);
  /// chỉ cộng thưởng và mở chặng kế khi [passed].
  ///
  /// [learnedWords]: các từ thuộc chặng — được đánh dấu "đã học" khi qua chặng.
  Future<StageReward> recordStagePlay({
    required int topicId,
    required int stage,
    required String stageType,
    required int score,
    required int totalQuestions,
    required int stars,
    required bool passed,
    required int totalStages,
    List<String> learnedWords = const [],
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction((txn) async {
      // 1. Chặng: giữ điểm / sao cao nhất, đếm số lần chơi.
      final prev = await txn.query(
        'stage_progress',
        where: 'topic_id = ? AND stage = ?',
        whereArgs: [topicId, stage],
      );
      final firstClear = passed &&
          (prev.isEmpty || (prev.first['passed'] as int) == 0);
      if (prev.isEmpty) {
        await txn.insert('stage_progress', {
          'topic_id': topicId,
          'stage': stage,
          'stage_type': stageType,
          'best_score': score,
          'total_questions': totalQuestions,
          'stars': stars,
          'attempts': 1,
          'passed': passed ? 1 : 0,
          'first_completed_at': passed ? now : null,
          'last_played_at': now,
        });
      } else {
        final p = prev.first;
        await txn.update(
          'stage_progress',
          {
            'best_score': score > (p['best_score'] as int)
                ? score
                : p['best_score'],
            'stars': stars > (p['stars'] as int) ? stars : p['stars'],
            'attempts': (p['attempts'] as int) + 1,
            'passed': passed || (p['passed'] as int) != 0 ? 1 : 0,
            'first_completed_at':
                p['first_completed_at'] ?? (passed ? now : null),
            'last_played_at': now,
          },
          where: 'topic_id = ? AND stage = ?',
          whereArgs: [topicId, stage],
        );
      }

      // 2. Chủ đề: cập nhật chặng hiện tại, tổng điểm, trạng thái.
      final passedStages = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM stage_progress '
            'WHERE topic_id = ? AND passed = 1',
            [topicId],
          )) ??
          0;
      final totalScore = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT SUM(best_score) FROM stage_progress WHERE topic_id = ?',
            [topicId],
          )) ??
          0;
      final topicCompleted = passedStages >= totalStages;
      final currentStage =
          topicCompleted ? totalStages : (passed ? stage + 1 : stage);

      final topicRows = await txn.query(
        'topic_progress',
        where: 'topic_id = ?',
        whereArgs: [topicId],
      );
      final topicValues = {
        'status': topicCompleted ? 'completed' : 'in_progress',
        'current_stage': currentStage,
        'total_stages': totalStages,
        'total_score': totalScore,
        'updated_at': now,
      };
      if (topicRows.isEmpty) {
        await txn.insert('topic_progress', {
          ...topicValues,
          'topic_id': topicId,
          'started_at': now,
          'completed_at': topicCompleted ? now : null,
        });
      } else {
        await txn.update(
          'topic_progress',
          {
            ...topicValues,
            'completed_at':
                topicRows.first['completed_at'] ?? (topicCompleted ? now : null),
          },
          where: 'topic_id = ?',
          whereArgs: [topicId],
        );
      }

      // 3. Từ vựng: qua chặng thì các từ trong chặng được tính là đã học.
      if (passed) {
        for (final word in learnedWords) {
          await txn.rawInsert(
            'INSERT INTO word_progress '
            '(topic_id, word, correct_count, wrong_count, learned_at, last_seen_at) '
            'VALUES (?, ?, 0, 0, ?, ?) '
            'ON CONFLICT(topic_id, word) DO UPDATE SET last_seen_at = ?',
            [topicId, word, now, now, now],
          );
        }
      }

      // 4. Thưởng XP + xử lý lên cấp. Coin/food/shard/eggs/... do
      //    [RewardService] + [InventoryRepository.grantReward] phụ trách,
      //    tránh cộng trùng tại đây.
      final xpGained =
          passed ? score * xpPerCorrectAnswer + stars * xpPerStar : 0;

      final profileRows = await txn.query('user_profile', where: 'id = 1');
      final profile = UserProfile.fromMap(profileRows.first);
      var level = profile.level;
      var xp = profile.xp + xpGained;
      while (xp >= UserProfile.xpToLevelUp(level)) {
        xp -= UserProfile.xpToLevelUp(level);
        level++;
      }
      await txn.update(
        'user_profile',
        {
          'level': level,
          'xp': xp,
          'total_xp': profile.totalXp + xpGained,
          'updated_at': now,
        },
        where: 'id = 1',
      );

      return StageReward(
        xpGained: xpGained,
        coinsGained: 0,
        leveledUp: level > profile.level,
        firstClear: firstClear,
        profile: UserProfile(
          level: level,
          xp: xp,
          totalXp: profile.totalXp + xpGained,
          coins: profile.coins,
          food: profile.food,
          evolutionStone: profile.evolutionStone,
          commonEgg: profile.commonEgg,
          rareEgg: profile.rareEgg,
          chest: profile.chest,
        ),
      );
    });
  }

  // ── Từ vựng ───────────────────────────────────────────────────────────────

  /// Ghi nhận một lượt trả lời từ [word] (đúng / sai) khi đang chơi.
  Future<void> recordAnswer({
    required int topicId,
    required String word,
    required bool correct,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final column = correct ? 'correct_count' : 'wrong_count';
    await db.rawInsert(
      'INSERT INTO word_progress '
      '(topic_id, word, correct_count, wrong_count, learned_at, last_seen_at) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(topic_id, word) DO UPDATE SET '
      '$column = $column + 1, last_seen_at = ?',
      [topicId, word, correct ? 1 : 0, correct ? 0 : 1, now, now, now],
    );
  }

  Future<List<WordProgress>> getLearnedWords(int topicId) async {
    final db = await _db;
    final rows = await db.query(
      'word_progress',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'learned_at ASC',
    );
    return [for (final r in rows) WordProgress.fromMap(r)];
  }

  /// Tổng số từ đã học (toàn bộ, hoặc trong một chủ đề).
  Future<int> learnedWordCount({int? topicId}) async {
    final db = await _db;
    final rows = topicId == null
        ? await db.rawQuery('SELECT COUNT(*) FROM word_progress')
        : await db.rawQuery(
            'SELECT COUNT(*) FROM word_progress WHERE topic_id = ?',
            [topicId],
          );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
