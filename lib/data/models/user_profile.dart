import 'package:equatable/equatable.dart';

/// Hồ sơ người chơi (bảng `user_profile`, luôn chỉ có 1 dòng).
class UserProfile extends Equatable {
  const UserProfile({
    required this.level,
    required this.xp,
    required this.totalXp,
    required this.coins,
  });

  final int level;

  /// XP trong cấp hiện tại.
  final int xp;

  /// XP tích lũy toàn bộ.
  final int totalXp;
  final int coins;

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
      );

  @override
  List<Object?> get props => [level, xp, totalXp, coins];
}
