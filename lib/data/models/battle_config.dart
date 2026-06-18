import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Cấu hình trận đánh enemy, đọc từ `lib/data/sample/battle_config.json`.
/// Mô tả cơ chế đầy đủ: `lib/data/sample/enemy_battle_mechanism.md`.
class BattleConfig {
  const BattleConfig({
    required this.enabled,
    required this.questionDamage,
    required this.comboBonus,
    required this.wrongAnswerPenalty,
    required this.defaultDamage,
  });

  /// Có bật cơ chế battle hay không.
  final bool enabled;

  /// Damage cơ bản theo loại câu hỏi (vd `meaningChoice` → 10).
  final Map<String, int> questionDamage;

  /// Các mốc combo và hệ số nhân damage, sắp theo `comboMin` tăng dần.
  final List<ComboBonus> comboBonus;

  /// Hình phạt khi trả lời sai, theo difficulty của chặng.
  final Map<String, WrongAnswerPenalty> wrongAnswerPenalty;

  /// Damage mặc định khi loại câu hỏi không có trong [questionDamage].
  final int defaultDamage;

  static BattleConfig? _cache;

  static const _asset = 'lib/data/sample/battle_config.json';

  /// Cấu hình dự phòng khi file thiếu/đọc lỗi.
  static const fallback = BattleConfig(
    enabled: true,
    questionDamage: {
      'imageChoice': 8,
      'meaningChoice': 10,
      'listeningChoice': 12,
      'wordArrangement': 14,
      'sentenceFill': 14,
      'typingAnswer': 18,
    },
    comboBonus: [
      ComboBonus(comboMin: 3, damageMultiplier: 1.1),
      ComboBonus(comboMin: 5, damageMultiplier: 1.2),
      ComboBonus(comboMin: 10, damageMultiplier: 1.35),
    ],
    wrongAnswerPenalty: {
      'easy': WrongAnswerPenalty(heartDamage: 0, shieldGain: 0),
      'normal': WrongAnswerPenalty(heartDamage: 1, shieldGain: 0),
      'hard': WrongAnswerPenalty(heartDamage: 1, shieldGain: 5),
      'boss': WrongAnswerPenalty(heartDamage: 1, shieldGain: 10),
      'elite_boss': WrongAnswerPenalty(heartDamage: 1, shieldGain: 15),
    },
    defaultDamage: 10,
  );

  static Future<BattleConfig> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString(_asset);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = BattleConfig.fromJson(
        map['battleConfig'] as Map<String, dynamic>? ?? map,
      );
    } catch (_) {
      _cache = fallback;
    }
    return _cache!;
  }

  factory BattleConfig.fromJson(Map<String, dynamic> json) {
    final dmgRaw = json['questionDamage'] as Map<String, dynamic>? ?? const {};
    final comboRaw = json['comboBonus'] as List<dynamic>? ?? const [];
    final penaltyRaw =
        json['wrongAnswerPenalty'] as Map<String, dynamic>? ?? const {};
    return BattleConfig(
      enabled: json['enabled'] as bool? ?? true,
      questionDamage: {
        for (final e in dmgRaw.entries) e.key: (e.value as num).toInt(),
      },
      comboBonus: [
        for (final c in comboRaw.cast<Map<String, dynamic>>())
          ComboBonus(
            comboMin: (c['comboMin'] as num).toInt(),
            damageMultiplier: (c['damageMultiplier'] as num).toDouble(),
          ),
      ]..sort((a, b) => a.comboMin.compareTo(b.comboMin)),
      wrongAnswerPenalty: {
        for (final e in penaltyRaw.entries)
          e.key: WrongAnswerPenalty.fromJson(e.value as Map<String, dynamic>),
      },
      defaultDamage:
          (json['bossHpFormula']?['baseDamageTarget'] as num?)?.toInt() ?? 10,
    );
  }

  /// Damage cơ bản cho một loại câu hỏi.
  int damageFor(String questionKey) =>
      questionDamage[questionKey] ?? defaultDamage;

  /// Hệ số nhân damage ứng với chuỗi combo hiện tại (mốc cao nhất đạt được).
  double comboMultiplier(int combo) {
    var mult = 1.0;
    for (final c in comboBonus) {
      if (combo >= c.comboMin) mult = c.damageMultiplier;
    }
    return mult;
  }

  /// Hình phạt sai câu cho difficulty; rơi về `easy` nếu thiếu.
  WrongAnswerPenalty penaltyFor(String difficulty) =>
      wrongAnswerPenalty[difficulty] ??
      wrongAnswerPenalty['easy'] ??
      const WrongAnswerPenalty(heartDamage: 0, shieldGain: 0);
}

class ComboBonus {
  const ComboBonus({required this.comboMin, required this.damageMultiplier});
  final int comboMin;
  final double damageMultiplier;
}

class WrongAnswerPenalty {
  const WrongAnswerPenalty({
    required this.heartDamage,
    required this.shieldGain,
  });

  final int heartDamage;

  /// Shield enemy nhận thêm khi người chơi sai (`bossShieldGain` trong JSON).
  final int shieldGain;

  factory WrongAnswerPenalty.fromJson(Map<String, dynamic> json) =>
      WrongAnswerPenalty(
        heartDamage: (json['heartDamage'] as num?)?.toInt() ?? 0,
        shieldGain: (json['bossShieldGain'] as num?)?.toInt() ?? 0,
      );
}
