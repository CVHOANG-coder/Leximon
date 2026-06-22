import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/creature.dart';

/// Tải danh sách sinh vật (animals.json) và ánh xạ ảnh trong assets.
class CreatureRepository {
  CreatureRepository._();
  static final CreatureRepository instance = CreatureRepository._();

  static const _asset = 'lib/data/sample/animals.json';

  /// Thư mục chứa toàn bộ ảnh thú cưng, phân theo độ hiếm:
  /// `assets/images/pets/<rarity>/<prefix>_<stage>.png`.
  static const _imageDir = 'assets/images/pets';

  /// Thư mục chứa ảnh "mảnh ghép" của thú cưng.
  static const _puzzleDir = 'assets/images/pets/puzzles';
  static const _lottieDir = 'assets/lotties';
  static const defaultImage = 'assets/images/animal_default.png';

  /// Tiền tố tên file ảnh khác với id sinh vật (mặc định trùng id).
  static const _prefixOverride = {
    'book_fox': 'bookfox',
    'number_bunny': 'NumberBunny',
  };

  /// Sinh vật có ảnh "mảnh ghép" và hoạt ảnh dotLottie riêng.
  static const _puzzleIds = {
    'owlmon',
    'book_fox',
    'computurtle',
    'number_bunny',
  };

  /// Tiền tố tên file ảnh của một sinh vật (mặc định là chính id).
  static String _prefix(String id) => _prefixOverride[id] ?? id;

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

  /// Sinh vật có bộ ảnh riêng trong assets hay chỉ dùng ảnh mặc định.
  /// Mọi sinh vật trong animals.json đều có ảnh trong `assets/images/pets`.
  static bool hasOwnImage(String id) => instance.cachedById(id) != null;

  /// Đường dẫn ảnh cho một stage ('baby' | 'teen' | 'adult');
  /// rơi về [defaultImage] khi chưa nạp được độ hiếm của sinh vật.
  static String imageAsset(String id, {String stage = 'baby'}) {
    final rarity = instance.cachedById(id)?.rarity;
    if (rarity == null) return defaultImage;
    return '$_imageDir/$rarity/${_prefix(id)}_${_stageSuffix[stage] ?? 'baby'}.png';
  }

  /// Đường dẫn ảnh "mảnh ghép" của sinh vật (dùng ở màn nâng sao).
  /// Trả về null nếu sinh vật chưa có ảnh mảnh ghép riêng.
  static String? puzzleAsset(String id) {
    if (!_puzzleIds.contains(id)) return null;
    return '$_puzzleDir/${_prefix(id)}_puzzle.png';
  }

  /// Đường dẫn hoạt ảnh dotLottie ứng viên cho một stage (cùng quy ước tên
  /// với [imageAsset]). Trả về null nếu sinh vật chưa có hoạt ảnh riêng.
  ///
  /// File có thể chưa tồn tại — bên gọi nên dùng `errorBuilder` của Lottie
  /// để rơi về ảnh tĩnh khi không nạp được.
  static String? lottieAsset(String id, {String stage = 'baby'}) {
    if (!_puzzleIds.contains(id)) return null;
    return '$_lottieDir/pet/${_prefix(id)}_${_stageSuffix[stage] ?? 'baby'}.json';
  }
}
