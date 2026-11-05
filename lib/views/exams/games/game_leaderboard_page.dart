// lib/views/exams/games/game_leaderboard_page.dart
//
// لوحة ترتيب لعبة: أفضل نتيجة لكل طالب (النقاط تنازليًا، والأسرع عند
// التساوي). التعدّد للمدرس بس (قواعد Firestore) — والمشاركة نص واتساب.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/services/online_game_service.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

/// نص ترتيب جاهز للمشاركة (أول [top] طلاب).
String gameLeaderboardShareText(String title, List<GameScore> ranked,
    {int top = 10}) {
  final b = StringBuffer('🏆 ترتيب لعبة «$title»\n');
  const medals = ['🥇', '🥈', '🥉'];
  for (var i = 0; i < ranked.length && i < top; i++) {
    final s = ranked[i];
    final mark = i < 3 ? medals[i] : '${i + 1}.';
    b.writeln('$mark ${s.name.isEmpty ? s.code : s.name} — ${s.score} نقطة');
  }
  return b.toString().trimRight();
}

class GameLeaderboardPage extends StatefulWidget {
  final OnlineGame game;
  const GameLeaderboardPage({super.key, required this.game});

  @override
  State<GameLeaderboardPage> createState() => _GameLeaderboardPageState();
}

class _GameLeaderboardPageState extends State<GameLeaderboardPage> {
  List<GameScore>? _scores;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final s = await OnlineGameService().fetchScores(widget.game.id);
      if (mounted) setState(() => _scores = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scores = _scores;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'ترتيب: ${widget.game.title}',
        actions: [
          if (scores != null && scores.isNotEmpty)
            IconButton(
              tooltip: 'مشاركة الترتيب',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => Share.share(
                  gameLeaderboardShareText(widget.game.title, scores)),
            ),
        ],
      ),
      body: _failed && scores == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('تعذّر تحميل الترتيب',
                  style: AppType.label.copyWith(color: t.inkSoft)),
              const SizedBox(height: AppSpace.md),
              FilledButton(onPressed: _load, child: const Text('حاول تاني')),
            ]))
          : scores == null
              ? Center(child: CircularProgressIndicator(color: t.brand))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: scores.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.sizeOf(context).height * 0.25),
                            Icon(Icons.emoji_events_outlined,
                                size: 52, color: t.inkFaint),
                            const SizedBox(height: AppSpace.lg),
                            Text('لسه محدش لعب',
                                textAlign: TextAlign.center,
                                style: AppType.title.copyWith(color: t.ink)),
                            const SizedBox(height: AppSpace.sm),
                            Text('اسحب للأسفل للتحديث',
                                textAlign: TextAlign.center,
                                style:
                                    AppType.body.copyWith(color: t.inkFaint)),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                              AppSpace.lg,
                              AppSpace.lg,
                              AppSpace.lg,
                              AppSpace.xl +
                                  MediaQuery.paddingOf(context).bottom),
                          itemCount: scores.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpace.sm),
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpace.xs),
                                child: Text(
                                    '${scores.length} طالب لعبوا — أفضل نتيجة لكل واحد',
                                    style: AppType.body
                                        .copyWith(color: t.inkSoft)),
                              );
                            }
                            return _Row(rank: i, score: scores[i - 1]);
                          },
                        ),
                ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final GameScore score;
  const _Row({required this.rank, required this.score});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const medals = ['🥇', '🥈', '🥉'];
    final top = rank <= 3;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md + 2, vertical: AppSpace.md),
      lineColor: top ? t.chalk.withValues(alpha: 0.7) : null,
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text(top ? medals[rank - 1] : '$rank',
              textAlign: TextAlign.center,
              style: top
                  ? const TextStyle(fontSize: 24)
                  : AppType.label.copyWith(color: t.inkFaint)),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(score.name.isEmpty ? score.code : score.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: t.ink)),
              Text(
                  '${score.correct} صح من ${score.total} · '
                  '${(score.timeMs / 1000).round()} ث · ${score.code}',
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ],
          ),
        ),
        Text('${score.score}', style: AppType.figure.copyWith(color: t.brand)),
      ]),
    );
  }
}
