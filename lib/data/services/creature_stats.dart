import '../models/creature.dart';

/// Hệ số sức mạnh theo độ hiếm.
double rarityPowerMultiplier(String rarity) => switch (rarity) {
      'legendary' => 2.4,
      'epic' => 1.8,
      'rare' => 1.4,
      _ => 1.0,
    };

/// Sức mạnh (mock) của một sinh vật — sinh ổn định theo id + độ hiếm để mỗi
/// thú có số khác nhau nhưng không đổi giữa các lần mở. Dùng chung cho màn
/// chi tiết thú và màn chọn đội hình để giá trị luôn khớp nhau.
int creaturePower(Creature c) {
  final seed = c.id.codeUnits.fold<int>(0, (a, b) => a + b);
  return (300 + seed % 200) * rarityPowerMultiplier(c.rarity) ~/ 1;
}

/// Định dạng số có dấu chấm phân tách hàng nghìn (kiểu Việt): 1850 → "1.850".
String formatThousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
