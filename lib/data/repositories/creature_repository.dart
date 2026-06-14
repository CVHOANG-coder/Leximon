import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/creature.dart';

/// Tải danh sách sinh vật (animals.json) và ánh xạ ảnh trong assets.
class CreatureRepository {
  CreatureRepository._();
  static final CreatureRepository instance = CreatureRepository._();

  static const _asset = 'lib/data/sample/animals.json';
  static const _imageDir = 'assets/images/learningIslandScreen/animals';
  static const _lottieDir = 'assets/lotties';
  static const defaultImage = 'assets/images/animal_default.png';

  /// Sinh vật đã có bộ ảnh riêng: id → tiền tố tên file.
  /// (Tên file trong assets không theo quy tắc thống nhất nên ánh xạ tay.)
  static const _imagePrefix = {
    'owlmon': 'owlmon',
    'book_fox': 'bookfox',
    'computurtle': 'computurtle',
    'number_bunny': 'NumberBunny',
  };

  /// Khóa stage trong JSON → hậu tố tên file ảnh.
  static const _stageSuffix = {
    'baby': 'baby',
    'teen': 'young',
    'adult': 'mature',
  };

  List<Creature>? _creatures;

  Future<List<Creature>> loadCreatures() async {
    if (_creatures != null) return _creatures!;
    final raw = await rootBundle.loadString(_asset);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _creatures = [
      for (final e
          in (map['creatures'] as List<dynamic>).cast<Map<String, dynamic>>())
        Creature.fromJson(e),
    ];
    return _creatures!;
  }

  /// Tra cứu nhanh theo id từ cache; null nếu chưa gọi [loadCreatures]
  /// hoặc id không tồn tại.
  Creature? cachedById(String id) {
    final list = _creatures;
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Sinh vật có bộ ảnh riêng hay chỉ dùng ảnh mặc định.
  static bool hasOwnImage(String id) => _imagePrefix.containsKey(id);

  /// Đường dẫn ảnh cho một stage ('baby' | 'teen' | 'adult');
  /// rơi về [defaultImage] khi sinh vật chưa có ảnh.
  static String imageAsset(String id, {String stage = 'baby'}) {
    final prefix = _imagePrefix[id];
    if (prefix == null) return defaultImage;
    return '$_imageDir/${prefix}_${_stageSuffix[stage] ?? 'baby'}.png';
  }

  /// Đường dẫn ảnh "mảnh ghép" của sinh vật (dùng ở màn nâng sao).
  /// Trả về null nếu sinh vật chưa có bộ ảnh riêng.
  static String? puzzleAsset(String id) {
    final prefix = _imagePrefix[id];
    if (prefix == null) return null;
    return '$_imageDir/${prefix}_puzzle.png';
  }

  /// Đường dẫn hoạt ảnh dotLottie ứng viên cho một stage (cùng quy ước tên
  /// với [imageAsset]). Trả về null nếu sinh vật chưa có bộ ảnh riêng.
  ///
  /// File có thể chưa tồn tại — bên gọi nên dùng `errorBuilder` của Lottie
  /// để rơi về ảnh tĩnh khi không nạp được.
  static String? lottieAsset(String id, {String stage = 'baby'}) {
    final prefix = _imagePrefix[id];
    if (prefix == null) return null;
    return '$_lottieDir/${prefix}_${_stageSuffix[stage] ?? 'baby'}.lottie';
  }
}
