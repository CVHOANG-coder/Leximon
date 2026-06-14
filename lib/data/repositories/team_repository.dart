import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Lưu / đọc đội hình thú ra trận (tối đa 3 thú) của người chơi.
///
/// Đội hình được lưu trong bảng SQLite `team_lineup` (mỗi dòng một ô `slot`),
/// `creature_id` trỏ tới `creature_inventory` để dữ liệu luôn nhất quán với
/// kho thú đang sở hữu.
class TeamRepository {
  TeamRepository._();
  static final TeamRepository instance = TeamRepository._();

  /// Số thú tối đa trong một đội hình.
  static const maxSlots = 3;

  Future<Database> get _db => AppDatabase.instance.database;

  /// Danh sách creature_id trong đội hình, theo thứ tự ô (slot tăng dần).
  Future<List<String>> getTeam() async {
    final db = await _db;
    final rows = await db.query(
      'team_lineup',
      columns: ['creature_id'],
      orderBy: 'slot ASC',
    );
    return [for (final r in rows) r['creature_id'] as String];
  }

  /// Ghi đè toàn bộ đội hình theo thứ tự [creatureIds] (giới hạn [maxSlots]).
  ///
  /// Thực hiện trong một transaction: xóa sạch đội hình cũ rồi ghi lại các ô
  /// mới, nên không bao giờ để lại trạng thái dở dang.
  Future<void> saveTeam(List<String> creatureIds) async {
    final db = await _db;
    final ids = creatureIds.take(maxSlots).toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('team_lineup');
      for (var slot = 0; slot < ids.length; slot++) {
        await txn.insert('team_lineup', {
          'slot': slot,
          'creature_id': ids[slot],
          'updated_at': now,
        });
      }
    });
  }
}
