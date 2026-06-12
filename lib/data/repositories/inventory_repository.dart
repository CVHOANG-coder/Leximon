import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Bản ghi inventory của một creature.
class CreatureInventoryEntry {
  const CreatureInventoryEntry({
    required this.creatureId,
    required this.shards,
    required this.hatched,
    required this.stars,
    required this.stage,
    required this.obtainedAt,
    required this.updatedAt,
  });

  final String creatureId;
  final int shards;

  /// Đã ấp / triệu hồi ra creature này hay chưa.
  final bool hatched;
  final int stars;

  /// baby | teen | adult.
  final String stage;
  final int? obtainedAt;
  final int updatedAt;

  factory CreatureInventoryEntry.fromMap(Map<String, dynamic> map) =>
      CreatureInventoryEntry(
        creatureId: map['creature_id'] as String,
        shards: map['shards'] as int,
        hatched: (map['hatched'] as int) != 0,
        stars: map['stars'] as int,
        stage: map['stage'] as String,
        obtainedAt: map['obtained_at'] as int?,
        updatedAt: map['updated_at'] as int,
      );
}

/// Phần thưởng đã chia nhỏ — tiện gọi [InventoryRepository.grantReward].
class RewardPayload {
  const RewardPayload({
    this.coin = 0,
    this.food = 0,
    this.evolutionStone = 0,
    this.commonEgg = 0,
    this.rareEgg = 0,
    this.chest = 0,
    this.shardsByRarity = const {},
    this.creatureShards = const {},
  });

  final int coin;
  final int food;
  final int evolutionStone;
  final int commonEgg;
  final int rareEgg;
  final int chest;

  /// Shard tổng theo rarity ('common'/'rare'/'epic'/'legendary' → amount).
  final Map<String, int> shardsByRarity;

  /// Shard gắn theo creature_id (dùng khi đã chọn được creature cụ thể).
  final Map<String, int> creatureShards;

  bool get isEmpty =>
      coin == 0 &&
      food == 0 &&
      evolutionStone == 0 &&
      commonEgg == 0 &&
      rareEgg == 0 &&
      chest == 0 &&
      shardsByRarity.isEmpty &&
      creatureShards.isEmpty;

  int get totalShards =>
      shardsByRarity.values.fold(0, (s, v) => s + v);

  Map<String, dynamic> toJson() => {
        if (coin > 0) 'coin': coin,
        if (food > 0) 'food': food,
        if (evolutionStone > 0) 'evolutionStone': evolutionStone,
        if (commonEgg > 0) 'commonEgg': commonEgg,
        if (rareEgg > 0) 'rareEgg': rareEgg,
        if (chest > 0) 'chest': chest,
        if (shardsByRarity.isNotEmpty) 'shardsByRarity': shardsByRarity,
        if (creatureShards.isNotEmpty) 'creatureShards': creatureShards,
      };
}

/// Đọc / ghi kho vật phẩm + nhân vật người chơi sở hữu.
class InventoryRepository {
  InventoryRepository._();
  static final InventoryRepository instance = InventoryRepository._();

  Future<Database> get _db => AppDatabase.instance.database;

  // ── Shard tổng theo rarity ────────────────────────────────────────────────

  Future<Map<String, int>> getShardsByRarity() async {
    final db = await _db;
    final rows = await db.query('shard_inventory');
    return {for (final r in rows) r['rarity'] as String: r['amount'] as int};
  }

  // ── Creature inventory ────────────────────────────────────────────────────

  Future<CreatureInventoryEntry?> getCreature(String creatureId) async {
    final db = await _db;
    final rows = await db.query(
      'creature_inventory',
      where: 'creature_id = ?',
      whereArgs: [creatureId],
    );
    return rows.isEmpty ? null : CreatureInventoryEntry.fromMap(rows.first);
  }

  Future<List<CreatureInventoryEntry>> getAllCreatures() async {
    final db = await _db;
    final rows = await db.query('creature_inventory', orderBy: 'updated_at DESC');
    return [for (final r in rows) CreatureInventoryEntry.fromMap(r)];
  }

  /// Tập creature_id người chơi đang sở hữu (đã ấp / triệu hồi).
  Future<Set<String>> getOwnedCreatureIds() async {
    final db = await _db;
    final rows = await db.query(
      'creature_inventory',
      columns: ['creature_id'],
      where: 'hatched = 1',
    );
    return {for (final r in rows) r['creature_id'] as String};
  }

  Future<int> getTotalShardsCollected() async {
    final db = await _db;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT SUM(shards) FROM creature_inventory')) ??
        0;
  }

  // ── Cộng phần thưởng ──────────────────────────────────────────────────────

  /// Cộng [reward] vào kho + ghi 1 dòng `reward_log` (nếu có metadata stage).
  Future<void> grantReward(
    RewardPayload reward, {
    int? topicId,
    int? stage,
    String? difficulty,
    int stageStars = 0,
  }) async {
    if (reward.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Currencies trong user_profile.
      final updates = <String, Object>{};
      if (reward.coin != 0) updates['coins'] = _Bump(reward.coin);
      if (reward.food != 0) updates['food'] = _Bump(reward.food);
      if (reward.evolutionStone != 0) {
        updates['evolution_stone'] = _Bump(reward.evolutionStone);
      }
      if (reward.commonEgg != 0) updates['common_egg'] = _Bump(reward.commonEgg);
      if (reward.rareEgg != 0) updates['rare_egg'] = _Bump(reward.rareEgg);
      if (reward.chest != 0) updates['chest'] = _Bump(reward.chest);
      if (updates.isNotEmpty) {
        final setClauses = [
          for (final e in updates.entries) '${e.key} = ${e.key} + ${(e.value as _Bump).delta}',
          'updated_at = $now',
        ].join(', ');
        await txn.rawUpdate('UPDATE user_profile SET $setClauses WHERE id = 1');
      }

      // 2. Shard tổng theo rarity.
      for (final entry in reward.shardsByRarity.entries) {
        if (entry.value == 0) continue;
        await txn.rawUpdate(
          'UPDATE shard_inventory SET amount = amount + ? WHERE rarity = ?',
          [entry.value, entry.key],
        );
      }

      // 3. Shard gắn theo creature.
      for (final entry in reward.creatureShards.entries) {
        if (entry.value == 0) continue;
        await txn.rawInsert(
          'INSERT INTO creature_inventory '
          '(creature_id, shards, hatched, stars, stage, updated_at) '
          'VALUES (?, ?, 0, 0, ?, ?) '
          'ON CONFLICT(creature_id) DO UPDATE SET '
          'shards = shards + excluded.shards, updated_at = excluded.updated_at',
          [entry.key, entry.value, 'baby', now],
        );
      }

      // 4. Log (nếu gọi từ ngữ cảnh stage).
      if (topicId != null && stage != null && difficulty != null) {
        await txn.insert('reward_log', {
          'topic_id': topicId,
          'stage': stage,
          'difficulty': difficulty,
          'stars': stageStars,
          'payload': jsonEncode(reward.toJson()),
          'awarded_at': now,
        });
      }
    });
  }

  // ── Tiêu / nâng cấp ───────────────────────────────────────────────────────

  /// Ấp một trứng (dùng [eggType] = 'common' | 'rare') ra [creatureId].
  /// Trả về false nếu không còn trứng.
  Future<bool> hatchEgg({
    required String eggType,
    required String creatureId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final column = eggType == 'rare' ? 'rare_egg' : 'common_egg';

    return db.transaction((txn) async {
      final spent = await txn.rawUpdate(
        'UPDATE user_profile SET $column = $column - 1, updated_at = ? '
        'WHERE id = 1 AND $column > 0',
        [now],
      );
      if (spent == 0) return false;
      await txn.rawInsert(
        'INSERT INTO creature_inventory '
        '(creature_id, shards, hatched, stars, stage, obtained_at, updated_at) '
        'VALUES (?, 0, 1, 0, ?, ?, ?) '
        'ON CONFLICT(creature_id) DO UPDATE SET '
        'hatched = 1, '
        'obtained_at = COALESCE(obtained_at, excluded.obtained_at), '
        'updated_at = excluded.updated_at',
        [creatureId, 'baby', now, now],
      );
      return true;
    });
  }

  /// Tiêu coin + shard để +1 sao cho creature.
  /// Trả về false nếu thiếu tài nguyên hoặc đã đạt 5 sao.
  Future<bool> upgradeStar({
    required String creatureId,
    required int coinCost,
    required int shardCost,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'creature_inventory',
        where: 'creature_id = ?',
        whereArgs: [creatureId],
      );
      if (rows.isEmpty) return false;
      final entry = CreatureInventoryEntry.fromMap(rows.first);
      if (entry.stars >= 5 || entry.shards < shardCost) return false;

      final coinSpent = await txn.rawUpdate(
        'UPDATE user_profile SET coins = coins - ?, updated_at = ? '
        'WHERE id = 1 AND coins >= ?',
        [coinCost, now, coinCost],
      );
      if (coinSpent == 0) return false;

      await txn.rawUpdate(
        'UPDATE creature_inventory '
        'SET shards = shards - ?, stars = stars + 1, updated_at = ? '
        'WHERE creature_id = ?',
        [shardCost, now, creatureId],
      );
      return true;
    });
  }

  /// Tiêu coin + evolution stone để tiến hóa baby→teen hoặc teen→adult.
  Future<bool> evolve({
    required String creatureId,
    required int coinCost,
    required int stoneCost,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'creature_inventory',
        where: 'creature_id = ?',
        whereArgs: [creatureId],
      );
      if (rows.isEmpty) return false;
      final entry = CreatureInventoryEntry.fromMap(rows.first);
      final nextStage = switch (entry.stage) {
        'baby' => 'teen',
        'teen' => 'adult',
        _ => null,
      };
      if (nextStage == null) return false;

      final spent = await txn.rawUpdate(
        'UPDATE user_profile '
        'SET coins = coins - ?, evolution_stone = evolution_stone - ?, '
        '    updated_at = ? '
        'WHERE id = 1 AND coins >= ? AND evolution_stone >= ?',
        [coinCost, stoneCost, now, coinCost, stoneCost],
      );
      if (spent == 0) return false;

      await txn.rawUpdate(
        'UPDATE creature_inventory SET stage = ?, updated_at = ? '
        'WHERE creature_id = ?',
        [nextStage, now, creatureId],
      );
      return true;
    });
  }
}

class _Bump {
  const _Bump(this.delta);
  final int delta;
}
