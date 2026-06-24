import 'dart:math';

import '../repositories/creature_repository.dart';
import '../repositories/inventory_repository.dart';

/// Quy đổi (stage_type, vị trí, độ dài topic, sao) → [RewardPayload] để
/// nạp vào kho người chơi. Bám theo `reward_mechanism_explanation.md` /
/// `lib/data/sample/reward_rule.json`.
class RewardService {
  RewardService._();
  static final RewardService instance = RewardService._();

  static final _rng = Random();

  /// Sinh phần thưởng cho một lần chơi qua chặng.
  ///
  /// - [stageType]: 'learn' | 'review' | 'final_review'
  /// - [stageIndex]: chỉ số chặng (0-based) — phân biệt early/late review
  /// - [totalStages]: tổng số chặng của topic
  /// - [correctAnswers]: số câu trả lời đúng
  /// - [totalQuestions]: tổng số câu của màn chơi
  /// Khi [islandId] có giá trị, shard chỉ rơi cho creature thuộc đảo đó.
  /// Nếu null hoặc đảo không có creature → fallback toàn bộ pool.
  Future<RewardPayload> rollStageReward({
    required String stageType,
    required int stageIndex,
    required int totalStages,
    required int correctAnswers,
    required int totalQuestions,
    String? islandId,
  }) async {
    if (totalQuestions <= 0 || correctAnswers <= 0) {
      return const RewardPayload();
    }

    final difficulty = _resolveDifficulty(stageType, stageIndex, totalStages);
    final base = _difficultyBase[difficulty]!;
    final topicMult = _topicLengthMultiplier(totalStages);
    final correctRate = (correctAnswers / totalQuestions).clamp(0.0, 1.0);
    if (correctRate < 0.6) return const RewardPayload();
    final perfMult = _performanceMultiplier(correctRate);
    final extraShardChance = _extraShardChance(correctRate);

    int scaled(int min, int max) {
      final raw = _rollRange(min, max).toDouble() * topicMult * perfMult;
      return raw.round();
    }

    final coin = scaled(base.coinMin, base.coinMax);
    final food = scaled(base.foodMin, base.foodMax);

    final evolutionStone = _rng.nextDouble() < base.stoneChance
        ? base.stoneAmount
        : 0;

    final commonEgg = _rng.nextDouble() < base.commonEggChance ? 1 : 0;
    final rareEgg = _rng.nextDouble() < base.rareEggChance ? 1 : 0;
    final chest = _rng.nextDouble() < base.chestChance ? 1 : 0;

    // Roll shard amount theo difficulty, rồi pick rarity + creature.
    final allCreatures = await CreatureRepository.instance.loadCreatures();
    final islandName = islandId == null ? null : _islandNameById[islandId];
    final scopedCreatures = islandName == null
        ? allCreatures
        : [
            for (final c in allCreatures)
              if (c.island == islandName) c,
          ];
    // Đảo không có creature (chưa có data) → rơi về toàn bộ pool.
    final creatures = scopedCreatures.isEmpty ? allCreatures : scopedCreatures;
    final creatureShards = <String, int>{};
    final shardsByRarity = <String, int>{};

    void grantShards(int amount) {
      if (amount <= 0) return;
      final rarity = _rollShardRarity();
      shardsByRarity[rarity] = (shardsByRarity[rarity] ?? 0) + amount;
      // Ưu tiên creature đúng đảo + đúng rarity; nếu không có
      // creature đúng rarity ở đảo, hạ yêu cầu (chỉ cần đúng đảo).
      final byRarity = [
        for (final c in creatures)
          if (c.rarity == rarity) c,
      ];
      final pool = byRarity.isNotEmpty ? byRarity : creatures;
      if (pool.isNotEmpty) {
        final pick = pool[_rng.nextInt(pool.length)];
        creatureShards[pick.id] = (creatureShards[pick.id] ?? 0) + amount;
      }
    }

    if (_rng.nextDouble() < base.shardChance) {
      grantShards(_rollRange(base.shardMin, base.shardMax));
    }
    if (extraShardChance > 0 && _rng.nextDouble() < extraShardChance) {
      grantShards(1);
    }

    return RewardPayload(
      coin: coin,
      food: food,
      evolutionStone: evolutionStone,
      commonEgg: commonEgg,
      rareEgg: rareEgg,
      chest: chest,
      shardsByRarity: shardsByRarity,
      creatureShards: creatureShards,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _resolveDifficulty(String stageType, int stageIdx, int totalStages) {
    switch (stageType) {
      case 'learn':
        return 'easy';
      case 'final_review':
        return totalStages >= 7 ? 'elite_boss' : 'boss';
      case 'review':
      default:
        return stageIdx < totalStages / 2 ? 'normal' : 'hard';
    }
  }

  int _rollRange(int min, int max) =>
      max <= min ? min : min + _rng.nextInt(max - min + 1);

  double _topicLengthMultiplier(int totalStages) {
    if (totalStages <= 3) return 0.85;
    if (totalStages <= 5) return 1.0;
    if (totalStages <= 7) return 1.15;
    if (totalStages <= 9) return 1.3;
    if (totalStages <= 11) return 1.45;
    return 1.6;
  }

  double _performanceMultiplier(double correctRate) => switch (correctRate) {
    >= 1.0 => 1.25,
    >= 0.8 => 1.0,
    >= 0.6 => 0.85,
    _ => 0.0,
  };

  double _extraShardChance(double correctRate) => switch (correctRate) {
    >= 1.0 => 0.12,
    >= 0.8 => 0.05,
    _ => 0.0,
  };

  /// Ánh xạ IslandData.id → tên đảo dùng trong animals.json (Creature.island).
  static const _islandNameById = <String, String>{
    'learning': 'Learning Island',
    'home': 'Home Village',
    'ocean_kingdom': 'Ocean Kingdom',
    'nature': 'Nature Island',
    'city': 'City Island',
    'adventure': 'Adventure Island',
    'entertainment': 'Entertainment Island',
    'life': 'Life Island',
    'festival': 'Festival Island',
    'master': 'Master Island',
  };

  String _rollShardRarity() {
    final r = _rng.nextDouble();
    if (r < 0.68) return 'common';
    if (r < 0.90) return 'rare';
    if (r < 0.98) return 'epic';
    return 'legendary';
  }

  /// Chọn rarity của thú khi nở trứng theo `eggHatchRate` (reward_rule.json).
  /// [eggType]: 'common' | 'rare'. Cộng dồn xác suất theo thứ tự
  /// common → rare → epic → legendary.
  String rollEggHatchRarity(String eggType) {
    final rates = _eggHatchRate[eggType] ?? _eggHatchRate['common']!;
    final r = _rng.nextDouble();
    var acc = 0.0;
    for (final entry in rates.entries) {
      acc += entry.value;
      if (r < acc) return entry.key;
    }
    return rates.keys.last;
  }

  // Tỉ lệ rarity khi nở mỗi loại trứng (reward_rule.json → eggHatchRate).
  // Map literal giữ nguyên thứ tự chèn nên cộng dồn đúng common→legendary.
  static const _eggHatchRate = <String, Map<String, double>>{
    'common': {'common': 0.72, 'rare': 0.2, 'epic': 0.07, 'legendary': 0.01},
    'rare': {'common': 0.35, 'rare': 0.4, 'epic': 0.2, 'legendary': 0.05},
  };
}

class _DifficultyBase {
  const _DifficultyBase({
    required this.coinMin,
    required this.coinMax,
    required this.foodMin,
    required this.foodMax,
    required this.stoneChance,
    required this.stoneAmount,
    required this.shardChance,
    required this.shardMin,
    required this.shardMax,
    required this.commonEggChance,
    required this.rareEggChance,
    required this.chestChance,
  });

  final int coinMin, coinMax;
  final int foodMin, foodMax;
  final double stoneChance;
  final int stoneAmount;
  final double shardChance;
  final int shardMin, shardMax;
  final double commonEggChance;
  final double rareEggChance;
  final double chestChance;
}

const _difficultyBase = <String, _DifficultyBase>{
  'easy': _DifficultyBase(
    coinMin: 8,
    coinMax: 14,
    foodMin: 10,
    foodMax: 18,
    stoneChance: 0,
    stoneAmount: 0,
    shardChance: 0.25,
    shardMin: 1,
    shardMax: 1,
    commonEggChance: 0,
    rareEggChance: 0,
    chestChance: 0,
  ),
  'normal': _DifficultyBase(
    coinMin: 12,
    coinMax: 20,
    foodMin: 16,
    foodMax: 26,
    stoneChance: 0.05,
    stoneAmount: 1,
    shardChance: 0.4,
    shardMin: 1,
    shardMax: 2,
    commonEggChance: 0,
    rareEggChance: 0,
    chestChance: 0,
  ),
  'hard': _DifficultyBase(
    coinMin: 18,
    coinMax: 30,
    foodMin: 24,
    foodMax: 38,
    stoneChance: 0.1,
    stoneAmount: 1,
    shardChance: 0.6,
    shardMin: 1,
    shardMax: 3,
    commonEggChance: 0.03,
    rareEggChance: 0,
    chestChance: 0.05,
  ),
  'boss': _DifficultyBase(
    coinMin: 35,
    coinMax: 55,
    foodMin: 45,
    foodMax: 70,
    stoneChance: 0.35,
    stoneAmount: 2,
    shardChance: 1.0,
    shardMin: 3,
    shardMax: 6,
    commonEggChance: 0.18,
    rareEggChance: 0.03,
    chestChance: 0.25,
  ),
  'elite_boss': _DifficultyBase(
    coinMin: 60,
    coinMax: 90,
    foodMin: 80,
    foodMax: 120,
    stoneChance: 0.6,
    stoneAmount: 3,
    shardChance: 1.0,
    shardMin: 5,
    shardMax: 10,
    commonEggChance: 0.35,
    rareEggChance: 0.08,
    chestChance: 0.45,
  ),
};

/// Suy ra difficulty cho `reward_log` từ context của stage. Dùng chung với
/// [InventoryRepository.grantReward].
String difficultyFor({
  required String stageType,
  required int stageIndex,
  required int totalStages,
}) => RewardService.instance._resolveDifficulty(
  stageType,
  stageIndex,
  totalStages,
);
