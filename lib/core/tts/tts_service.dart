import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

/// Phát âm từ vựng bằng Supertonic TTS (on-device, ONNX).
///
/// - Mỗi lượt phát chọn ngẫu nhiên một trong 10 giọng đọc (M1–M5, F1–F5).
/// - Lần chạy đầu package tự tải model Supertonic 3 (~400MB) từ HuggingFace
///   về cache (`supertonic_models_v3`); trong lúc tải / nếu lỗi, [speak] im
///   lặng bỏ qua nên không ảnh hưởng màn chơi.
/// - Kết quả tổng hợp được cache theo (giọng, văn bản) để đọc lại tức thì.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  static const _voices = [
    'M1', 'M2', 'M3', 'M4', 'M5',
    'F1', 'F2', 'F3', 'F4', 'F5',
  ];
  static const _cacheLimit = 80;

  final _tts = SupertonicTTS();
  final _player = AudioPlayer();
  final _rng = Random();
  final _cache = <String, TTSResult>{};
  Directory? _tempDir;
  int _fileSeq = 0;

  bool _initializing = false;
  bool _synthesizing = false;

  bool get isReady => _tts.isInitialized;

  /// Tải model và khởi tạo engine. Gọi sớm (không cần await) để nút loa
  /// sẵn sàng khi vào câu hỏi; gọi lặp lại là no-op.
  Future<void> init() async {
    if (_tts.isInitialized || _initializing) return;
    _initializing = true;
    try {
      await _tts.initialize();
    } catch (_) {
      // Chưa có mạng để tải model lần đầu → thử lại ở lần init() sau.
    } finally {
      _initializing = false;
    }
  }

  /// Đọc [text] bằng một giọng ngẫu nhiên. Bỏ qua khi engine chưa sẵn sàng
  /// hoặc đang tổng hợp câu khác.
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) return;
    if (!_tts.isInitialized) {
      init();
      return;
    }
    if (_synthesizing) return;
    _synthesizing = true;
    try {
      final voice = _voices[_rng.nextInt(_voices.length)];
      final key = '$voice|$language|$text';
      var result = _cache[key];
      if (result == null) {
        result = await _tts.synthesize(
          text,
          language: language,
          voiceStyle: voice,
        );
        if (_cache.length >= _cacheLimit) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = result;
      }
      // Tự ghi WAV ra file `.wav` rồi phát qua DeviceFileSource — tránh bug
      // của TTSAudioPlayer (ghi BytesSource thiếu extension → AVPlayer iOS
      // fail "Failed to set playerItem").
      _tempDir ??= await getTemporaryDirectory();
      final path = p.join(
          _tempDir!.path, 'tts_${(_fileSeq++) % 2}.wav');
      await File(path).writeAsBytes(result.toWavBytes(), flush: true);
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {
      // Lỗi tổng hợp / phát âm không được làm hỏng màn chơi.
    } finally {
      _synthesizing = false;
    }
  }

  Future<void> stop() => _player.stop();
}
