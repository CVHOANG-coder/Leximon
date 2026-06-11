import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/creature.dart';

/// Tải danh sách sinh vật (animals.json) và ánh xạ ảnh trong assets.
class CreatureRepository {
  CreatureRepository._();
  static final CreatureRepository instance = CreatureRepository._();

  static const _asset = 'lib/data/sample/animals.json';
  static const _imageDir = 'assets/images/learningIslandScreen/animals';
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

  /// Sinh vật có bộ ảnh riêng hay chỉ dùng ảnh mặc định.
  static bool hasOwnImage(String id) => _imagePrefix.containsKey(id);

  /// Đường dẫn ảnh cho một stage ('baby' | 'teen' | 'adult');
  /// rơi về [defaultImage] khi sinh vật chưa có ảnh.
  static String imageAsset(String id, {String stage = 'baby'}) {
    final prefix = _imagePrefix[id];
    if (prefix == null) return defaultImage;
    return '$_imageDir/${prefix}_${_stageSuffix[stage] ?? 'baby'}.png';
  }
}
