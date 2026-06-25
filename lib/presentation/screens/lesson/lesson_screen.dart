import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../core/tts/tts_service.dart';
import '../../../data/models/battle_config.dart';
import '../../../data/models/context_sentence.dart';
import '../../../data/models/creature.dart';
import '../../../data/models/enemy.dart';
import '../../../data/models/vocab_topic.dart';
import '../../../data/models/vocab_word.dart';
import '../../../data/repositories/creature_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../data/repositories/vocabulary_repository.dart';
import '../../../data/services/reward_service.dart';
import 'stage_complete_dialog.dart';

// ─── Palette (parchment / cartoon game style) ─────────────────────────────────

const _kCream = Color(0xFFFFF6DE);
const _kCreamDark = Color(0xFFEFDDB2);
const _kBorder = Color(0xFFC9A05E);
const _kInk = Color(0xFF1E3A5F);
const _kGreen = Color(0xFF3CB54A);
const _kRed = Color(0xFFE53935);
const _kBlue = Color(0xFF2196F3);
const _kGold = Color(0xFFF5B91E);

/// Thời lượng một lượt enemy phản công (lottie `mini2_attack.json`). Dùng
/// chung để canh việc chuyển câu khi trả lời sai sao cho không cắt ngang
/// hoạt ảnh tấn công.
const _kEnemyAttackMs = 1300;

// ─── Quiz / stage models ──────────────────────────────────────────────────────

/// Các dạng câu hỏi. Chặng "Học" chỉ dùng [meaning]; chặng "Ôn" xen kẽ cả 5.
enum _QKind {
  /// Chọn nghĩa tiếng Việt đúng.
  meaning,

  /// Nghe âm thanh (hiện dùng phiên âm, audio bổ sung sau) và chọn từ đúng.
  listening,

  /// Chọn từ còn thiếu trong câu có ngữ cảnh.
  fillBlank,

  /// Sắp xếp chữ cái thành từ.
  anagram,

  /// Sắp xếp từ thành câu hoàn chỉnh.
  sentenceOrder,
}

class _Question {
  _Question({
    required this.kind,
    required this.word,
    this.options = const [],
    this.correctIdx = -1,
    this.sentence,
    this.tokens = const [],
    this.answerTokens = const [],
  });

  final _QKind kind;
  final VocabWord word;

  /// Dạng chọn đáp án (meaning / listening / fillBlank).
  final List<String> options;
  final int correctIdx;

  /// Câu ngữ cảnh cho fillBlank / sentenceOrder.
  final ContextSentence? sentence;

  /// Dạng sắp xếp: các thẻ (chữ cái hoặc từ) đã xáo trộn, và thứ tự đúng.
  final List<String> tokens;
  final List<String> answerTokens;

  bool get isChoice =>
      kind == _QKind.meaning ||
      kind == _QKind.listening ||
      kind == _QKind.fillBlank;
}

enum _StageKind { learn, review, finalReview }

/// One stage on the bottom track, dựng theo kế hoạch chặng trong
/// `topics_with_stage_difficulty.json`: [words] là pool từ vựng của chặng và
/// [targetCount] là `recommendedQuestionCount` lấy thẳng từ JSON.
class _Stage {
  const _Stage({
    required this.kind,
    required this.type,
    required this.words,
    required this.targetCount,
    required this.label,
    required this.enemy,
  });

  final _StageKind kind;

  /// Type gốc trong JSON: `learn` / `review` / `final_review`.
  final String type;

  /// Pool từ vựng của chặng (đã giải về [VocabWord]).
  final List<VocabWord> words;

  /// Số câu mục tiêu = `recommendedQuestionCount` của chặng trong JSON.
  final int targetCount;

  final String label;

  /// Enemy của chặng (từ JSON). Có thể null nếu JSON chưa khai báo.
  final Enemy? enemy;

  int get wordCount => words.length;
}

/// Màn chơi học từ vựng theo chủ đề: quiz "Chọn nghĩa tiếng Việt đúng"
/// với các chặng Học/Ôn 10 từ một.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.topicId, this.islandId});
  final int topicId;

  /// Id đảo (theo IslandData) để chọn ảnh nền màn chơi; null → nền mặc định.
  final String? islandId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _rng = math.Random();
  final _stageScroll = ScrollController();

  bool _loading = true;
  String? _error;
  VocabTopic? _topic;
  List<VocabWord> _allWords = const [];

  List<_Stage> _stages = const [];
  int _stageIdx = 0;
  final Set<int> _completedStages = {};

  List<_Question> _questions = const [];
  int _qIdx = 0;
  int _score = 0;
  int? _selectedIdx;
  bool _choiceChecked = false;
  final Set<int> _hiddenOptions = {};

  // Trạng thái dạng sắp xếp (anagram / sentenceOrder):
  // chỉ số các thẻ đã đặt vào ô trống, theo thứ tự đặt.
  final List<int> _placed = [];
  bool _arrangeChecked = false;
  bool _arrangeCorrect = false;

  /// Câu ngữ cảnh của chủ đề, nhóm theo từ đáp án (chữ thường).
  Map<String, List<ContextSentence>> _sentences = const {};

  /// Đội hình thú ra trận của người chơi (đọc từ SQLite). Rỗng nếu chưa chọn.
  List<_TeamPet> _team = const [];

  /// Neo popup đội hình vào nút "Đội hình" (hiển thị như tooltip đính nút).
  final LayerLink _teamLink = LayerLink();
  OverlayEntry? _teamOverlay;

  /// Hiện/ẩn thanh các chặng ở dưới đáy màn. Mặc định ẩn cho rộng màn chơi;
  /// bật bằng nút "Hiện chặng".
  bool _showStageTrack = false;

  // ── Trạng thái battle (xem enemy_battle_mechanism.md) ──────────────────────
  BattleConfig _battle = BattleConfig.fallback;

  /// Enemy của chặng đang chơi.
  Enemy? _enemy;
  int _enemyMaxHp = 1;
  int _enemyHp = 1;
  int _enemyShield = 0;

  /// Chuỗi trả lời đúng liên tiếp (combo) → nhân damage.
  int _combo = 0;

  /// Difficulty của chặng (easy/normal/hard/boss/elite_boss) cho hình phạt sai.
  String _difficulty = 'easy';

  /// Damage của đòn vừa đánh + bộ đếm để kích lại hiệu ứng số bay lên.
  int _lastDamage = 0;
  int _hitTick = 0;

  /// Bộ đếm tăng mỗi khi trả lời sai → enemy phản công (mini2_attack.json)
  /// kèm hiệu ứng sấm chớp toàn màn hình.
  int _attackTick = 0;

  bool get _answered => _choiceChecked || _arrangeChecked;
  _Question get _question => _questions[_qIdx];

  bool get _canCheck =>
      !_answered &&
      (_question.isChoice
          ? _selectedIdx != null
          : _placed.length == _question.answerTokens.length);

  @override
  void initState() {
    super.initState();
    // Khởi tạo TTS sớm (lần đầu sẽ tải model nền) để nút loa sẵn sàng.
    TtsService.instance.init();
    _load();
    _loadTeam();
  }

  /// Nạp đội hình thú đã lưu (creature_id + giai đoạn + sao) để hiển thị ảnh
  /// thú thật bên đấu trường. Lỗi hoặc chưa có đội hình → giữ danh sách rỗng.
  Future<void> _loadTeam() async {
    try {
      final creatures = await CreatureRepository.instance.loadCreatures();
      final entries = await InventoryRepository.instance.getAllCreatures();
      final teamIds = await TeamRepository.instance.getTeam();
      if (!mounted) return;
      final byId = {for (final c in creatures) c.id: c};
      final invById = {for (final e in entries) e.creatureId: e};
      final team = <_TeamPet>[];
      for (final id in teamIds) {
        final c = byId[id];
        final inv = invById[id];
        if (c == null || inv == null || !inv.hatched) continue;
        team.add(_TeamPet(creature: c, stage: inv.stage, stars: inv.stars));
      }
      setState(() => _team = team);
    } catch (_) {
      // Bỏ qua: đấu trường vẫn chạy bình thường khi không nạp được đội hình.
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _teamOverlay?.remove();
    _teamOverlay = null;
    _stageScroll.dispose();
    super.dispose();
  }

  /// Đọc từ của câu hỏi hiện tại bằng giọng ngẫu nhiên.
  void _speakWord() => TtsService.instance.speak(_question.word.word);

  /// Câu hỏi nghe: tự phát âm khi câu hỏi hiện ra.
  void _autoPlayIfListening() {
    if (_questions.isNotEmpty && _question.kind == _QKind.listening) {
      _speakWord();
    }
  }

  Future<void> _load() async {
    try {
      final repo = VocabularyRepository.instance;
      final topic = await repo.topicById(widget.topicId);
      final words = await repo.wordsForTopic(widget.topicId);
      final sentences = await repo.sentencesForTopic(widget.topicId);
      final savedStages = await ProgressRepository.instance.getStagesForTopic(
        widget.topicId,
      );
      _battle = await BattleConfig.load();
      if (!mounted) return;
      if (topic == null || words.length < 4) {
        setState(() {
          _error = 'Chủ đề này chưa có đủ từ vựng.';
          _loading = false;
        });
        return;
      }
      final stages = _buildStages(topic, words);
      // Khôi phục các chặng đã qua từ SQLite (stage trong DB là 1-based).
      final completed = {
        for (final s in savedStages)
          if (s.passed && s.stage - 1 < stages.length) s.stage - 1,
      };
      var startIdx = 0;
      while (startIdx < stages.length - 1 && completed.contains(startIdx)) {
        startIdx++;
      }
      setState(() {
        _topic = topic;
        _allWords = words;
        _sentences = sentences;
        _stages = stages;
        _completedStages
          ..clear()
          ..addAll(completed);
        _loading = false;
      });
      _startStage(startIdx);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được dữ liệu từ vựng.';
        _loading = false;
      });
    }
  }

  /// Dựng track chặng theo kế hoạch `stages[]` trong JSON. Mỗi chặng lấy pool
  /// từ vựng và `recommendedQuestionCount` trực tiếp từ JSON; `final_review`
  /// (JSON không liệt kê từ) ôn toàn bộ chủ đề.
  List<_Stage> _buildStages(VocabTopic topic, List<VocabWord> words) {
    final byWord = {for (final w in words) w.word.toLowerCase(): w};
    final indexOf = {
      for (var i = 0; i < words.length; i++) words[i].word.toLowerCase(): i,
    };

    final stages = <_Stage>[];
    for (final s in topic.stages) {
      final List<VocabWord> pool;
      if (s.isFinalReview || s.words.isEmpty) {
        pool = List.of(words);
      } else {
        pool = [for (final raw in s.words) ?byWord[raw.toLowerCase()]];
      }
      if (pool.isEmpty) continue;

      final _StageKind kind = s.isLearn
          ? _StageKind.learn
          : (s.isFinalReview ? _StageKind.finalReview : _StageKind.review);

      stages.add(
        _Stage(
          kind: kind,
          type: s.type,
          words: pool,
          targetCount: s.recommendedQuestionCount > 0
              ? s.recommendedQuestionCount
              : pool.length,
          label: _stageLabel(kind, pool, indexOf),
          enemy: s.enemy,
        ),
      );
    }
    return stages;
  }

  /// Nhãn ngắn dưới node chặng. Giữ dạng "Học a-b" / "Ôn a-b" theo vị trí từ
  /// trong danh sách chủ đề; `final_review` hiển thị "Ôn cuối".
  String _stageLabel(
    _StageKind kind,
    List<VocabWord> pool,
    Map<String, int> indexOf,
  ) {
    if (kind == _StageKind.finalReview) return 'Ôn cuối';
    final prefix = kind == _StageKind.learn ? 'Học' : 'Ôn';
    final idxs = [for (final w in pool) ?indexOf[w.word.toLowerCase()]];
    if (idxs.isEmpty) return prefix;
    idxs.sort();
    return '$prefix ${idxs.first + 1}-${idxs.last + 1}';
  }

  List<_Question> _buildQuestions(_Stage stage, int stageIdx) {
    final pool = List.of(stage.words)..shuffle(_rng);
    final target = stage.targetCount;

    // Chặng "Học": chỉ dạng chọn nghĩa để làm quen từ mới — lặp lại pool
    // nếu thiếu, cắt nếu thừa, để khớp số câu mục tiêu.
    if (stage.kind == _StageKind.learn) {
      return [
        for (var i = 0; i < target; i++)
          _buildMeaningQuestion(pool[i % pool.length]),
      ];
    }

    // Chặng "Ôn" / "Ôn cuối": xen kẽ 5 dạng chơi theo chu kỳ.
    const cycle = [
      _QKind.listening,
      _QKind.fillBlank,
      _QKind.anagram,
      _QKind.sentenceOrder,
      _QKind.meaning,
    ];
    final usedSentences = <String>{};
    return [
      for (var i = 0; i < target; i++)
        _buildReviewQuestion(
          pool[i % pool.length],
          cycle[i % cycle.length],
          usedSentences,
        ),
    ];
  }

  /// Tạo câu hỏi dạng [desired]; nếu từ không đủ dữ liệu cho dạng đó
  /// (thiếu câu ngữ cảnh, từ quá dài/ngắn…) thì lùi dần về dạng khả dụng.
  _Question _buildReviewQuestion(
    VocabWord word,
    _QKind desired,
    Set<String> usedSentences,
  ) {
    final order = switch (desired) {
      _QKind.meaning => const [_QKind.meaning],
      _QKind.listening => const [_QKind.listening],
      _QKind.fillBlank => const [
        _QKind.fillBlank,
        _QKind.anagram,
        _QKind.listening,
      ],
      _QKind.anagram => const [_QKind.anagram, _QKind.listening],
      _QKind.sentenceOrder => const [
        _QKind.sentenceOrder,
        _QKind.fillBlank,
        _QKind.anagram,
        _QKind.listening,
      ],
    };
    for (final kind in order) {
      final q = switch (kind) {
        _QKind.meaning => _buildMeaningQuestion(word),
        _QKind.listening => _buildListeningQuestion(word),
        _QKind.fillBlank => _buildFillBlankQuestion(word, usedSentences),
        _QKind.anagram => _buildAnagramQuestion(word),
        _QKind.sentenceOrder => _buildSentenceOrderQuestion(
          word,
          usedSentences,
        ),
      };
      if (q != null) return q;
    }
    return _buildMeaningQuestion(word); // luôn khả dụng
  }

  /// Chọn nghĩa tiếng Việt đúng cho từ tiếng Anh.
  _Question _buildMeaningQuestion(VocabWord word) {
    final distractors =
        _allWords.where((w) => w.meaning != word.meaning).toList()
          ..shuffle(_rng);
    final options = [word.meaning, ...distractors.take(3).map((w) => w.meaning)]
      ..shuffle(_rng);
    return _Question(
      kind: _QKind.meaning,
      word: word,
      options: options,
      correctIdx: options.indexOf(word.meaning),
    );
  }

  /// Nghe (phiên âm) và chọn từ tiếng Anh đúng.
  _Question? _buildListeningQuestion(VocabWord word) {
    final distractors = _allWords.where((w) => w.word != word.word).toList()
      ..shuffle(_rng);
    if (distractors.length < 3) return null;
    final options = [word.word, ...distractors.take(3).map((w) => w.word)]
      ..shuffle(_rng);
    return _Question(
      kind: _QKind.listening,
      word: word,
      options: options,
      correctIdx: options.indexOf(word.word),
    );
  }

  /// Câu ngữ cảnh chưa dùng trong chặng cho từ [word], nếu có.
  ContextSentence? _sentenceFor(VocabWord word, Set<String> used) {
    final list = _sentences[word.word.toLowerCase()];
    if (list == null) return null;
    for (final c in list) {
      if (!used.contains(c.sentence)) return c;
    }
    return null;
  }

  /// Chọn từ còn thiếu trong câu có ngữ cảnh.
  _Question? _buildFillBlankQuestion(VocabWord word, Set<String> used) {
    final c = _sentenceFor(word, used);
    if (c == null) return null;
    final distractors = _allWords.where((w) => w.word != word.word).toList()
      ..shuffle(_rng);
    if (distractors.length < 3) return null;
    used.add(c.sentence);
    final options = [word.word, ...distractors.take(3).map((w) => w.word)]
      ..shuffle(_rng);
    return _Question(
      kind: _QKind.fillBlank,
      word: word,
      options: options,
      correctIdx: options.indexOf(word.word),
      sentence: c,
    );
  }

  /// Sắp xếp chữ cái thành từ (chỉ với từ đơn 3–10 chữ cái).
  _Question? _buildAnagramQuestion(VocabWord word) {
    final letters = word.word.toUpperCase();
    if (!RegExp(r'^[A-Z]{3,10}$').hasMatch(letters)) return null;
    final answer = letters.split('');
    final tokens = _shuffledTokens(answer);
    return _Question(
      kind: _QKind.anagram,
      word: word,
      tokens: tokens,
      answerTokens: answer,
    );
  }

  /// Sắp xếp từ thành câu hoàn chỉnh (câu 3–9 từ).
  _Question? _buildSentenceOrderQuestion(VocabWord word, Set<String> used) {
    final c = _sentenceFor(word, used);
    if (c == null) return null;
    final full = c.sentence.replaceFirst('___', word.word);
    final answer = [
      for (final t in full.split(RegExp(r'\s+')))
        t.replaceAll(RegExp(r'[.,!?;:]+$'), ''),
    ].where((t) => t.isNotEmpty).toList();
    if (answer.length < 3 || answer.length > 9) return null;
    used.add(c.sentence);
    return _Question(
      kind: _QKind.sentenceOrder,
      word: word,
      sentence: c,
      tokens: _shuffledTokens(answer),
      answerTokens: answer,
    );
  }

  /// Xáo trộn sao cho kết quả khác thứ tự đúng (trừ khi mọi thẻ giống nhau).
  List<String> _shuffledTokens(List<String> answer) {
    final tokens = [...answer];
    for (var attempt = 0; attempt < 5; attempt++) {
      tokens.shuffle(_rng);
      for (var i = 0; i < tokens.length; i++) {
        if (tokens[i] != answer[i]) return tokens;
      }
    }
    return tokens;
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  /// Chặng được mở khi là chặng đầu, đã hoàn thành, hoặc ngay sau một chặng
  /// đã hoàn thành.
  bool _isUnlocked(int idx) =>
      idx == 0 ||
      _completedStages.contains(idx) ||
      _completedStages.contains(idx - 1);

  void _startStage(int idx) {
    final stage = _stages[idx];
    final enemy = stage.enemy;
    setState(() {
      _stageIdx = idx;
      _questions = _buildQuestions(stage, idx);
      _qIdx = 0;
      _score = 0;
      _selectedIdx = null;
      _choiceChecked = false;
      _hiddenOptions.clear();
      _placed.clear();
      _arrangeChecked = false;
      _arrangeCorrect = false;
      // Khởi tạo trận đánh enemy của chặng.
      _enemy = enemy;
      _enemyMaxHp = (enemy?.maxHp ?? 1).clamp(1, 1 << 30);
      _enemyHp = (enemy?.hp ?? _enemyMaxHp).clamp(0, _enemyMaxHp);
      _enemyShield = enemy?.shield ?? 0;
      _combo = 0;
      _lastDamage = 0;
      _difficulty = difficultyFor(
        stageType: stage.type,
        stageIndex: idx,
        totalStages: _stages.length,
      );
    });
    _scrollToStage(idx);
    _autoPlayIfListening();
  }

  /// Trả lời đúng → cộng combo, tính damage (theo loại câu × hệ số combo),
  /// trừ shield trước rồi mới trừ HP enemy. Xem enemy_battle_mechanism.md.
  void _registerHit(_QKind kind) {
    if (_enemy == null) return;
    _combo++;
    final base = _battle.damageFor(_damageKey(kind));
    final damage = (base * _battle.comboMultiplier(_combo)).round();
    var remaining = damage;
    if (_enemyShield > 0) {
      final blocked = math.min(_enemyShield, remaining);
      _enemyShield -= blocked;
      remaining -= blocked;
    }
    _enemyHp = (_enemyHp - remaining).clamp(0, _enemyMaxHp);
    _lastDamage = damage;
    _hitTick++;
  }

  /// Trả lời sai → enemy phản công (lottie attack + sấm chớp toàn màn hình),
  /// reset combo, enemy nhận thêm shield theo difficulty.
  void _registerMiss() {
    _attackTick++;
    if (_enemy == null) return;
    _combo = 0;
    _enemyShield += _battle.penaltyFor(_difficulty).shieldGain;
  }

  /// Map loại câu hỏi sang khóa damage trong battle_config.json.
  String _damageKey(_QKind kind) => switch (kind) {
    _QKind.meaning => 'meaningChoice',
    _QKind.listening => 'listeningChoice',
    _QKind.fillBlank => 'sentenceFill',
    _QKind.anagram => 'wordArrangement',
    _QKind.sentenceOrder => 'wordArrangement',
  };

  void _scrollToStage(int idx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stageScroll.hasClients) return;
      const stageExtent = 96.0;
      final target =
          (idx * stageExtent -
                  _stageScroll.position.viewportDimension / 2 +
                  stageExtent / 2)
              .clamp(0.0, _stageScroll.position.maxScrollExtent);
      _stageScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onStageTap(int idx) async {
    if (idx == _stageIdx || !_isUnlocked(idx)) return;
    // Có tiến độ dở (đã trả ít nhất 1 câu / đang xếp từ) → hỏi xác nhận.
    final inProgress =
        _qIdx > 0 || _score > 0 || _placed.isNotEmpty || _selectedIdx != null;
    if (inProgress) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SwitchStageWarningDialog(),
      );
      if (confirm != true || !mounted) return;
    }
    _startStage(idx);
  }

  void _onSelect(int idx) {
    if (_answered || _hiddenOptions.contains(idx)) return;
    setState(() => _selectedIdx = idx);
  }

  void _checkChoice() {
    final selectedIdx = _selectedIdx;
    if (_answered || selectedIdx == null) return;
    final correct = selectedIdx == _question.correctIdx;
    setState(() {
      _choiceChecked = true;
      if (correct) {
        _score++;
        _registerHit(_question.kind);
      } else {
        _registerMiss();
      }
    });
    // Lưu thống kê đúng/sai của từ vào SQLite (không chặn UI).
    ProgressRepository.instance.recordAnswer(
      topicId: widget.topicId,
      word: _question.word.word,
      correct: correct,
    );
  }

  // ── Dạng sắp xếp: đặt / gỡ thẻ ────────────────────────────────────────────

  void _onTokenTap(int tokenIdx) {
    if (_answered || _placed.contains(tokenIdx)) return;
    setState(() => _placed.add(tokenIdx));
  }

  void _onSlotTap(int slotIdx) {
    if (_answered || slotIdx >= _placed.length) return;
    setState(() => _placed.removeAt(slotIdx));
  }

  void _checkArrange() {
    if (_answered || _placed.length != _question.answerTokens.length) return;
    final q = _question;
    var correct = true;
    for (var i = 0; i < q.answerTokens.length; i++) {
      if (q.tokens[_placed[i]] != q.answerTokens[i]) {
        correct = false;
        break;
      }
    }
    setState(() {
      _arrangeChecked = true;
      _arrangeCorrect = correct;
      if (correct) {
        _score++;
        _registerHit(q.kind);
      } else {
        _registerMiss();
      }
    });
    ProgressRepository.instance.recordAnswer(
      topicId: widget.topicId,
      word: q.word.word,
      correct: correct,
    );
  }

  void _onCheckPressed() {
    if (!_canCheck) return;
    if (_question.isChoice) {
      _checkChoice();
    } else {
      _checkArrange();
    }
  }

  void _next() {
    if (!mounted) return;
    if (_qIdx + 1 >= _questions.length) {
      _showResult();
      return;
    }
    setState(() {
      _qIdx++;
      _selectedIdx = null;
      _choiceChecked = false;
      _hiddenOptions.clear();
      _placed.clear();
      _arrangeChecked = false;
      _arrangeCorrect = false;
    });
    _autoPlayIfListening();
  }

  Future<void> _showResult() async {
    final total = _questions.length;
    final passed = _score >= (total * 0.6).ceil();
    if (passed) _completedStages.add(_stageIdx);
    final stage = _stages[_stageIdx];
    // Type lấy thẳng từ JSON: learn / review / final_review. final_review
    // kích hoạt mức thưởng boss / elite_boss theo độ dài topic
    // (xem reward_mechanism_explanation.md).
    final stageType = stage.type;
    final reward = await ProgressRepository.instance.recordStagePlay(
      topicId: widget.topicId,
      stage: _stageIdx + 1,
      stageType: stageType,
      score: _score,
      totalQuestions: total,
      passed: passed,
      totalStages: _stages.length,
      learnedWords: stage.kind == _StageKind.learn
          ? [for (final w in stage.words) w.word]
          : const [],
    );

    final payload = passed
        ? await RewardService.instance.rollStageReward(
            stageType: stageType,
            stageIndex: _stageIdx,
            totalStages: _stages.length,
            correctAnswers: _score,
            totalQuestions: total,
            islandId: widget.islandId,
          )
        : const RewardPayload();
    final difficulty = difficultyFor(
      stageType: stageType,
      stageIndex: _stageIdx,
      totalStages: _stages.length,
    );
    if (!mounted) return;

    final replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => passed
          ? StageCompleteDialog(
              score: _score,
              total: total,
              reward: payload,
              topicId: widget.topicId,
              stage: _stageIdx + 1,
              difficulty: difficulty,
            )
          : _ResultDialog(
              stageLabel: _stages[_stageIdx].label,
              score: _score,
              total: total,
              passed: passed,
              reward: reward,
            ),
    );
    if (!mounted) return;
    if (replay == true) {
      _startStage(_stageIdx);
    } else if (passed && _stageIdx + 1 < _stages.length) {
      _startStage(_stageIdx + 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showVocabList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                _topic?.title ?? 'Từ vựng',
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _allWords.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: _kCreamDark),
                itemBuilder: (_, i) {
                  final w = _allWords[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${w.word} (${w.pos})',
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      w.phonetic,
                      style: TextStyle(color: _kInk.withValues(alpha: 0.6)),
                    ),
                    trailing: Text(
                      w.meaning,
                      style: const TextStyle(
                        color: _kGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Thư mục asset chứa ảnh nền màn chơi của mỗi đảo (theo IslandData.id).
  /// Đảo nào chưa có thư mục/ảnh thì rơi về nền gradient mặc định.
  static const _islandBgDir = <String, String>{
    'learning': 'learningIslandScreen',
  };

  /// Nền gradient mặc định: trời xanh → tán lá → cỏ đậm.
  Widget _defaultBackground(Widget child) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF59A7E8), Color(0xFF7FBF6A), Color(0xFF3F7E33)],
        stops: [0.0, 0.45, 1.0],
      ),
    ),
    child: child,
  );

  /// Nền theo đảo: dùng `<đảo>/background_game_play.png` nếu có,
  /// nếu không (chưa map đảo hoặc ảnh lỗi) thì về nền gradient mặc định.
  Widget _background(Widget child) {
    final dir = _islandBgDir[widget.islandId];
    if (dir == null) return _defaultBackground(child);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/$dir/background_game_play.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _defaultBackground(const SizedBox()),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                  ? _ErrorView(message: _error!)
                  : _questions.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildPlayArea()),
                        // Ẩn/hiện thanh chặng với hiệu ứng trượt-mờ + co giãn.
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOut,
                              opacity: _showStageTrack ? 1 : 0,
                              child: _showStageTrack
                                  ? _buildStageTrack()
                                  : const SizedBox(width: double.infinity),
                            ),
                          ),
                        ),
                        _buildCheckArea(),
                      ],
                    ),
            ),
          ),
          // Sấm chớp toàn màn hình khi enemy phản công (trả lời sai).
          Positioned.fill(child: _FullScreenLightning(tick: _attackTick)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _SquareButton(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_rounded, color: _kRed, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildQuestionProgress()),
          const SizedBox(width: 10),
          _SquareButton(
            onTap: _showVocabList,
            child: SvgPicture.asset(
              'assets/svgs/library_icon.svg',
              width: 26,
              height: 26,
            ),
          ),
        ],
      ),
    );
  }

  /// Tiến độ câu hỏi của chặng hiện tại, luôn hiển thị ở header màn lesson.
  Widget _buildQuestionProgress() {
    final progress = (_qIdx + (_answered ? 1 : 0)) / _questions.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 6),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Câu ${_qIdx + 1}/${_questions.length}',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                _ProgressBar(progress: progress, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold,
              border: Border.all(color: const Color(0xFFB98300), width: 2),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayArea() {
    return Column(
      children: [
        _buildArena(),
        // Vùng câu hỏi + đáp án (cuộn được).
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              children: [
                _buildQuestionCard(),
                const SizedBox(height: 12),
                if (_question.isChoice)
                  _buildOptionGrid()
                else
                  _buildArrangeArea(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckArea() {
    final showContinue = _answered;
    final enabled = showContinue || _canCheck;
    final buttonAsset = showContinue
        ? 'assets/images/lesson/button_continue.png'
        : 'assets/images/lesson/button_test.png';
    return AspectRatio(
      aspectRatio: 1969 / 533,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/lesson/container_button.png',
            fit: BoxFit.fill,
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                reverseDuration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.center,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.84,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: AspectRatio(
                  key: ValueKey(showContinue),
                  aspectRatio: showContinue ? 2200 / 435 : 2150 / 389,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: enabled ? 1 : 0.55,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled
                          ? (showContinue ? _next : _onCheckPressed)
                          : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(buttonAsset, fit: BoxFit.fill),
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                showContinue ? 'TIẾP TỤC' : 'KIỂM TRA',
                                style: GoogleFonts.baloo2(
                                  color: Colors.white,
                                  fontSize: showContinue ? 20 : 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Đấu trường: enemy trong khung tròn + thanh HP/tên đè lên đỉnh khung,
  /// cụm đội hình bên trái.
  Widget _buildArena() {
    // Kích thước khung tròn enemy + phần header nhô lên đỉnh khung.
    const frame = 176.0;
    const headerTop = 6.0;
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Khung tròn chứa enemy (ảnh lottie phủ kín khung).
          Positioned(
            right: 6,
            top: 210 - frame - 2,
            width: frame,
            height: frame,
            child: _EnemyFrame(
              child: _EnemyVisual(
                assetKey: _enemy?.assetKey ?? '',
                hitTick: _hitTick,
                attackTick: _attackTick,
              ),
            ),
          ),
          // Hiệu ứng tấn công (chớp / nổ / tia điện) phủ trên khung enemy.
          Positioned(
            right: 6,
            top: 210 - frame - 2,
            width: frame,
            height: frame,
            child: _HitEffectOverlay(hitTick: _hitTick),
          ),
          // Số damage bay lên mỗi khi đánh trúng (giữa đỉnh khung).
          if (_lastDamage > 0)
            Positioned(
              right: 6 + frame / 2 - 16,
              top: 210 - frame + 16,
              child: _DamageFloat(key: ValueKey(_hitTick), damage: _lastDamage),
            ),
          // Thanh tên + cấp + HP (gọn), căn giữa và đè lên đỉnh khung.
          Positioned(
            right: 6 + frame / 2 - 66,
            top: headerTop,
            width: 132,
            child: _EnemyHeader(
              name: _enemy?.name ?? 'Enemy',
              level: _enemy?.level ?? 1,
              hp: _enemyHp,
              maxHp: _enemyMaxHp,
              shield: _enemyShield,
            ),
          ),
          // Badge combo (góc phải khung, như ảnh tham khảo).
          if (_combo >= 2)
            Positioned(
              right: 0,
              top: 210 - frame + 64,
              child: _ComboBadge(combo: _combo),
            ),
          // Nút "Đội hình": ấn để bật/tắt popup chi tiết đội hình (tooltip
          // đính ngay dưới nút). Không hiển thị bảng pet thường trực.
          Positioned(
            left: 8,
            top: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompositedTransformTarget(
                  link: _teamLink,
                  child: _ArenaButton(
                    icon: Icons.pets_rounded,
                    label: 'Đội hình',
                    onTap: _toggleTeamPopup,
                  ),
                ),
                const SizedBox(height: 6),
                // Ẩn/hiện thanh các chặng ở đáy màn.
                _ArenaButton(
                  icon: _showStageTrack
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  label: _showStageTrack ? 'Ẩn chặng' : 'Hiện chặng',
                  onTap: () =>
                      setState(() => _showStageTrack = !_showStageTrack),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bật/tắt popup chi tiết đội hình — hiển thị như tooltip đính ngay dưới nút
  /// "Đội hình" (dùng Overlay + LayerLink). Ấn ra ngoài hoặc ấn lại nút để đóng.
  void _toggleTeamPopup() {
    if (_teamOverlay != null) {
      _removeTeamPopup();
      return;
    }
    final overlay = Overlay.of(context);
    _teamOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Lớp chắn trong suốt phủ kín màn: chạm bất kỳ đâu (kể cả vào nút)
          // để đóng popup. Dùng opaque để không lọt xuống nút bên dưới (tránh
          // vừa đóng vừa mở lại).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeTeamPopup,
            ),
          ),
          // Popup đính bên phải nút (mũi nhọn chỉ sang trái vào nút).
          CompositedTransformFollower(
            link: _teamLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: const Offset(6, 0),
            child: _TeamTooltip(pets: _team),
          ),
        ],
      ),
    );
    overlay.insert(_teamOverlay!);
  }

  void _removeTeamPopup() {
    _teamOverlay?.remove();
    _teamOverlay = null;
  }

  Widget _buildQuestionCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: switch (_question.kind) {
            _QKind.meaning => _buildMeaningCard(),
            _QKind.listening => _buildListeningCard(),
            _QKind.fillBlank => _buildFillBlankCard(),
            _QKind.anagram => _buildAnagramCard(),
            _QKind.sentenceOrder => _buildSentenceOrderCard(),
          },
        ),
        // Ngôi sao trên đỉnh thẻ
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCream,
                border: Border.all(color: _kBorder, width: 2),
              ),
              child: const Icon(Icons.star_rounded, color: _kGold, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  // ── Nội dung thẻ câu hỏi theo từng dạng chơi ──────────────────────────────

  static Widget _cardCaption(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: _kInk,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );

  /// Nút phát âm: đọc từ của câu hỏi hiện tại bằng giọng ngẫu nhiên.
  Widget _speakerButton(double size) => GestureDetector(
    onTap: _speakWord,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kBlue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(
        Icons.volume_up_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );

  /// Chọn nghĩa tiếng Việt đúng.
  Widget _buildMeaningCard() {
    final word = _question.word;
    return Column(
      children: [
        Text(
          word.word.toLowerCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kInk,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${word.phonetic} (${word.pos})',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _speakerButton(42),
        const SizedBox(height: 8),
        _cardCaption('Chọn nghĩa tiếng Việt đúng'),
      ],
    );
  }

  /// Nghe âm thanh và chọn từ đúng — tự phát khi câu hỏi hiện,
  /// chạm loa để nghe lại; đáp án và phiên âm chỉ lộ sau khi trả lời.
  Widget _buildListeningCard() {
    final word = _question.word;
    return Column(
      children: [
        _speakerButton(60),
        const SizedBox(height: 6),
        Text(
          'Chạm loa để nghe lại',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 4),
          Text(
            word.word.toLowerCase(),
            style: const TextStyle(
              color: _kGreen,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            word.phonetic,
            style: TextStyle(
              color: _kInk.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _cardCaption('Nghe âm thanh và chọn từ đúng'),
      ],
    );
  }

  /// Chọn từ còn thiếu trong câu.
  Widget _buildFillBlankCard() {
    final sentence = _question.sentence!;
    return Column(
      children: [
        Text(
          sentence.sentence,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kInk,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 2, color: _kCreamDark),
        const SizedBox(height: 8),
        _cardCaption('Chọn từ còn thiếu trong câu'),
        if (_answered) ...[
          const SizedBox(height: 8),
          Text(
            sentence.translation,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kInk.withValues(alpha: 0.65),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// Sắp xếp chữ cái thành từ — gợi ý bằng nghĩa tiếng Việt + phiên âm.
  Widget _buildAnagramCard() {
    final word = _question.word;
    return Column(
      children: [
        _cardCaption('Sắp xếp chữ cái thành từ'),
        const SizedBox(height: 12),
        Text(
          word.meaning,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kInk,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${word.phonetic} (${word.pos})',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.55),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Sắp xếp từ thành câu — gợi ý bằng bản dịch tiếng Việt.
  Widget _buildSentenceOrderCard() {
    final sentence = _question.sentence!;
    return Column(
      children: [
        _cardCaption('Sắp xếp từ thành câu'),
        const SizedBox(height: 12),
        Text(
          '“${sentence.translation}”',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kInk,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// Vùng chơi dạng sắp xếp: hàng ô trống + hàng thẻ chữ cái / từ.
  Widget _buildArrangeArea() {
    final q = _question;
    final isAnagram = q.kind == _QKind.anagram;
    final slotBorder = !_arrangeChecked
        ? _kBorder
        : _arrangeCorrect
        ? _kGreen
        : _kRed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: slotBorder, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Vùng hiển thị các từ đã chọn:
          //  - anagram: hàng các ô trống (chạm để gỡ ký tự đã đặt)
          //  - sentenceOrder: 1 dòng text căn giữa, chạm để gỡ từ cuối
          if (isAnagram)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var i = 0; i < q.answerTokens.length; i++)
                  _TokenTile(
                    text: i < _placed.length ? q.tokens[_placed[i]] : '',
                    square: true,
                    isSlot: true,
                    borderColor: slotBorder,
                    onTap: () => _onSlotTap(i),
                  ),
              ],
            )
          else
            _SentenceLine(
              words: [for (final i in _placed) q.tokens[i]],
              borderColor: slotBorder,
              onTapRemoveLast: _placed.isEmpty
                  ? null
                  : () => _onSlotTap(_placed.length - 1),
            ),
          const SizedBox(height: 16),
          // Các thẻ để chọn.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var i = 0; i < q.tokens.length; i++)
                _TokenTile(
                  text: q.tokens[i],
                  square: isAnagram,
                  dimmed: _placed.contains(i),
                  onTap: () => _onTokenTap(i),
                ),
            ],
          ),
          if (_arrangeChecked && !_arrangeCorrect) ...[
            const SizedBox(height: 12),
            Text(
              'Đáp án: ${q.answerTokens.join(isAnagram ? '' : ' ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Lưới đáp án 2×2 cho câu hỏi dạng chọn (luôn có 4 lựa chọn).
  Widget _buildOptionGrid() {
    final n = _question.options.length;
    Widget row(int a, int b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildOption(a)),
          const SizedBox(width: 10),
          if (b < n) Expanded(child: _buildOption(b)) else const Spacer(),
        ],
      ),
    );
    return Column(
      children: [
        row(0, 1),
        if (n > 2) ...[const SizedBox(height: 10), row(2, 3)],
      ],
    );
  }

  Widget _buildOption(int idx) {
    final hidden = _hiddenOptions.contains(idx);
    final isCorrect = idx == _question.correctIdx;
    final isSelected = idx == _selectedIdx;

    Color bg = _kCream;
    Color border = _kBorder;
    Color foreground = _kInk;
    if (_answered && isCorrect) {
      bg = const Color(0xFF35A944);
      border = const Color(0xFF237D31);
      foreground = Colors.white;
    } else if (_answered && isSelected && !isCorrect) {
      bg = const Color(0xFFFBE2E0);
      border = _kRed;
    } else if (isSelected) {
      bg = const Color(0xFFE8F3FF);
      border = _kBlue;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: hidden ? 0.25 : 1,
      child: GestureDetector(
        onTap: () => _onSelect(idx),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _question.options[idx],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            // Dấu đúng/sai nổi ở góc phải, thay cho badge số 1–4.
            if (_answered && (isCorrect || (isSelected && !isCorrect)))
              Positioned(
                top: -7,
                right: -5,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCorrect ? _kGreen : _kRed,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTrack() {
    return SizedBox(
      height: 108,
      child: ListView.builder(
        controller: _stageScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _stages.length,
        itemBuilder: (_, i) => _StageNode(
          stage: _stages[i],
          isCurrent: i == _stageIdx,
          isCompleted: _completedStages.contains(i),
          isUnlocked: _isUnlocked(i),
          isFirst: i == 0,
          isLast: i == _stages.length - 1,
          onTap: () => _onStageTap(i),
        ),
      ),
    );
  }
}

// ─── Battle: enemy + đội hình (hệ thống pet sẽ nối sau) ───────────────────────

/// Nút mở popup đội hình — dấu chân thú + nhãn "Đội hình" (kiểu nút gỗ).
/// Nút vuông gọn ở góc đấu trường (icon + nhãn) — dùng cho "Đội hình" và
/// nút ẩn/hiện thanh chặng.
class _ArenaButton extends StatelessWidget {
  const _ArenaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8A5A2B), size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kInk,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một thú trong đội hình ra trận (gói dữ liệu để hiển thị ảnh thật).
class _TeamPet {
  const _TeamPet({
    required this.creature,
    required this.stage,
    required this.stars,
  });

  final Creature creature;

  /// Giai đoạn tiến hóa ('baby' | 'teen' | 'adult') → chọn đúng ảnh.
  final String stage;

  /// Số sao tiến hóa (0–5).
  final int stars;
}

/// Popup chi tiết đội hình, hiển thị như tooltip đính ngay dưới nút "Đội hình":
/// một mũi nhọn chỉ lên nút + thẻ kem liệt kê ảnh thú thật trong đội hình.
class _TeamTooltip extends StatelessWidget {
  const _TeamTooltip({required this.pets});

  final List<_TeamPet> pets;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mũi nhọn chỉ sang trái vào nút.
          const CustomPaint(size: Size(9, 18), painter: _TooltipArrowPainter()),
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: pets.isEmpty ? _buildEmpty() : _buildPets(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pets_rounded, color: _kBorder, size: 22),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Chưa chọn đội hình thú.\nVào "Đội hình thú" để chọn linh thú ra trận.',
            style: TextStyle(
              color: _kInk,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPets() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đội hình thú',
          style: TextStyle(
            color: _kInk,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < pets.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _tooltipPet(pets[i]),
        ],
      ],
    );
  }

  Widget _tooltipPet(_TeamPet pet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            CreatureRepository.imageAsset(pet.creature.id, stage: pet.stage),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              CreatureRepository.defaultImage,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                pet.creature.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _StarsRow(stars: pet.stars),
          ],
        ),
      ],
    );
  }
}

/// Mũi nhọn (tam giác hướng sang trái) của tooltip đội hình — nền kem, viền vàng.
class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, Paint()..color = _kCream);
    canvas.drawPath(
      path,
      Paint()
        ..color = _kBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TooltipArrowPainter oldDelegate) => false;
}

/// Hàng sao tiến hóa (số sao đặc / tổng 5) — dùng trong popup đội hình.
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 12,
            color: _kGold,
          ),
      ],
    );
  }
}

/// Khung tròn trang trí quanh enemy: viền vàng kim loại + viền trong sẫm +
/// vignette làm tối mép để enemy nổi bật (ảnh enemy phủ kín khung).
class _EnemyFrame extends StatelessWidget {
  const _EnemyFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Viền vàng kim loại (sáng trên → sẫm dưới) + đổ bóng tạo chiều sâu.
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9A8), Color(0xFFE3A93F), Color(0xFF9B6B22)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 9, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Container(
        // Viền trong sẫm ngăn cách viền vàng với ảnh.
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF3E2C13),
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              // Vignette: tối dần ở mép trong.
              const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x00000000), Color(0x73000000)],
                    stops: [0.62, 1.0],
                  ),
                ),
              ),
              // Đường viền vàng sáng mỏng ở mép trong cho cảm giác bevel.
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xCCFFE9A8),
                    width: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sprite enemy: nạp lottie theo [assetKey] của enemy trong JSON
/// (`assets/lotties/enemy/<assetKey>.json` cho idle và
/// `<assetKey>_attack.json` cho đòn phản công). Khi đánh trúng ([hitTick] đổi)
/// thì nhá đỏ; khi người chơi trả lời sai ([attackTick] đổi) thì phát một lượt
/// lottie attack rồi quay lại loop bình thường. [assetKey] rỗng → rơi về
/// hoạt ảnh mặc định (`mini4`).
class _EnemyVisual extends StatefulWidget {
  const _EnemyVisual({
    required this.assetKey,
    required this.hitTick,
    required this.attackTick,
  });

  /// Khóa asset của enemy, ví dụ `common/tiger`, `boss/t-rex`.
  final String assetKey;
  final int hitTick;
  final int attackTick;

  @override
  State<_EnemyVisual> createState() => _EnemyVisualState();
}

class _EnemyVisualState extends State<_EnemyVisual>
    with SingleTickerProviderStateMixin {
  // Thời lượng một lượt tấn công (ép cố định cho ngắn gọn — lottie gốc dài 6.6s
  // nên ta tua nhanh qua toàn bộ khung hình trong khoảng này).
  static const _attackDuration = Duration(milliseconds: _kEnemyAttackMs);

  /// Hoạt ảnh mặc định khi enemy chưa khai báo [assetKey].
  static const _fallbackIdle = 'assets/lotties/enemy/mini4.json';
  static const _fallbackAttack = 'assets/lotties/enemy/mini4_attack.json';

  late final AnimationController _attackCtrl;
  bool _attacking = false;

  /// Nạp sẵn composition lottie attack (file nặng ~2.8MB, 99 ảnh nhúng) để
  /// khi trả lời sai có thể phát ngay, không bị trễ giải mã làm "mất" hiệu ứng.
  LottieComposition? _attackComposition;

  String get _idlePath => widget.assetKey.isEmpty
      ? _fallbackIdle
      : 'assets/lotties/enemy/${widget.assetKey}.json';
  String get _attackPath => widget.assetKey.isEmpty
      ? _fallbackAttack
      : 'assets/lotties/enemy/${widget.assetKey}_attack.json';

  @override
  void initState() {
    super.initState();
    _attackCtrl = AnimationController(vsync: this, duration: _attackDuration);
    _attackCtrl.addStatusListener((status) {
      // Hết một lượt tấn công → trở về hoạt ảnh idle.
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _attacking = false);
      }
    });
    _preloadAttack();
  }

  /// Nạp composition lottie attack theo enemy hiện tại. Nếu asset riêng không
  /// nạp được thì rơi về hoạt ảnh mặc định để vẫn có đòn phản công.
  Future<void> _preloadAttack() async {
    final path = _attackPath;
    try {
      final c = await AssetLottie(path).load();
      if (mounted) setState(() => _attackComposition = c);
    } catch (e) {
      debugPrint('Preload attack lottie failed ($path): $e');
      if (path != _fallbackAttack) {
        try {
          final c = await AssetLottie(_fallbackAttack).load();
          if (mounted) setState(() => _attackComposition = c);
        } catch (e) {
          debugPrint('Preload fallback attack lottie failed: $e');
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant _EnemyVisual old) {
    super.didUpdateWidget(old);
    // Đổi enemy (sang chặng khác) → nạp lại lottie attack cho asset mới.
    if (widget.assetKey != old.assetKey) {
      _attackComposition = null;
      _attacking = false;
      _preloadAttack();
    }
    if (widget.attackTick != old.attackTick && widget.attackTick > 0) {
      // Chỉ phát khi composition đã sẵn sàng (đã nạp xong).
      if (_attackComposition != null) {
        setState(() => _attacking = true);
        _attackCtrl.forward(from: 0);
      } else {
        // Chưa nạp xong → nạp tiếp, lần sai sau sẽ có.
        _preloadAttack();
      }
    }
  }

  @override
  void dispose() {
    _attackCtrl.dispose();
    super.dispose();
  }

  Widget _idleLottie() => Lottie.asset(
    _idlePath,
    key: ValueKey(_idlePath),
    fit: BoxFit.fitHeight,
    alignment: Alignment.center,
    repeat: true,
    reverse: true,
    // Asset riêng lỗi → thử hoạt ảnh mặc định, rồi mới tới emoji.
    errorBuilder: (_, _, _) => _idlePath == _fallbackIdle
        ? const Center(child: Text('👾', style: TextStyle(fontSize: 72)))
        : Lottie.asset(
            _fallbackIdle,
            fit: BoxFit.fitHeight,
            alignment: Alignment.center,
            repeat: true,
            reverse: true,
            errorBuilder: (_, _, _) =>
                const Center(child: Text('👾', style: TextStyle(fontSize: 72))),
          ),
  );

  @override
  Widget build(BuildContext context) {
    // Lottie cao 4/5 chiều cao khung, canh giữa. Cho phép bề ngang tràn ra
    // ngoài khung (OverflowBox maxWidth = ∞) để lottie tự nở theo tỉ lệ và
    // được ClipOval của khung cắt ĐỀU hai bên, giữ tâm trùng tâm khung.
    return Center(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          alignment: Alignment.center,
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    // Đang phản công → chiếu thẳng lottie attack đã nạp sẵn (không bọc hiệu
    // ứng nháy đỏ) để hiển thị tức thì.
    if (_attacking && _attackComposition != null) {
      return Lottie(
        composition: _attackComposition,
        controller: _attackCtrl,
        fit: BoxFit.fitHeight,
        alignment: Alignment.center,
      );
    }

    // Idle: loop bình thường + cú nháy đỏ mỗi khi trúng đòn.
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.hitTick),
      tween: Tween(begin: widget.hitTick == 0 ? 0 : 1, end: 0),
      duration: const Duration(milliseconds: 260),
      builder: (context, t, child) {
        // t: 1 → 0, tạo cú nảy nhẹ + ánh đỏ khi trúng đòn.
        return Transform.scale(
          scale: 1 + 0.06 * t,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFFE53935).withValues(alpha: 0.55 * t),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        );
      },
      child: _idleLottie(),
    );
  }
}

/// Lớp phủ hiệu ứng tấn công lên enemy. Mỗi lần [hitTick] đổi (enemy bị trừ
/// máu) sẽ phát một hiệu ứng ngắn — luân phiên chớp sét / nổ / tia điện.
class _HitEffectOverlay extends StatefulWidget {
  const _HitEffectOverlay({required this.hitTick});
  final int hitTick;

  @override
  State<_HitEffectOverlay> createState() => _HitEffectOverlayState();
}

class _HitEffectOverlayState extends State<_HitEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    if (widget.hitTick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _HitEffectOverlay old) {
    super.didUpdateWidget(old);
    if (widget.hitTick != old.hitTick) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Chỉ vẽ khi đang chạy hiệu ứng (0 < t < 1).
          if (_c.value <= 0 || _c.value >= 1) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _HitEffectPainter(
              progress: _c.value,
              seed: widget.hitTick,
              kind: widget.hitTick % 3,
            ),
          );
        },
      ),
    );
  }
}

/// Vẽ hiệu ứng tấn công bằng CustomPainter (không cần asset). [kind]:
/// 0 = chớp sét, 1 = vụ nổ, 2 = tia điện toả tròn.
class _HitEffectPainter extends CustomPainter {
  _HitEffectPainter({
    required this.progress,
    required this.seed,
    required this.kind,
  });

  /// 0 → 1 theo vòng đời hiệu ứng.
  final double progress;
  final int seed;
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed * 9973 + kind);
    final center = Offset(size.width * 0.52, size.height * 0.5);
    final t = progress;
    final fade = (1 - t).clamp(0.0, 1.0);

    // Lóe sáng trắng ở nhịp đầu (0–30%) tạo cảm giác "trúng đòn".
    final flashT = (1 - t / 0.3).clamp(0.0, 1.0);
    if (flashT > 0) {
      final r = size.shortestSide * (0.32 + 0.22 * (1 - flashT));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.85 * flashT),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    switch (kind) {
      case 0:
        _paintLightning(canvas, size, center, rng, t, fade);
      case 1:
        _paintExplosion(canvas, size, center, rng, t, fade);
      default:
        _paintSparkBurst(canvas, size, center, rng, t, fade);
    }
  }

  /// Đường sét gãy khúc từ [a] đến [b], lệch ngẫu nhiên theo phương vuông góc.
  Path _bolt(Offset a, Offset b, math.Random rng, int segments, double jitter) {
    final path = Path()..moveTo(a.dx, a.dy);
    final dir = b - a;
    final len = dir.distance;
    final perp = len == 0 ? Offset.zero : Offset(-dir.dy / len, dir.dx / len);
    for (var i = 1; i < segments; i++) {
      final f = i / segments;
      final base = Offset.lerp(a, b, f)!;
      final off = (rng.nextDouble() - 0.5) * jitter;
      path.lineTo(base.dx + perp.dx * off, base.dy + perp.dy * off);
    }
    path.lineTo(b.dx, b.dy);
    return path;
  }

  void _paintLightning(
    Canvas canvas,
    Size size,
    Offset center,
    math.Random rng,
    double t,
    double fade,
  ) {
    // Sét chỉ loé trong ~75% đầu rồi tắt (nhấp nháy nhanh).
    if (t >= 0.75) return;
    final flicker = 0.6 + 0.4 * math.sin(t * 40);
    final glow = Paint()
      ..color = const Color(0xFF9FD8FF).withValues(alpha: 0.5 * fade * flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final bolts = 1 + rng.nextInt(2);
    for (var i = 0; i < bolts; i++) {
      final start = Offset(size.width * (0.35 + rng.nextDouble() * 0.35), -12);
      final end =
          center +
          Offset((rng.nextDouble() - 0.5) * 34, (rng.nextDouble() - 0.5) * 34);
      final path = _bolt(start, end, rng, 7, size.height * 0.28);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  void _paintExplosion(
    Canvas canvas,
    Size size,
    Offset center,
    math.Random rng,
    double t,
    double fade,
  ) {
    final maxR = size.shortestSide * 0.55;
    // Hai vòng xung kích lan ra.
    for (var k = 0; k < 2; k++) {
      final rt = (t - k * 0.12).clamp(0.0, 1.0);
      if (rt <= 0 || rt >= 1) continue;
      final r = maxR * Curves.easeOut.transform(rt);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - rt)
          ..color = (k == 0 ? const Color(0xFFFFD24A) : const Color(0xFFFF7A2A))
              .withValues(alpha: (1 - rt) * 0.85),
      );
    }
    // Lõi nổ hình sao gai, sáng trắng → cam.
    final burstR = maxR * 0.55 * Curves.easeOut.transform(t.clamp(0.0, 1.0));
    if (burstR > 1) {
      const spikes = 11;
      final path = Path();
      for (var i = 0; i <= spikes * 2; i++) {
        final ang = (i / (spikes * 2)) * 2 * math.pi;
        final rr =
            (i.isEven ? burstR : burstR * 0.55) *
            (0.85 + rng.nextDouble() * 0.3);
        final p = center + Offset(math.cos(ang), math.sin(ang)) * rr;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95 * fade),
              const Color(0xFFFFB23E).withValues(alpha: 0.8 * fade),
              const Color(0xFFFF5A1F).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: burstR)),
      );
    }
    // Mảnh vỡ văng ra.
    const n = 11;
    for (var i = 0; i < n; i++) {
      final ang = (i / n) * 2 * math.pi + rng.nextDouble();
      final dist =
          maxR *
          (0.4 + rng.nextDouble() * 0.7) *
          Curves.easeOut.transform(t.clamp(0.0, 1.0));
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      canvas.drawCircle(
        pos,
        3.5 * fade + 1,
        Paint()..color = const Color(0xFFFFC04A).withValues(alpha: fade),
      );
    }
  }

  void _paintSparkBurst(
    Canvas canvas,
    Size size,
    Offset center,
    math.Random rng,
    double t,
    double fade,
  ) {
    if (t >= 0.82) return;
    final maxLen = size.shortestSide * 0.52;
    final glow = Paint()
      ..color = const Color(0xFFB6E3FF).withValues(alpha: 0.45 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final n = 8 + rng.nextInt(4);
    for (var i = 0; i < n; i++) {
      final ang = (i / n) * 2 * math.pi + rng.nextDouble() * 0.5;
      final len =
          maxLen *
          (0.45 + rng.nextDouble() * 0.55) *
          Curves.easeOut.transform(t.clamp(0.0, 1.0));
      final end = center + Offset(math.cos(ang), math.sin(ang)) * len;
      final path = _bolt(center, end, rng, 4, len * 0.3);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(_HitEffectPainter old) =>
      old.progress != progress || old.seed != seed || old.kind != kind;
}

/// Sấm chớp phủ toàn màn hình khi enemy phản công. Mỗi lần [tick] đổi (trả
/// lời sai) sẽ loé sáng + giáng vài tia sét xuyên màn hình rồi tắt.
class _FullScreenLightning extends StatefulWidget {
  const _FullScreenLightning({required this.tick});
  final int tick;

  @override
  State<_FullScreenLightning> createState() => _FullScreenLightningState();
}

class _FullScreenLightningState extends State<_FullScreenLightning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (widget.tick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _FullScreenLightning old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.value <= 0 || _c.value >= 1) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _FullScreenLightningPainter(
              progress: _c.value,
              seed: widget.tick,
            ),
          );
        },
      ),
    );
  }
}

/// Vẽ sấm chớp toàn màn hình: hai nhịp loé trắng + tia sét gãy khúc từ đỉnh
/// màn hình giáng xuống, pha chút ánh cam (flame).
class _FullScreenLightningPainter extends CustomPainter {
  _FullScreenLightningPainter({required this.progress, required this.seed});

  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final rng = math.Random(seed * 7919 + 17);
    final rect = Offset.zero & size;

    // Hai nhịp loé: trắng gắt lúc đầu, nhấp nháy nhẹ giữa hiệu ứng.
    final flash1 = (1 - t / 0.16).clamp(0.0, 1.0);
    final flash2 = (t > 0.30 && t < 0.52)
        ? (1 - (t - 0.30) / 0.22).clamp(0.0, 1.0)
        : 0.0;
    final flash = math.max(flash1, flash2 * 0.65);
    if (flash > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * flash),
      );
      // Ánh cam ấm (flame) ở mép trên.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0x66FF7A2A), Color(0x00FF7A2A)],
          ).createShader(rect)
          ..color = const Color(0xFFFF7A2A).withValues(alpha: flash),
      );
    }

    // Tia sét giáng xuống trong ~62% đầu.
    if (t >= 0.62) return;
    final fade = (1 - t / 0.62).clamp(0.0, 1.0);
    final flicker = 0.55 + 0.45 * math.sin(t * 46);
    final glow = Paint()
      ..color = const Color(0xFFB6E3FF).withValues(alpha: 0.5 * fade * flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final bolts = 3 + rng.nextInt(3);
    for (var i = 0; i < bolts; i++) {
      final startX = size.width * rng.nextDouble();
      final start = Offset(startX, -12);
      final end = Offset(
        startX + (rng.nextDouble() - 0.5) * size.width * 0.4,
        size.height * (0.5 + rng.nextDouble() * 0.5),
      );
      final path = _bolt(start, end, rng, 9, size.width * 0.12);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  /// Đường sét gãy khúc từ [a] đến [b], lệch ngẫu nhiên theo phương vuông góc.
  Path _bolt(Offset a, Offset b, math.Random rng, int segments, double jitter) {
    final path = Path()..moveTo(a.dx, a.dy);
    final dir = b - a;
    final len = dir.distance;
    final perp = len == 0 ? Offset.zero : Offset(-dir.dy / len, dir.dx / len);
    for (var i = 1; i < segments; i++) {
      final f = i / segments;
      final base = Offset.lerp(a, b, f)!;
      final off = (rng.nextDouble() - 0.5) * jitter;
      path.lineTo(base.dx + perp.dx * off, base.dy + perp.dy * off);
    }
    path.lineTo(b.dx, b.dy);
    return path;
  }

  @override
  bool shouldRepaint(_FullScreenLightningPainter old) =>
      old.progress != progress || old.seed != seed;
}

/// Thanh thông tin enemy: huy hiệu sọ + tên + cấp + thanh HP (và giáp nếu có).
class _EnemyHeader extends StatelessWidget {
  const _EnemyHeader({
    required this.name,
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.shield,
  });

  final String name;
  final int level;
  final int hp;
  final int maxHp;
  final int shield;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dòng tên + cấp: nền sẫm, viền vàng đồng bộ với khung enemy.
        Container(
          padding: const EdgeInsets.fromLTRB(2, 1, 6, 1),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF21E2B3D), Color(0xF2121B28)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3A93F), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Huy hiệu sọ viền vàng.
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A1830),
                  border: Border.all(
                    color: const Color(0xFFE3A93F),
                    width: 1.2,
                  ),
                ),
                child: const Text('☠️', style: TextStyle(fontSize: 9)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Lv. $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Thanh HP đỏ nhô lên phía dưới name plate một chút (đè lên đỉnh khung).
        Transform.translate(
          offset: const Offset(0, -2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                if (shield > 0) ...[
                  _ShieldChip(shield: shield),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: _HpBar(hp: hp, maxHp: maxHp),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Thanh máu enemy (đỏ) với số hp/maxHp ở giữa.
class _HpBar extends StatelessWidget {
  const _HpBar({required this.hp, required this.maxHp});
  final int hp;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp == 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    return Container(
      height: 13,
      decoration: BoxDecoration(
        color: const Color(0xFF4A1212),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF2A0A0A), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              heightFactor: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF6B5E), Color(0xFFE53935)],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '$hp/$maxHp',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu giáp enemy.
class _ShieldChip extends StatelessWidget {
  const _ShieldChip({required this.shield});
  final int shield;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF5B7FB0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(
            '$shield',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Số damage bay lên rồi mờ dần khi đánh trúng enemy.
class _DamageFloat extends StatelessWidget {
  const _DamageFloat({super.key, required this.damage});
  final int damage;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, child) {
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, -34 * t), child: child),
        );
      },
      child: Text(
        '-$damage',
        style: const TextStyle(
          color: Color(0xFFFFE36E),
          fontSize: 26,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// Badge hiển thị chuỗi combo hiện tại.
class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kGold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        'Combo x$combo',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─── Stage node on the bottom track ───────────────────────────────────────────

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.stage,
    required this.isCurrent,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final _Stage stage;
  final bool isCurrent;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  // Tâm dọc của ô icon (đường nối đi qua đây) và bề rộng mỗi node.
  static const _centerY = 36.0;
  static const _nodeWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final boxSize = isCurrent ? 68.0 : 58.0;
    // Học → icon sách, Ôn → icon mũi tên luyện tập;
    // bản "done" chỉ khi chặng đã hoàn thành, còn lại (đang chơi / khóa)
    // dùng bản "undone".
    final iconAsset = stage.kind == _StageKind.learn
        ? (isCompleted
              ? 'assets/svgs/book_done.svg'
              : 'assets/svgs/book_undone.svg')
        : (isCompleted
              ? 'assets/svgs/practive_done.svg'
              : 'assets/svgs/practive_undone.svg');

    final iconBox = Container(
      width: boxSize,
      height: boxSize,
      padding: EdgeInsets.all(isCurrent ? 14 : 12),
      decoration: BoxDecoration(
        color: isCurrent ? _kBlue : _kCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? _kGold : _kBorder,
          width: isCurrent ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SvgPicture.asset(iconAsset),
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _nodeWidth,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Đường nối hai bên, đi qua tâm ô icon (tâm tại y = _centerY)
            Positioned(
              top: _centerY - 2,
              left: 0,
              right: _nodeWidth / 2,
              child: isFirst
                  ? const SizedBox(height: 4)
                  : Container(height: 4, color: _kCreamDark),
            ),
            Positioned(
              top: _centerY - 2,
              left: _nodeWidth / 2,
              right: 0,
              child: isLast
                  ? const SizedBox(height: 4)
                  : Container(height: 4, color: _kCreamDark),
            ),
            Positioned(
              top: _centerY - boxSize / 2,
              child: Opacity(opacity: isUnlocked ? 1 : 0.55, child: iconBox),
            ),
            // Mũi nhọn dưới ô đang chơi
            if (isCurrent)
              Positioned(
                top: _centerY + boxSize / 2 - 7,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: _kCream,
                      border: Border.all(color: _kGold, width: 2),
                    ),
                  ),
                ),
              ),
            // Dấu tick chặng đã xong
            if (isCompleted)
              Positioned(
                top: _centerY + boxSize / 2 - 13,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
              ),
            Positioned(
              top: _centerY + 40,
              child: Text(
                stage.label,
                style:
                    TextStyle(
                      color: _kInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color: Colors.white70,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ).copyWith(
                      color: isUnlocked ? _kInk : _kInk.withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small shared widgets ─────────────────────────────────────────────────────

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Thẻ chữ cái / từ trong dạng sắp xếp. Khi [isSlot] là ô trống đích;
/// khi [dimmed] là thẻ đã được đặt (mờ đi, không bấm được nữa).
class _TokenTile extends StatelessWidget {
  const _TokenTile({
    required this.text,
    required this.onTap,
    this.square = false,
    this.isSlot = false,
    this.dimmed = false,
    this.borderColor = _kBorder,
  });

  final String text;
  final VoidCallback onTap;

  /// Ô vuông cố định cho chữ cái; co giãn theo nội dung cho từ.
  final bool square;
  final bool isSlot;
  final bool dimmed;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final empty = isSlot && text.isEmpty;
    return GestureDetector(
      onTap: dimmed ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.3 : 1,
        child: Container(
          width: square ? 42 : null,
          height: 42,
          padding: square ? null : const EdgeInsets.symmetric(horizontal: 12),
          // Chỉ căn giữa khi ô vuông cố định; nếu null + alignment thì
          // Container sẽ "nở" để chiếm hết width của Wrap → mất layout.
          alignment: square ? Alignment.center : null,
          decoration: BoxDecoration(
            color: empty ? _kCreamDark.withValues(alpha: 0.5) : _kCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: empty ? _kCreamDark : borderColor,
              width: 2,
            ),
            boxShadow: empty
                ? null
                : const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: _kInk,
              fontSize: square ? 20 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup cảnh báo khi người chơi chuyển chặng giữa lúc đang chơi dở.
class _SwitchStageWarningDialog extends StatelessWidget {
  const _SwitchStageWarningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _kBorder, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE8A93B),
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Chuyển chặng?',
              style: TextStyle(
                color: _kInk,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn đang chơi dở chặng này.\nTiến độ hiện tại sẽ bị mất.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kInk,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Tiếp tục chơi',
                    color: _kBlue,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: 'Chuyển',
                    color: _kRed,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Khu hiển thị câu đã ghép trong dạng "sắp xếp từ thành câu": một dòng
/// text căn giữa, chạm để gỡ từ cuối cùng.
class _SentenceLine extends StatelessWidget {
  const _SentenceLine({
    required this.words,
    required this.borderColor,
    required this.onTapRemoveLast,
  });

  final List<String> words;
  final Color borderColor;
  final VoidCallback? onTapRemoveLast;

  @override
  Widget build(BuildContext context) {
    final empty = words.isEmpty;
    return GestureDetector(
      onTap: onTapRemoveLast,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: empty ? _kCreamDark.withValues(alpha: 0.4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Text(
          empty ? 'Chạm các từ bên dưới để xếp câu' : words.join(' '),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: empty ? _kInk.withValues(alpha: 0.45) : _kInk,
            fontSize: 18,
            height: 1.35,
            fontWeight: empty ? FontWeight.w700 : FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, this.height = 10});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD8CBA8),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFFBCA87E)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA5DC5C), Color(0xFF6FB52E)],
            ),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.stageLabel,
    required this.score,
    required this.total,
    required this.passed,
    this.reward,
  });

  final String stageLabel;
  final int score;
  final int total;
  final bool passed;
  final StageReward? reward;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _kBorder, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              passed ? 'Hoàn thành $stageLabel!' : 'Cố lên nào!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kInk,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn trả lời đúng $score/$total câu',
              style: const TextStyle(
                color: _kInk,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (reward != null && passed) ...[
              const SizedBox(height: 8),
              Text(
                '+${reward!.xpGained} XP   🪙 +${reward!.coinsGained}',
                style: const TextStyle(
                  color: _kBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (reward!.leveledUp)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🎉 Lên cấp ${reward!.profile.level}!',
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Học lại',
                    color: _kBlue,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: 'Tiếp tục',
                    color: _kGreen,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DialogButton(
            label: 'Quay lại',
            color: _kGreen,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
