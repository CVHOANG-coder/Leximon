import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/tts/tts_service.dart';
import '../../../data/models/context_sentence.dart';
import '../../../data/models/vocab_topic.dart';
import '../../../data/models/vocab_word.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/progress_repository.dart';
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

const _kOptionBadgeColors = [
  Color(0xFF3CB54A), // green
  Color(0xFF2196F3), // blue
  Color(0xFFF5A623), // orange
  Color(0xFF9C27B0), // purple
];

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

enum _StageKind { learn, review }

/// One stage on the bottom track: "Học 1-10", "Ôn 1-10", "Học 11-20", …
/// [start] inclusive / [end] exclusive indices into the topic word list.
class _Stage {
  const _Stage({required this.kind, required this.start, required this.end});

  final _StageKind kind;
  final int start;
  final int end;

  int get wordCount => end - start;
  String get label =>
      '${kind == _StageKind.learn ? 'Học' : 'Ôn'} ${start + 1}-$end';
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
  static const int _chunkSize = 10;

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
  int _hintsLeft = 3;
  final Set<int> _hiddenOptions = {};

  // Trạng thái dạng sắp xếp (anagram / sentenceOrder):
  // chỉ số các thẻ đã đặt vào ô trống, theo thứ tự đặt.
  final List<int> _placed = [];
  bool _arrangeChecked = false;
  bool _arrangeCorrect = false;

  /// Câu ngữ cảnh của chủ đề, nhóm theo từ đáp án (chữ thường).
  Map<String, List<ContextSentence>> _sentences = const {};

  bool get _answered => _selectedIdx != null || _arrangeChecked;
  _Question get _question => _questions[_qIdx];

  /// Số từ đã học = tổng từ của các chặng "Học" đã hoàn thành.
  int get _learnedWords => [
        for (var i = 0; i < _stages.length; i++)
          if (_completedStages.contains(i) &&
              _stages[i].kind == _StageKind.learn)
            _stages[i].wordCount,
      ].fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    // Khởi tạo TTS sớm (lần đầu sẽ tải model nền) để nút loa sẵn sàng.
    TtsService.instance.init();
    _load();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
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
      final savedStages =
          await ProgressRepository.instance.getStagesForTopic(widget.topicId);
      if (!mounted) return;
      if (words.length < 4) {
        setState(() {
          _error = 'Chủ đề này chưa có đủ từ vựng.';
          _loading = false;
        });
        return;
      }
      final stages = _buildStages(words.length);
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

  List<_Stage> _buildStages(int wordCount) {
    return [
      for (var s = 0; s < wordCount; s += _chunkSize) ...[
        _Stage(
          kind: _StageKind.learn,
          start: s,
          end: math.min(s + _chunkSize, wordCount),
        ),
        _Stage(
          kind: _StageKind.review,
          start: s,
          end: math.min(s + _chunkSize, wordCount),
        ),
      ],
    ];
  }

  /// Số câu hỏi mục tiêu cho 1 chặng theo `questionCountRules` ở
  /// `topics_with_stage_difficulty.json`.
  int _targetQuestionCount({
    required _StageKind kind,
    required int stageIdx,
    required int totalStages,
    required int wordCount,
  }) {
    if (kind == _StageKind.learn) {
      return (wordCount * 0.65).ceil().clamp(6, 10);
    }
    final isLast = stageIdx == totalStages - 1;
    if (isLast) {
      // final_review: fixed theo độ dài topic (tính trên _stages tổng).
      if (totalStages <= 3) return 12;
      if (totalStages <= 5) return 16;
      if (totalStages <= 7) return 22;
      if (totalStages <= 9) return 28;
      if (totalStages <= 11) return 34;
      return 40;
    }
    // review: nửa đầu = normal, nửa sau = hard.
    final isEarlyHalf = stageIdx < totalStages / 2;
    return isEarlyHalf
        ? (wordCount * 0.85).ceil().clamp(8, 12)
        : (wordCount * 1.05).ceil().clamp(10, 15);
  }

  List<_Question> _buildQuestions(_Stage stage, int stageIdx) {
    final pool = _allWords.sublist(stage.start, stage.end)..shuffle(_rng);
    final target = _targetQuestionCount(
      kind: stage.kind,
      stageIdx: stageIdx,
      totalStages: _stages.length,
      wordCount: pool.length,
    );

    // Chặng "Học": chỉ dạng chọn nghĩa để làm quen từ mới — lặp lại pool
    // nếu thiếu, cắt nếu thừa, để khớp số câu mục tiêu.
    if (stage.kind == _StageKind.learn) {
      return [
        for (var i = 0; i < target; i++) _buildMeaningQuestion(pool[i % pool.length]),
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
            pool[i % pool.length], cycle[i % cycle.length], usedSentences),
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
      _QKind.fillBlank =>
        const [_QKind.fillBlank, _QKind.anagram, _QKind.listening],
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
        _QKind.sentenceOrder =>
          _buildSentenceOrderQuestion(word, usedSentences),
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
    final options = [
      word.meaning,
      ...distractors.take(3).map((w) => w.meaning),
    ]..shuffle(_rng);
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
    final options = [
      word.word,
      ...distractors.take(3).map((w) => w.word),
    ]..shuffle(_rng);
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
    final options = [
      word.word,
      ...distractors.take(3).map((w) => w.word),
    ]..shuffle(_rng);
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
    setState(() {
      _stageIdx = idx;
      _questions = _buildQuestions(_stages[idx], idx);
      _qIdx = 0;
      _score = 0;
      _selectedIdx = null;
      _hintsLeft = 3;
      _hiddenOptions.clear();
      _placed.clear();
      _arrangeChecked = false;
      _arrangeCorrect = false;
    });
    _scrollToStage(idx);
    _autoPlayIfListening();
  }

  void _scrollToStage(int idx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stageScroll.hasClients) return;
      const stageExtent = 96.0;
      final target = (idx * stageExtent -
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
    final inProgress = _qIdx > 0 ||
        _score > 0 ||
        _placed.isNotEmpty ||
        _selectedIdx != null;
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
    final correct = idx == _question.correctIdx;
    setState(() {
      _selectedIdx = idx;
      if (correct) _score++;
    });
    // Lưu thống kê đúng/sai của từ vào SQLite (không chặn UI).
    ProgressRepository.instance.recordAnswer(
      topicId: widget.topicId,
      word: _question.word.word,
      correct: correct,
    );
    Future.delayed(const Duration(milliseconds: 1000), _next);
  }

  // ── Dạng sắp xếp: đặt / gỡ thẻ ────────────────────────────────────────────

  void _onTokenTap(int tokenIdx) {
    if (_answered || _placed.contains(tokenIdx)) return;
    setState(() => _placed.add(tokenIdx));
    if (_placed.length == _question.answerTokens.length) _checkArrange();
  }

  void _onSlotTap(int slotIdx) {
    if (_answered || slotIdx >= _placed.length) return;
    setState(() => _placed.removeAt(slotIdx));
  }

  void _checkArrange() {
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
      if (correct) _score++;
    });
    ProgressRepository.instance.recordAnswer(
      topicId: widget.topicId,
      word: q.word.word,
      correct: correct,
    );
    Future.delayed(const Duration(milliseconds: 1300), _next);
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
      _hiddenOptions.clear();
      _placed.clear();
      _arrangeChecked = false;
      _arrangeCorrect = false;
    });
    _autoPlayIfListening();
  }

  void _useHint() {
    if (_hintsLeft <= 0 || _answered || _loading || _error != null) return;
    if (_question.isChoice) {
      // Ẩn bớt 2 đáp án sai.
      final wrong = [
        for (var i = 0; i < _question.options.length; i++)
          if (i != _question.correctIdx && !_hiddenOptions.contains(i)) i,
      ]..shuffle(_rng);
      setState(() {
        _hintsLeft--;
        _hiddenOptions.addAll(wrong.take(2));
      });
      return;
    }
    // Dạng sắp xếp: tự đặt thẻ đúng tiếp theo vào ô trống.
    final q = _question;
    final needed = q.answerTokens[_placed.length];
    for (var i = 0; i < q.tokens.length; i++) {
      if (!_placed.contains(i) && q.tokens[i] == needed) {
        setState(() {
          _hintsLeft--;
          _placed.add(i);
        });
        if (_placed.length == q.answerTokens.length) _checkArrange();
        return;
      }
    }
  }

  Future<void> _showResult() async {
    final total = _questions.length;
    final passed = _score >= (total * 0.6).ceil();
    if (passed) _completedStages.add(_stageIdx);
    final stars = _score >= total * 0.9
        ? 3
        : (_score >= total * 0.6 ? 2 : (_score >= total * 0.3 ? 1 : 0));

    final stage = _stages[_stageIdx];
    final isLastStage = _stageIdx == _stages.length - 1;
    // Chặng review cuối topic = final_review → kích hoạt mức thưởng
    // boss / elite_boss theo độ dài topic (xem reward_mechanism_explanation.md).
    final stageType = stage.kind == _StageKind.learn
        ? 'learn'
        : (isLastStage ? 'final_review' : 'review');
    final reward = await ProgressRepository.instance.recordStagePlay(
      topicId: widget.topicId,
      stage: _stageIdx + 1,
      stageType: stageType,
      score: _score,
      totalQuestions: total,
      stars: stars,
      passed: passed,
      totalStages: _stages.length,
      learnedWords: stage.kind == _StageKind.learn
          ? [for (final w in _allWords.sublist(stage.start, stage.end)) w.word]
          : const [],
    );

    final payload = passed
        ? await RewardService.instance.rollStageReward(
            stageType: stageType,
            stageIndex: _stageIdx,
            totalStages: _stages.length,
            stars: stars,
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
              stars: stars,
              reward: payload,
              topicId: widget.topicId,
              stage: _stageIdx + 1,
              difficulty: difficulty,
            )
          : _ResultDialog(
              stageLabel: _stages[_stageIdx].label,
              score: _score,
              total: total,
              stars: stars,
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
            colors: [
              Color(0xFF59A7E8),
              Color(0xFF7FBF6A),
              Color(0xFF3F7E33),
            ],
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
      body: _background(
        SafeArea(
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
                            _buildStageTrack(),
                            _buildTopicProgress(),
                          ],
                        ),
        ),
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

  /// Hộp tiến độ gọn: "Câu x/y" phía trên thanh tiến độ, huy hiệu sao bên phải.
  Widget _buildQuestionProgress() {
    final progress = (_qIdx + (_answered ? 1 : 0)) / _questions.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 6),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
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
            child:
                const Icon(Icons.star_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayArea() {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cột trái: panel Đội hình + linh vật
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 14),
              child: Column(
                children: [
                  const _TeamPanel(),
                  const Spacer(),
                  Text(
                    '🦊',
                    style: TextStyle(
                      fontSize: 46,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            // Vùng câu hỏi + đáp án
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 6, 14, 8),
                child: Column(
                  children: [
                    _buildQuestionCard(),
                    const SizedBox(height: 16),
                    if (_question.isChoice)
                      for (var i = 0; i < _question.options.length; i++) ...[
                        _buildOption(i),
                        const SizedBox(height: 10),
                      ]
                    else
                      _buildArrangeArea(),
                    const SizedBox(height: 56),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 10,
          bottom: 6,
          child: _HintButton(count: _hintsLeft, onTap: _useHint),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(26),
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
              child:
                  const Icon(Icons.star_rounded, color: _kGold, size: 20),
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
          fontSize: 15,
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
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
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
            fontSize: 38,
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
        const SizedBox(height: 14),
        _speakerButton(54),
        const SizedBox(height: 16),
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
        _speakerButton(84),
        const SizedBox(height: 8),
        Text(
          'Chạm loa để nghe lại',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 6),
          Text(
            word.word.toLowerCase(),
            style: const TextStyle(
              color: _kGreen,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            word.phonetic,
            style: TextStyle(
              color: _kInk.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
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
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 2, color: _kCreamDark),
        const SizedBox(height: 12),
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
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
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
              onTapRemoveLast:
                  _placed.isEmpty ? null : () => _onSlotTap(_placed.length - 1),
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

  Widget _buildOption(int idx) {
    final hidden = _hiddenOptions.contains(idx);
    final isCorrect = idx == _question.correctIdx;
    final isSelected = idx == _selectedIdx;

    Color bg = _kCream;
    Color border = _kBorder;
    if (_answered && isCorrect) {
      bg = const Color(0xFFE4F6E0);
      border = _kGreen;
    } else if (_answered && isSelected && !isCorrect) {
      bg = const Color(0xFFFBE2E0);
      border = _kRed;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: hidden ? 0.25 : 1,
      child: GestureDetector(
        onTap: () => _onSelect(idx),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kOptionBadgeColors[idx % _kOptionBadgeColors.length],
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _question.options[idx],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                child: _answered && isCorrect
                    ? const Icon(Icons.check_circle, color: _kGreen)
                    : _answered && isSelected && !isCorrect
                        ? const Icon(Icons.cancel, color: _kRed)
                        : null,
              ),
            ],
          ),
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

  Widget _buildTopicProgress() {
    final total = _allWords.length;
    final learned = _learnedWords;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/eggs/scholar_egg.png',
              width: 44,
              height: 44,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        const TextSpan(text: 'Tiến độ chủ đề '),
                        TextSpan(
                          text: '$learned/$total',
                          style: const TextStyle(color: _kBlue),
                        ),
                        const TextSpan(text: ' từ'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  _ProgressBar(
                    progress: total == 0 ? 0 : learned / total,
                    height: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Image.asset(
              'assets/images/task/chess_stage.png',
              width: 46,
              height: 46,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Đội hình panel (trang trí — hệ thống pet sẽ nối sau) ─────────────────────

class _TeamPanel extends StatelessWidget {
  const _TeamPanel();

  static const _pets = [('🦊', 6), ('🐤', 5), ('🌱', 4)];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBEE3F5), Color(0xFF8FC7E8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6FA8CC), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Đội hình',
            style: TextStyle(
              color: _kInk,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final (emoji, lv) in _pets) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF274B6D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 2),
                  Text(
                    'Lv. $lv',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _ProgressBar(progress: lv / 10, height: 5),
                  ),
                ],
              ),
            ),
          ],
        ],
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
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
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
              child: Opacity(
                opacity: isUnlocked ? 1 : 0.55,
                child: iconBox,
              ),
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
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 15),
                ),
              ),
            Positioned(
              top: _centerY + 40,
              child: Text(
                stage.label,
                style: TextStyle(
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

class _HintButton extends StatelessWidget {
  const _HintButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              children: [
                Text('💡', style: TextStyle(fontSize: 24)),
                SizedBox(height: 2),
                Text(
                  'Gợi ý',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -7,
            right: -7,
            child: Container(
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
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
          padding:
              square ? null : const EdgeInsets.symmetric(horizontal: 12),
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
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE8A93B), size: 48),
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
      // Nền (track) luôn chiếm hết bề rộng — kể cả khi tiến độ 0%,
      // tránh thanh co lại thành một vạch.
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
    required this.stars,
    required this.passed,
    this.reward,
  });

  final String stageLabel;
  final int score;
  final int total;
  final int stars;
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: i < stars
                        ? const Color(0xFFF5A623)
                        : const Color(0xFFD8CBA8),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
