import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/vocab_topic.dart';
import '../../../data/models/vocab_word.dart';
import '../../../data/repositories/vocabulary_repository.dart';

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

class _Question {
  _Question({
    required this.word,
    required this.options,
    required this.correctIdx,
  });

  final VocabWord word;
  final List<String> options;
  final int correctIdx;
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
  const LessonScreen({super.key, required this.topicId});
  final int topicId;

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

  bool get _answered => _selectedIdx != null;
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
    _load();
  }

  @override
  void dispose() {
    _stageScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = VocabularyRepository.instance;
      final topic = await repo.topicById(widget.topicId);
      final words = await repo.wordsForTopic(widget.topicId);
      if (!mounted) return;
      if (words.length < 4) {
        setState(() {
          _error = 'Chủ đề này chưa có đủ từ vựng.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _topic = topic;
        _allWords = words;
        _stages = _buildStages(words.length);
        _loading = false;
      });
      _startStage(0);
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

  List<_Question> _buildQuestions(_Stage stage) {
    final pool = _allWords.sublist(stage.start, stage.end)..shuffle(_rng);
    return [for (final w in pool) _buildQuestion(w)];
  }

  _Question _buildQuestion(VocabWord word) {
    final distractors =
        _allWords.where((w) => w.meaning != word.meaning).toList()
          ..shuffle(_rng);
    final options = [
      word.meaning,
      ...distractors.take(3).map((w) => w.meaning),
    ]..shuffle(_rng);
    return _Question(
      word: word,
      options: options,
      correctIdx: options.indexOf(word.meaning),
    );
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
      _questions = _buildQuestions(_stages[idx]);
      _qIdx = 0;
      _score = 0;
      _selectedIdx = null;
      _hintsLeft = 3;
      _hiddenOptions.clear();
    });
    _scrollToStage(idx);
  }

  void _scrollToStage(int idx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stageScroll.hasClients) return;
      const stageExtent = 82.0;
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

  void _onStageTap(int idx) {
    if (idx == _stageIdx || !_isUnlocked(idx)) return;
    _startStage(idx);
  }

  void _onSelect(int idx) {
    if (_answered || _hiddenOptions.contains(idx)) return;
    setState(() {
      _selectedIdx = idx;
      if (idx == _question.correctIdx) _score++;
    });
    Future.delayed(const Duration(milliseconds: 1000), _next);
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
    });
  }

  void _useHint() {
    if (_hintsLeft <= 0 || _answered || _loading || _error != null) return;
    final wrong = [
      for (var i = 0; i < _question.options.length; i++)
        if (i != _question.correctIdx && !_hiddenOptions.contains(i)) i,
    ]..shuffle(_rng);
    setState(() {
      _hintsLeft--;
      _hiddenOptions.addAll(wrong.take(2));
    });
  }

  Future<void> _showResult() async {
    final total = _questions.length;
    final passed = _score >= (total * 0.6).ceil();
    if (passed) _completedStages.add(_stageIdx);
    final stars = _score >= total * 0.9
        ? 3
        : (_score >= total * 0.6 ? 2 : (_score >= total * 0.3 ? 1 : 0));

    final replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        stageLabel: _stages[_stageIdx].label,
        score: _score,
        total: total,
        stars: stars,
        passed: passed,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Nền rừng: trời xanh → tán lá → cỏ đậm (chưa có ảnh nền riêng).
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
        child: SafeArea(
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
                            const SizedBox(height: 6),
                            _buildQuestionProgress(),
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
          Expanded(
            child: Text(
              'Câu ${_qIdx + 1}/${_questions.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.white70,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          _SquareButton(
            onTap: _showVocabList,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('📖', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text(
                  'Từ vựng',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionProgress() {
    final progress = (_qIdx + (_answered ? 1 : 0)) / _questions.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
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
            Expanded(child: _ProgressBar(progress: progress, height: 12)),
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
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
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
                    for (var i = 0; i < _question.options.length; i++) ...[
                      _buildOption(i),
                      const SizedBox(height: 10),
                    ],
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
    final word = _question.word;
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
          child: Column(
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
              // Nút phát âm — trang trí, audio sẽ bổ sung sau
              Container(
                width: 54,
                height: 54,
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
                child: const Icon(Icons.volume_up_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn nghĩa tiếng Việt đúng',
                style: TextStyle(
                  color: _kInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      height: 92,
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
            const Text('🥚', style: TextStyle(fontSize: 26)),
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
            const Text('🧰', style: TextStyle(fontSize: 26)),
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

  @override
  Widget build(BuildContext context) {
    final boxSize = isCurrent ? 52.0 : 44.0;
    final icon = stage.kind == _StageKind.learn
        ? Icons.menu_book_rounded
        : Icons.autorenew_rounded;

    final iconBox = Container(
      width: boxSize,
      height: boxSize,
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
      child: Icon(
        icon,
        size: isCurrent ? 28 : 24,
        color: isCurrent
            ? Colors.white
            : isUnlocked
                ? _kGreen
                : _kInk.withValues(alpha: 0.35),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Đường nối hai bên, đi qua tâm ô icon (tâm tại y = 28)
            Positioned(
              top: 26,
              left: 0,
              right: 41,
              child: isFirst
                  ? const SizedBox(height: 4)
                  : Container(height: 4, color: _kCreamDark),
            ),
            Positioned(
              top: 26,
              left: 41,
              right: 0,
              child: isLast
                  ? const SizedBox(height: 4)
                  : Container(height: 4, color: _kCreamDark),
            ),
            Positioned(
              top: 28 - boxSize / 2,
              child: Opacity(
                opacity: isUnlocked ? 1 : 0.55,
                child: iconBox,
              ),
            ),
            // Mũi nhọn dưới ô đang chơi
            if (isCurrent)
              Positioned(
                top: 28 + boxSize / 2 - 7,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 11,
                    height: 11,
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
                top: 28 + boxSize / 2 - 11,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 12),
                ),
              ),
            Positioned(
              top: 60,
              child: Text(
                stage.label,
                style: TextStyle(
                  color: _kInk,
                  fontSize: 12,
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, this.height = 10});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
  });

  final String stageLabel;
  final int score;
  final int total;
  final int stars;
  final bool passed;

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
