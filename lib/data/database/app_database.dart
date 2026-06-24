import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database lưu tiến độ học / chơi của người dùng trên local.
///
/// Sơ đồ (schema v5):
///
/// - `user_profile`     : 1 dòng (id = 1) — cấp độ, XP, coin và các loại
///                        vật phẩm (food, chest, evolution_stone, trứng).
/// - `topic_progress`   : mỗi chủ đề đã / đang học — trạng thái, chặng hiện
///                        tại, tổng điểm.
/// - `stage_progress`   : mỗi chặng đã chơi — điểm cao nhất, sao, số lần chơi.
/// - `word_progress`    : mỗi từ đã học — số lần trả lời đúng / sai.
/// - `shard_inventory`  : tổng mảnh theo độ hiếm.
/// - `creature_inventory`: THÚ CƯNG người chơi sở hữu — mỗi dòng một thú với
///                        `hatched` (đang sở hữu?), `stars` (0–5),
///                        `stage` (baby/teen/adult), `shards`.
/// - `team_lineup`      : ĐỘI HÌNH RA TRẬN — thú nào đang được mang theo, mỗi
///                        dòng một ô (`slot`), trỏ tới `creature_inventory`.
/// - `reward_log`       : nhật ký phần thưởng đã trao.
/// - `daily_learning_activity`: dữ liệu học theo ngày cho streak và heatmap.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'leximon.db';
  static const _dbVersion = 5;

  /// Thú khởi đầu người chơi sở hữu sẵn: (creature_id, sao, giai đoạn, mảnh).
  /// 4 thú này đã có sẵn bộ ảnh trong assets.
  static const _starterCreatures = <(String, int, String, int)>[
    ('book_fox', 4, 'teen', 65),
    ('owlmon', 2, 'baby', 30),
    ('computurtle', 3, 'teen', 50),
    ('number_bunny', 1, 'baby', 20),
  ];

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id              INTEGER PRIMARY KEY CHECK (id = 1),
        level           INTEGER NOT NULL DEFAULT 1,
        xp              INTEGER NOT NULL DEFAULT 0, -- XP trong cấp hiện tại
        total_xp        INTEGER NOT NULL DEFAULT 0, -- XP tích lũy toàn bộ
        coins           INTEGER NOT NULL DEFAULT 0,
        chest           INTEGER NOT NULL DEFAULT 0,
        food            INTEGER NOT NULL DEFAULT 0,
        evolution_stone INTEGER NOT NULL DEFAULT 0,
        common_egg      INTEGER NOT NULL DEFAULT 0,
        rare_egg        INTEGER NOT NULL DEFAULT 0,
        current_streak  INTEGER NOT NULL DEFAULT 0,
        longest_streak  INTEGER NOT NULL DEFAULT 0,
        learning_days   INTEGER NOT NULL DEFAULT 0,
        completed_stages INTEGER NOT NULL DEFAULT 0,
        learned_words   INTEGER NOT NULL DEFAULT 0,
        last_learning_date TEXT,
        created_at      INTEGER NOT NULL,           -- epoch millis
        updated_at      INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE topic_progress (
        topic_id      INTEGER PRIMARY KEY,     -- id trong topics.json
        status        TEXT    NOT NULL DEFAULT 'in_progress'
                      CHECK (status IN ('in_progress', 'completed')),
        current_stage INTEGER NOT NULL DEFAULT 1,
        total_stages  INTEGER NOT NULL DEFAULT 0,
        total_score   INTEGER NOT NULL DEFAULT 0,
        started_at    INTEGER NOT NULL,
        completed_at  INTEGER,
        updated_at    INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stage_progress (
        topic_id           INTEGER NOT NULL,
        stage              INTEGER NOT NULL,   -- số thứ tự chặng (1-based)
        stage_type         TEXT    NOT NULL    -- learn | review | final_review
                           CHECK (stage_type IN ('learn', 'review', 'final_review')),
        best_score         INTEGER NOT NULL DEFAULT 0,
        total_questions    INTEGER NOT NULL DEFAULT 0,
        stars              INTEGER NOT NULL DEFAULT 0 CHECK (stars BETWEEN 0 AND 3),
        attempts           INTEGER NOT NULL DEFAULT 0,
        passed             INTEGER NOT NULL DEFAULT 0, -- 0/1
        first_completed_at INTEGER,
        last_played_at     INTEGER NOT NULL,
        PRIMARY KEY (topic_id, stage)
      )
    ''');

    await db.execute('''
      CREATE TABLE word_progress (
        topic_id      INTEGER NOT NULL,
        word          TEXT    NOT NULL,        -- khớp trường "word" trong all_vocabulary.json
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count   INTEGER NOT NULL DEFAULT 0,
        learned_at    INTEGER NOT NULL,
        last_seen_at  INTEGER NOT NULL,
        PRIMARY KEY (topic_id, word)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_stage_progress_topic ON stage_progress(topic_id)',
    );
    await db.execute(
      'CREATE INDEX idx_word_progress_topic ON word_progress(topic_id)',
    );

    await _createInventoryTables(db);
    await _createTeamTable(db);
    await _createLearningActivityTable(db);
    // Người chơi mới bắt đầu KHÔNG có thú nào — chỉ được tặng trứng.

    // Hồ sơ mặc định: cấp 1, 0 XP, 0 coin; tặng 1 trứng hiếm + 2 trứng thường
    // khi mới cài app.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_profile', {
      'id': 1,
      'level': 1,
      'xp': 0,
      'total_xp': 0,
      'coins': 0,
      'common_egg': 2,
      'rare_egg': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Seed các thú khởi đầu (idempotent — INSERT OR IGNORE nên không ghi đè).
  Future<void> _seedStarterCreatures(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (id, stars, stage, shards) in _starterCreatures) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO creature_inventory '
        '(creature_id, shards, hatched, stars, stage, obtained_at, updated_at) '
        'VALUES (?, ?, 1, ?, ?, ?, ?)',
        [id, shards, stars, stage, now, now],
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // user_profile: thêm các cột currency mới.
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN chest INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN food INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN evolution_stone INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN common_egg INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN rare_egg INTEGER NOT NULL DEFAULT 0',
      );
      await _createInventoryTables(db);
    }
    if (oldVersion < 3) {
      // Seed thú khởi đầu cho người chơi đã cài bản cũ.
      await _seedStarterCreatures(db);
    }
    if (oldVersion < 4) {
      // Đội hình ra trận chuyển từ SharedPreferences sang SQLite.
      await _createTeamTable(db);
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN current_streak INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN longest_streak INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN learning_days INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN completed_stages INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN learned_words INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE user_profile ADD COLUMN last_learning_date TEXT',
      );
      await _createLearningActivityTable(db);
      await _backfillLearningActivity(db);

      final learnedWords =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM word_progress'),
          ) ??
          0;
      final completedStages =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM stage_progress WHERE passed = 1',
            ),
          ) ??
          0;
      await db.update('user_profile', {
        'learned_words': learnedWords,
        'completed_stages': completedStages,
      }, where: 'id = 1');
    }
  }

  /// Tạo các bảng inventory + seed shard_inventory với 4 rarity.
  Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE shard_inventory (
        rarity TEXT    PRIMARY KEY
               CHECK (rarity IN ('common','rare','epic','legendary')),
        amount INTEGER NOT NULL DEFAULT 0
      )
    ''');
    for (final r in const ['common', 'rare', 'epic', 'legendary']) {
      await db.insert('shard_inventory', {'rarity': r, 'amount': 0});
    }

    await db.execute('''
      CREATE TABLE creature_inventory (
        creature_id TEXT    PRIMARY KEY,
        shards      INTEGER NOT NULL DEFAULT 0,
        hatched     INTEGER NOT NULL DEFAULT 0,
        stars       INTEGER NOT NULL DEFAULT 0
                    CHECK (stars BETWEEN 0 AND 5),
        stage       TEXT    NOT NULL DEFAULT 'baby'
                    CHECK (stage IN ('baby','teen','adult')),
        obtained_at INTEGER,
        updated_at  INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_creature_hatched ON creature_inventory(hatched)',
    );

    await db.execute('''
      CREATE TABLE reward_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id   INTEGER NOT NULL,
        stage      INTEGER NOT NULL,
        difficulty TEXT    NOT NULL,
        stars      INTEGER NOT NULL,
        payload    TEXT    NOT NULL,
        awarded_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_reward_log_stage ON reward_log(topic_id, stage)',
    );
  }

  /// Bảng đội hình ra trận: mỗi dòng là một ô (`slot`, 0-based) chứa một thú.
  ///
  /// `creature_id` trỏ tới `creature_inventory`; khi một thú bị xóa khỏi kho
  /// nó cũng tự rời đội hình (ON DELETE CASCADE). Tối đa 3 ô (khớp
  /// `TeamRepository.maxSlots`).
  Future<void> _createTeamTable(Database db) async {
    await db.execute('''
      CREATE TABLE team_lineup (
        slot        INTEGER PRIMARY KEY CHECK (slot BETWEEN 0 AND 2),
        creature_id TEXT    NOT NULL UNIQUE,
        updated_at  INTEGER NOT NULL,
        FOREIGN KEY (creature_id) REFERENCES creature_inventory(creature_id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createLearningActivityTable(Database db) async {
    await db.execute('''
      CREATE TABLE daily_learning_activity (
        activity_date      TEXT PRIMARY KEY, -- yyyy-MM-dd theo giờ địa phương
        xp_earned          INTEGER NOT NULL DEFAULT 0,
        correct_answers    INTEGER NOT NULL DEFAULT 0,
        questions_answered INTEGER NOT NULL DEFAULT 0,
        stages_played      INTEGER NOT NULL DEFAULT 0,
        stages_completed   INTEGER NOT NULL DEFAULT 0,
        updated_at         INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_daily_activity_date '
      'ON daily_learning_activity(activity_date)',
    );
  }

  /// Dùng lần chơi gần nhất của mỗi màn để tạo heatmap ban đầu cho dữ liệu cũ.
  Future<void> _backfillLearningActivity(Database db) async {
    final stages = await db.query(
      'stage_progress',
      columns: ['best_score', 'total_questions', 'passed', 'last_played_at'],
    );
    for (final stage in stages) {
      final playedAt = DateTime.fromMillisecondsSinceEpoch(
        stage['last_played_at'] as int,
      );
      final date = _dateKey(playedAt);
      await db.rawInsert(
        'INSERT INTO daily_learning_activity '
        '(activity_date, correct_answers, questions_answered, stages_played, '
        'stages_completed, updated_at) VALUES (?, ?, ?, 1, ?, ?) '
        'ON CONFLICT(activity_date) DO UPDATE SET '
        'correct_answers = correct_answers + excluded.correct_answers, '
        'questions_answered = questions_answered + excluded.questions_answered, '
        'stages_played = stages_played + 1, '
        'stages_completed = stages_completed + excluded.stages_completed, '
        'updated_at = MAX(updated_at, excluded.updated_at)',
        [
          date,
          stage['best_score'] as int,
          stage['total_questions'] as int,
          stage['passed'] as int,
          stage['last_played_at'] as int,
        ],
      );
    }

    final days = await db.query(
      'daily_learning_activity',
      columns: ['activity_date'],
      orderBy: 'activity_date ASC',
    );
    var streak = 0;
    var longestStreak = 0;
    DateTime? previous;
    for (final row in days) {
      final date = DateTime.parse(row['activity_date'] as String);
      streak = previous != null && date.difference(previous).inDays == 1
          ? streak + 1
          : 1;
      if (streak > longestStreak) longestStreak = streak;
      previous = date;
    }
    await db.update('user_profile', {
      'current_streak': streak,
      'longest_streak': longestStreak,
      'learning_days': days.length,
      'last_learning_date': previous == null ? null : _dateKey(previous),
    }, where: 'id = 1');
  }

  static String _dateKey(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
