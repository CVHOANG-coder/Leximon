import 'dart:convert';

import 'package:flutter/services.dart';

/// Bảng EXP cần để lên cấp, đọc từ `level_progression.json`.
class LevelProgression {
  const LevelProgression({required this.maxLevel, required this.xpByLevel});

  final int maxLevel;
  final Map<int, int?> xpByLevel;

  /// EXP cần để đi từ [level] lên cấp kế tiếp.
  /// Trả về `null` khi đã đạt cấp tối đa.
  int? xpToNextLevel(int level) {
    if (!xpByLevel.containsKey(level)) {
      throw RangeError.range(level, 1, maxLevel, 'level');
    }
    return xpByLevel[level];
  }

  factory LevelProgression.fromJson(Map<String, dynamic> json) {
    final maxLevel = json['maxLevel'] as int;
    final rawLevels = json['levels'] as List<dynamic>;
    final xpByLevel = <int, int?>{};
    int? previousRequirement;

    for (var index = 0; index < rawLevels.length; index++) {
      final entry = rawLevels[index] as Map<String, dynamic>;
      final level = entry['level'] as int;
      final requirement = entry['xpToNextLevel'] as int?;

      if (level != index + 1) {
        throw FormatException('Level progression phải liên tục từ cấp 1.');
      }
      if (level < maxLevel) {
        if (requirement == null || requirement <= 0) {
          throw FormatException('EXP cấp $level phải là số dương.');
        }
        if (previousRequirement != null && requirement <= previousRequirement) {
          throw FormatException(
            'EXP cấp $level phải lớn hơn cấp ${level - 1}.',
          );
        }
        previousRequirement = requirement;
      } else if (level == maxLevel && requirement != null) {
        throw FormatException('Cấp tối đa phải có xpToNextLevel = null.');
      }
      xpByLevel[level] = requirement;
    }

    if (rawLevels.length != maxLevel) {
      throw FormatException('Số level không khớp maxLevel.');
    }
    return LevelProgression(maxLevel: maxLevel, xpByLevel: xpByLevel);
  }
}

class LevelProgressionService {
  LevelProgressionService._();
  static final LevelProgressionService instance = LevelProgressionService._();

  Future<LevelProgression>? _cache;

  Future<LevelProgression> load() => _cache ??= _load();

  Future<LevelProgression> _load() async {
    final source = await rootBundle.loadString(
      'lib/data/sample/level_progression.json',
    );
    return LevelProgression.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}
