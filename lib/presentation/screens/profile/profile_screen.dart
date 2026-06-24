import 'package:flutter/material.dart';

import '../../../data/models/learning_activity.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/progress_repository.dart';

/// Formats an integer with `.` as the thousands separator (e.g. 4000 → 4.000).
String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Player profile ("Hồ sơ người chơi") — identity card, EXP progress,
/// level rewards track and the monthly learning-activity heatmap.
///
/// Dữ liệu EXP, level, heatmap và thống kê học tập được đọc từ SQLite qua
/// [ProgressRepository].
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String _assets = 'assets/images/profileInfo';

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _parchment = Color(0xFFF7E8C1);
  static const Color _parchmentDark = Color(0xFFEFD9A6);
  static const Color _goldBorder = Color(0xFFC79A45);
  static const Color _goldLight = Color(0xFFE9C45F);
  static const Color _ink = Color(0xFF4A2F12);
  static const Color _blue = Color(0xFF2E6FB7);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<PlayerProgressOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = ProgressRepository.instance.getPlayerProgressOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C2A20),
          image: DecorationImage(
            image: AssetImage('${ProfileScreen._assets}/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: FutureBuilder<PlayerProgressOverview>(
                  future: _overview,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Không thể tải tiến độ: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final overview = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _overview = ProgressRepository.instance
                              .getPlayerProgressOverview();
                        });
                        await _overview;
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            _IdentityCard(overview: overview),
                            const SizedBox(height: 14),
                            const _LevelRewardsPanel(),
                            const SizedBox(height: 14),
                            _ActivityPanel(
                              activities: overview.activities,
                              month: DateTime.now(),
                            ),
                            const SizedBox(height: 14),
                            _StatsPanel(profile: overview.profile),
                            const SizedBox(height: 14),
                            const _MascotBanner(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable parchment panel with a double gold frame ────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;
  static const EdgeInsets padding = EdgeInsets.all(8);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ProfileScreen._goldBorder,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: ProfileScreen._parchment,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ProfileScreen._goldLight, width: 2),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

// ─── Top bar: back · title banner · info menu ─────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Image.asset(
              'assets/images/back_button/back1.png',
              width: 48,
              height: 48,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
          ),
          const Expanded(
            child: Center(child: _TitleBanner(text: 'Hồ sơ người chơi')),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF59C2F2), Color(0xFF2E7FD6)],
                  ),
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Thông tin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBanner extends StatelessWidget {
  const _TitleBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            '${ProfileScreen._assets}/container_title.png',
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Title text sits on the wooden plank (nudged down past the gems).
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 24, right: 24),
            child: Text(
              text,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFFFF1CE),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    color: Color(0xFF5A3410),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Identity card: avatar · name · slogan · trophy · EXP ─────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.overview});

  final PlayerProgressOverview overview;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Avatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Flexible(
                          child: Text(
                            'Học Giỏi Mỗi Ngày',
                            style: TextStyle(
                              color: ProfileScreen._blue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.school, color: ProfileScreen._ink, size: 22),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Kiến thức hôm nay\nTương lai tỏa sáng!',
                            style: TextStyle(
                              color: ProfileScreen._ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        Image.asset(
                          '${ProfileScreen._assets}/icon10.png',
                          width: 64,
                          height: 64,
                          errorBuilder: (_, _, _) => const SizedBox(width: 64),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ExpPanel(
            profile: overview.profile,
            requiredXp: overview.xpToNextLevel,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ProfileScreen._goldBorder, width: 0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset(
                '${ProfileScreen._assets}/avatar_default.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: ProfileScreen._parchmentDark,
                  child: const Icon(Icons.person, size: 48),
                ),
              ),
            ),
          ),
          const Positioned(bottom: -6, right: -6, child: _EditDot(size: 26)),
        ],
      ),
    );
  }
}

class _EditDot extends StatelessWidget {
  const _EditDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF59C2F2), Color(0xFF2E7FD6)],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Colors.white, width: 2),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(Icons.edit, color: Colors.white, size: size * 0.55),
    );
  }
}

// ─── EXP sub-panel ────────────────────────────────────────────────────────────

class _ExpPanel extends StatelessWidget {
  const _ExpPanel({required this.profile, required this.requiredXp});

  final UserProfile profile;
  final int? requiredXp;

  @override
  Widget build(BuildContext context) {
    final isMaxLevel = requiredXp == null;
    final required = requiredXp ?? 1;
    final remaining = isMaxLevel ? 0 : required - profile.xp;
    final progress = isMaxLevel ? 1.0 : profile.xp / required;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProfileScreen._parchmentDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileScreen._goldBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LevelBadge(level: profile.level),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      '${ProfileScreen._assets}/icon1.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (_, _, _) => const SizedBox(width: 30),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Kinh nghiệm',
                      style: TextStyle(
                        color: ProfileScreen._blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isMaxLevel ? 'Đã đạt' : 'Cấp tiếp theo',
                          style: TextStyle(
                            color: ProfileScreen._ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isMaxLevel ? 'Tối đa' : 'Lv. ${profile.level + 1}',
                          style: const TextStyle(
                            color: ProfileScreen._ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isMaxLevel
                      ? '${_fmt(profile.totalXp)} EXP tổng'
                      : '${_fmt(profile.xp)}/${_fmt(required)} EXP',
                  style: const TextStyle(
                    color: ProfileScreen._ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _SegmentedBar(progress: progress),
                const SizedBox(height: 6),
                Text(
                  isMaxLevel
                      ? 'Bạn đã đạt cấp tối đa'
                      : 'Còn ${_fmt(remaining)} EXP để lên cấp',
                  style: const TextStyle(
                    color: ProfileScreen._ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            '${ProfileScreen._assets}/frame_level.png',
            width: 64,
            height: 78,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Lv. $level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xFF103A66),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented blue progress bar like the mockup (8 notches).
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.progress});

  final double progress;
  static const int segments = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 2.0;
          final segW = (c.maxWidth - gap * (segments - 1)) / segments;
          final filledExact = progress * segments;
          return Row(
            children: List.generate(segments, (i) {
              final fill = (filledExact - i).clamp(0.0, 1.0);
              return Container(
                width: segW,
                margin: EdgeInsets.only(right: i == segments - 1 ? 0 : gap),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBA86A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF9C7838)),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF5AA6F0), Color(0xFF2E78D6)],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Level rewards track ──────────────────────────────────────────────────────

enum _RewardState { claimed, current, locked }

class _Reward {
  const _Reward(this.asset, this.amount, this.state);
  final String asset;
  final String amount;
  final _RewardState state;
}

class _LevelRewardsPanel extends StatelessWidget {
  const _LevelRewardsPanel();

  static const List<_Reward> _rewards = [
    _Reward('assets/images/coin.png', '10.000', _RewardState.claimed),
    _Reward('${ProfileScreen._assets}/icon3.png', 'x1', _RewardState.claimed),
    _Reward('assets/images/eggs/common_egg.png', 'x1', _RewardState.claimed),
    _Reward('assets/images/stone_upgrade.png', 'x50', _RewardState.current),
    _Reward('${ProfileScreen._assets}/icon4.png', 'x1', _RewardState.locked),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                '${ProfileScreen._assets}/icon2.png',
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => const SizedBox(width: 28),
              ),
              const SizedBox(width: 8),
              const Text(
                'Phần thưởng theo cấp',
                style: TextStyle(
                  color: ProfileScreen._blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.info, color: ProfileScreen._blue, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          // Track line behind the state nodes.
          Stack(
            children: [
              Positioned(
                left: 18,
                right: 18,
                top: 12,
                child: Container(height: 4, color: const Color(0xFFCBA86A)),
              ),
              Row(
                children: [
                  for (final r in _rewards)
                    Expanded(child: _RewardColumn(reward: r)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardColumn extends StatelessWidget {
  const _RewardColumn({required this.reward});

  final _Reward reward;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StateNode(state: reward.state),
        const SizedBox(height: 8),
        _RewardTile(reward: reward),
        const SizedBox(height: 8),
        _StatusPill(state: reward.state),
      ],
    );
  }
}

class _StateNode extends StatelessWidget {
  const _StateNode({required this.state});

  final _RewardState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _RewardState.claimed:
        return _circle(
          const Color(0xFF3FB45A),
          const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _RewardState.current:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFF4D0),
            border: Border.all(color: const Color(0xFFE9B43C), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88F2C94C),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      case _RewardState.locked:
        return _circle(
          const Color(0xFF9AA0A6),
          const Icon(Icons.star, color: Colors.white, size: 15),
        );
    }
  }

  Widget _circle(Color color, Widget child) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Center(child: child),
  );
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward});

  final _Reward reward;

  @override
  Widget build(BuildContext context) {
    final isCurrent = reward.state == _RewardState.current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6E4A28), Color(0xFF4E331C)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? const Color(0xFFF2C94C) : const Color(0xFF8A6034),
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: isCurrent
            ? const [
                BoxShadow(
                  color: Color(0x88F2C94C),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              reward.asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_not_supported, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reward.amount,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _RewardState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _RewardState.claimed => ('Đã nhận', const Color(0xFF2E9E48)),
      _RewardState.current => ('Sắp nhận', const Color(0xFF2E78D6)),
      _RewardState.locked => ('Chưa đạt', const Color(0xFF6B4A2A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Learning activity: heatmap + stat list ───────────────────────────────────

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activities, required this.month});

  final List<DailyLearningActivity> activities;
  final DateTime month;

  static const List<String> _dayLabels = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  static Color _cellColor(int level) => switch (level) {
    -1 => const Color(0xFFF1E8CC),
    0 => const Color(0xFFE6DFA2),
    1 => const Color(0xFFAFD487),
    2 => const Color(0xFF54B79A),
    3 => const Color(0xFF2E94C4),
    _ => const Color(0xFF3E63C8),
  };

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: ProfileScreen._blue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Hoạt động học tập',
                style: TextStyle(
                  color: ProfileScreen._blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ProfileScreen._goldBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tháng ${month.month}/${month.year}',
                      style: const TextStyle(
                        color: ProfileScreen._ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: ProfileScreen._ink,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Heatmap(activities: activities, month: month),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activities, required this.month});

  final List<DailyLearningActivity> activities;
  final DateTime month;

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int _activityLevel(DailyLearningActivity? activity) {
    if (activity == null) return 0;
    return activity.stagesPlayed.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    const labelW = 30.0;
    final firstDay = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final usedCells = firstDay.weekday - 1 + lastDay.day;
    final weekCount = (usedCells / 7).ceil();
    final activityByDate = {
      for (final activity in activities) _dateKey(activity.date): activity,
    };
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-of-week header.
        Row(
          children: [
            const SizedBox(width: labelW),
            for (final d in _ActivityPanel._dayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: ProfileScreen._ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weekCount; w++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: labelW,
                  child: Text(
                    'Tuần ${w + 1}',
                    style: const TextStyle(
                      color: ProfileScreen._ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (var day = 0; day < 7; day++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Builder(
                          builder: (context) {
                            final date = gridStart.add(
                              Duration(days: w * 7 + day),
                            );
                            final outsideMonth = date.month != month.month;
                            final isFuture = date.isAfter(
                              DateTime(today.year, today.month, today.day),
                            );
                            final level = outsideMonth || isFuture
                                ? -1
                                : _activityLevel(
                                    activityByDate[_dateKey(date)],
                                  );
                            return Container(
                              decoration: BoxDecoration(
                                color: _ActivityPanel._cellColor(level),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFFCBB984),
                                  width: 0.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: outsideMonth
                                  ? null
                                  : Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        color: ProfileScreen._ink,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Learning-stats summary in its own panel, below the activity heatmap.
/// Four stats laid out as a 2×2 grid to fill the full panel width.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastDay = profile.lastLearningDate;
    final currentStreak =
        lastDay == null ||
            DateTime(now.year, now.month, now.day)
                    .difference(
                      DateTime(lastDay.year, lastDay.month, lastDay.day),
                    )
                    .inDays >
                1
        ? 0
        : profile.currentStreak;
    final stats = [
      _StatRow(
        asset: '${ProfileScreen._assets}/icon9.png',
        label: 'Tổng số từ đã học',
        value: _fmt(profile.learnedWords),
        valueColor: ProfileScreen._blue,
      ),
      _StatRow(
        asset: '${ProfileScreen._assets}/icon6.png',
        label: 'Số ngày học',
        value: '${profile.learningDays} ngày',
        valueColor: Color(0xFF2E9E48),
      ),
      _StatRow(
        asset: '${ProfileScreen._assets}/icon7.png',
        label: 'Chuỗi học hiện tại',
        value: '$currentStreak ngày',
        valueColor: Color(0xFFE0492E),
        badge: currentStreak >= 7 ? 'Tuyệt!' : null,
      ),
      _StatRow(
        asset: '${ProfileScreen._assets}/icon4.png',
        label: 'Bài học đã hoàn thành',
        value: '${profile.completedStages} màn',
        valueColor: ProfileScreen._blue,
      ),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.insights, color: ProfileScreen._blue, size: 22),
              SizedBox(width: 8),
              Text(
                'Thống kê học tập',
                style: TextStyle(
                  color: ProfileScreen._blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            stats[i],
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.asset,
    required this.label,
    required this.value,
    required this.valueColor,
    this.badge,
  });

  final String asset;
  final String label;
  final String value;
  final Color valueColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          asset,
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(width: 34),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ProfileScreen._ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF6B73C), Color(0xFFE08A2E)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const List<(String, int)> _items = [
    ('Không học', 0),
    ('1 màn', 1),
    ('2 màn', 2),
    ('3 màn', 3),
    ('4+ màn', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (label, level) in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _ActivityPanel._cellColor(level),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFCBB984),
                    width: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: ProfileScreen._ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Bottom mascot encouragement banner ───────────────────────────────────────

class _MascotBanner extends StatelessWidget {
  const _MascotBanner();

  // Sparkles scattered behind the text: (left?, right?, top, size, opacity).
  static const List<
    ({double? left, double? right, double top, double size, double opacity})
  >
  _sparkles = [
    (left: 96, right: null, top: 8, size: 14, opacity: 0.9),
    (left: 150, right: null, top: 40, size: 9, opacity: 0.7),
    (left: 200, right: null, top: 6, size: 8, opacity: 0.6),
    (left: null, right: 120, top: 12, size: 12, opacity: 0.85),
    (left: null, right: 96, top: 46, size: 10, opacity: 0.7),
    (left: null, right: 150, top: 30, size: 7, opacity: 0.6),
    (left: 130, right: null, top: 60, size: 8, opacity: 0.6),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Outer gold frame.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEBC25A), Color(0xFFB07F2C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          // Inner navy panel with a radial glow + thin inner gold line.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFF4DB97), width: 1.2),
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [Color(0xFF1E5C96), Color(0xFF123A66), Color(0xFF0C2546)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Sparkles behind the content.
                for (final s in _sparkles)
                  Positioned(
                    left: s.left,
                    right: s.right,
                    top: s.top,
                    child: Icon(
                      Icons.auto_awesome,
                      size: s.size,
                      color: const Color(
                        0xFFFFE9A8,
                      ).withValues(alpha: s.opacity),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        '${ProfileScreen._assets}/icon8.png',
                        width: 66,
                        height: 66,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(width: 66),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(child: _BannerText()),
                      const SizedBox(width: 6),
                      Image.asset(
                        '${ProfileScreen._assets}/icon5.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(width: 58),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-line encouragement text painted with a metallic-gold vertical gradient.
class _BannerText extends StatelessWidget {
  const _BannerText();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF6D6), Color(0xFFFFE29A), Color(0xFFE9B454)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'Mỗi ngày một chút cố gắng,\nKiến thức sẽ giúp bạn tỏa sáng!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          height: 1.35,
          shadows: [
            Shadow(
              color: Color(0xFF06203F),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
