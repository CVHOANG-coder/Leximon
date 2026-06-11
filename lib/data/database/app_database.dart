import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database lưu tiến độ học / chơi của người dùng trên local.
///
/// Sơ đồ (schema v1):
///
/// - `user_profile`  : 1 dòng duy nhất (id = 1) — cấp độ, kinh nghiệm, coin.
/// - `topic_progress`: mỗi chủ đề người dùng đã / đang học — trạng thái,
///                     chặng hiện tại, tổng điểm.
/// - `stage_progress`: mỗi chặng đã chơi trong một chủ đề — điểm cao nhất,
///                     số sao, số lần chơi, đã qua hay chưa.
/// - `word_progress` : mỗi từ đã học — số lần trả lời đúng / sai,
///                     thời điểm học và ôn gần nhất.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'leximon.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id         INTEGER PRIMARY KEY CHECK (id = 1),
        level      INTEGER NOT NULL DEFAULT 1,
        xp         INTEGER NOT NULL DEFAULT 0, -- XP trong cấp hiện tại
        total_xp   INTEGER NOT NULL DEFAULT 0, -- XP tích lũy toàn bộ
        coins      INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,           -- epoch millis
        updated_at INTEGER NOT NULL
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

    // Hồ sơ mặc định: cấp 1, 0 XP, 0 coin.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_profile', {
      'id': 1,
      'level': 1,
      'xp': 0,
      'total_xp': 0,
      'coins': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
