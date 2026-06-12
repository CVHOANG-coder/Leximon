import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart' as p;

/// Decoder cho file dotLottie (`.lottie`) sinh bởi "LottieFyr Converter".
///
/// Hai điểm cần xử lý riêng so với decoder mặc định:
/// - Bỏ qua `manifest.json` và chọn đúng file animation JSON (`a/…json`),
///   tránh assert `startFrame == endFrame`.
/// - JSON tham chiếu ảnh ở thư mục `images/` nhưng gói zip để ở `i/`, nên
///   map ảnh theo TÊN FILE để các frame webp nạp được.
Future<LottieComposition?> dotLottieDecoder(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  final imagesByName = <String, Uint8List>{};
  for (final file in archive.files) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.webp') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      imagesByName[p.basename(file.name)] = file.content;
    }
  }

  return LottieComposition.decodeZip(
    bytes,
    filePicker: (files) {
      for (final f in files) {
        if (f.name.endsWith('.json') &&
            !f.name.toLowerCase().endsWith('manifest.json')) {
          return f;
        }
      }
      return null;
    },
    imageProviderFactory: (image) {
      final data = imagesByName[image.fileName];
      return data != null ? MemoryImage(data) : null;
    },
  );
}
