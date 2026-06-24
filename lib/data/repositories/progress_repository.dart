import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/stage_progress.dart';
import '../models/topic_progress.dart';
import '../models/user_profile.dart';
import '../models/word_progress.dart';
import '../models/learning_activity.dart';
import '../services/level_progression_service.dart';

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
  static const xpPerCorrectAnswer = 5;
  static const firstClearCoinBonus = 10;

  Future<Database> get _db => AppDatabase.instance.database;

  // ── Hồ sơ người chơi ──────────────────────────────────────────────────────

  Future<UserProfile> getProfile() async {
    final db = await _db;
    final rows = await db.query('user_profile', where: 'id = 1');
    return UserProfile.fromMap(rows.first);
  }

  Future<PlayerProgressOverview> getPlayerProgressOverview({
    DateTime? month,
  }) async {
    final db = await _db;
    final profile = await getProfile();
    final progression = await LevelProgressionService.instance.load();
    final selectedMonth = month ?? DateTime.now();
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final rows = await db.query(
      'daily_learning_activity',
      where: 'activity_date BETWEEN ? AND ?',
      whereArgs: [_dateKey(firstDay), _dateKey(lastDay)],
      orderBy: 'activity_date ASC',
    );
    return PlayerProgressOverview(
      profile: profile,
      xpToNextLevel: progression.xpToNextLevel(profile.level),
      activities: [for (final row in rows) DailyLearningActivity.fromMap(row)],
    );
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
    required bool passed,
    required int totalStages,
    List<String> learnedWords = const [],
  }) async {
    final db = await _db;
    final progression = await LevelProgressionService.instance.load();
    final playedAt = DateTime.now();
    final now = playedAt.millisecondsSinceEpoch;
    final activityDate = _dateKey(playedAt);

    return db.transaction((txn) async {
      // 1. Chặng: giữ số câu đúng cao nhất, đếm số lần chơi.
      final prev = await txn.query(
        'stage_progress',
        where: 'topic_id = ? AND stage = ?',
        whereArgs: [topicId, stage],
      );
      final firstClear =
          passed && (prev.isEmpty || (prev.first['passed'] as int) == 0);
      if (prev.isEmpty) {
        await txn.insert('stage_progress', {
          'topic_id': topicId,
          'stage': stage,
          'stage_type': stageType,
          'best_score': score,
          'total_questions': totalQuestions,
          // Cột legacy, không còn dùng để đánh giá màn chơi.
          'stars': 0,
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
      final passedStages =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM stage_progress '
              'WHERE topic_id = ? AND passed = 1',
              [topicId],
            ),
          ) ??
          0;
      final totalScore =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT SUM(best_score) FROM stage_progress WHERE topic_id = ?',
              [topicId],
            ),
          ) ??
          0;
      final topicCompleted = passedStages >= totalStages;
      final currentStage = topicCompleted
          ? totalStages
          : (passed ? stage + 1 : stage);

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
                topicRows.first['completed_at'] ??
                (topicCompleted ? now : null),
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
      final xpGained = passed ? score * xpPerCorrectAnswer : 0;

      final profileRows = await txn.query('user_profile', where: 'id = 1');
      final profile = UserProfile.fromMap(profileRows.first);
      var level = profile.level;
      var xp = profile.xp + xpGained;
      while (true) {
        final requiredXp = progression.xpToNextLevel(level);
        if (requiredXp == null) {
          xp = 0;
          break;
        }
        if (xp < requiredXp) break;
        xp -= requiredXp;
        level++;
      }

      final learnedWordTotal =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM word_progress'),
          ) ??
          0;
      final completedStages =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM stage_progress WHERE passed = 1',
            ),
          ) ??
          0;
      final existingActivity = await txn.query(
        'daily_learning_activity',
        where: 'activity_date = ?',
        whereArgs: [activityDate],
        limit: 1,
      );
      final isNewLearningDay = existingActivity.isEmpty;
      var currentStreak = profile.currentStreak;
      var longestStreak = profile.longestStreak;
      var learningDays = profile.learningDays;
      if (isNewLearningDay) {
        final previousDay = profile.lastLearningDate;
        currentStreak =
            previousDay != null && _dayDifference(previousDay, playedAt) == 1
            ? profile.currentStreak + 1
            : 1;
        if (currentStreak > longestStreak) longestStreak = currentStreak;
        learningDays++;
      }

      await txn.rawInsert(
        'INSERT INTO daily_learning_activity '
        '(activity_date, xp_earned, correct_answers, questions_answered, '
        'stages_played, stages_completed, updated_at) '
        'VALUES (?, ?, ?, ?, 1, ?, ?) '
        'ON CONFLICT(activity_date) DO UPDATE SET '
        'xp_earned = xp_earned + excluded.xp_earned, '
        'correct_answers = correct_answers + excluded.correct_answers, '
        'questions_answered = questions_answered + excluded.questions_answered, '
        'stages_played = stages_played + 1, '
        'stages_completed = stages_completed + excluded.stages_completed, '
        'updated_at = excluded.updated_at',
        [activityDate, xpGained, score, totalQuestions, passed ? 1 : 0, now],
      );
      await txn.update('user_profile', {
        'level': level,
        'xp': xp,
        'total_xp': profile.totalXp + xpGained,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'learning_days': learningDays,
        'completed_stages': completedStages,
        'learned_words': learnedWordTotal,
        'last_learning_date': activityDate,
        'updated_at': now,
      }, where: 'id = 1');

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
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          learningDays: learningDays,
          completedStages: completedStages,
          learnedWords: learnedWordTotal,
          lastLearningDate: DateTime.parse(activityDate),
        ),
      );
    });
  }

  static String _dateKey(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  static int _dayDifference(DateTime earlier, DateTime later) {
    final from = DateTime(earlier.year, earlier.month, earlier.day);
    final to = DateTime(later.year, later.month, later.day);
    return to.difference(from).inDays;
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
    await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT INTO word_progress '
        '(topic_id, word, correct_count, wrong_count, learned_at, last_seen_at) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(topic_id, word) DO UPDATE SET '
        '$column = $column + 1, last_seen_at = ?',
        [topicId, word, correct ? 1 : 0, correct ? 0 : 1, now, now, now],
      );
      final learnedWordTotal =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM word_progress'),
          ) ??
          0;
      await txn.update('user_profile', {
        'learned_words': learnedWordTotal,
        'updated_at': now,
      }, where: 'id = 1');
    });
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
