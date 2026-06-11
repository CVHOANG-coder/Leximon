import 'package:equatable/equatable.dart';

/// Hồ sơ người chơi (bảng `user_profile`, luôn chỉ có 1 dòng).
class UserProfile extends Equatable {
  const UserProfile({
    required this.level,
    required this.xp,
    required this.totalXp,
    required this.coins,
    this.chest = 0,
    this.food = 0,
    this.evolutionStone = 0,
    this.commonEgg = 0,
    this.rareEgg = 0,
  });

  final int level;

  /// XP trong cấp hiện tại.
  final int xp;

  /// XP tích lũy toàn bộ.
  final int totalXp;
  final int coins;
  final int chest;
  final int food;
  final int evolutionStone;
  final int commonEgg;
  final int rareEgg;

  /// XP cần để lên cấp tiếp theo từ [level].
  static int xpToLevelUp(int level) => 100 + (level - 1) * 50;

  int get xpForNextLevel => xpToLevelUp(level);
  double get levelProgress =>
      (xp / xpForNextLevel).clamp(0.0, 1.0).toDouble();

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        level: map['level'] as int,
        xp: map['xp'] as int,
        totalXp: map['total_xp'] as int,
        coins: map['coins'] as int,
        chest: (map['chest'] as int?) ?? 0,
        food: (map['food'] as int?) ?? 0,
        evolutionStone: (map['evolution_stone'] as int?) ?? 0,
        commonEgg: (map['common_egg'] as int?) ?? 0,
        rareEgg: (map['rare_egg'] as int?) ?? 0,
      );

  @override
  List<Object?> get props => [
        level,
        xp,
        totalXp,
        coins,
        chest,
        food,
        evolutionStone,
        commonEgg,
        rareEgg,
      ];
}
