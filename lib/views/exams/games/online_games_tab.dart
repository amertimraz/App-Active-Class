// lib/views/exams/games/online_games_tab.dart
//
// تبويب «ألعاب» داخل شاشة الامتحانات: قائمة الألعاب المنشورة (رابط +
// نتائج + قفل/فتح + حذف). الألعاب محفوظة على السحابة بس (Firestore) —
// مفيش جدول محلي ولا مزامنة فريق.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/services/online_game_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/exams/games/game_leaderboard_page.dart';
import 'package:active_class/views/exams/games/online_game_editor_page.dart';
import 'package:active_class/widgets/app_panel.dart';

class OnlineGamesTab extends StatefulWidget {
  const OnlineGamesTab({super.key});

  @override
  State<OnlineGamesTab> createState() => OnlineGamesTabState();
}

class OnlineGamesTabState extends State<OnlineGamesTab> {
  final _service = OnlineGameService();
  List<OnlineGame>? _games;
  String? _slug;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// بيستدعيه زرار «لعبة جديدة» بعد الرجوع من المحرّر.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slug = await _service.slug();
      final games = await _service.listGames();
      if (!mounted) return;
      setState(() {
        _slug = slug;
        _games = games;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل الألعاب — تأكد من اتصالك بالإنترنت';
        _loading = false;
      });
    }
  }

  Future<void> _toggleOpen(OnlineGame g) async {
    try {
      await _service.setOpen(g.id, !g.open);
      ToastHelper.success(g.open ? 'اتقفلت اللعبة' : 'اتفتحت اللعبة');
      await reload();
    } catch (_) {
      ToastHelper.error('تعذّر التعديل — حاول تاني');
    }
  }

  Future<void> _delete(OnlineGame g) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('حذف اللعبة؟'),
      content: Text('هتتمسح «${g.title}» ومعاها كل نتايج الطلاب. الرابط '
          'هيبطّل يشتغل.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('حذف', style: TextStyle(color: context.tokens.danger))),
      ],
    ));
    if (ok != true) return;
    try {
      await _service.delete(g.id);
      ToastHelper.success('اتمسحت اللعبة');
      await reload();
    } catch (_) {
      ToastHelper.error('تعذّر الحذف — حاول تاني');
    }
  }

  Future<void> _showLink(OnlineGame g) async {
    final slug = _slug;
    if (slug == null) return;
    final link = OnlineGameService.linkFor(slug, g.id);
    final t = context.tokens;
    await showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.link_rounded, size: 30, color: t.brand),
            const SizedBox(height: AppSpace.sm),
            Text('رابط اللعبة', style: AppType.title.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.xs),
            Text('ابعته للطلاب — بيدخلوا بكودهم وبيلعبوا من الموبايل',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: t.inkFaint)),
            const SizedBox(height: AppSpace.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: t.rosterTint,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: SelectableText(link,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: t.rosterInk)),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://$link'));
                    ToastHelper.success('اتنسخ');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Share.share('https://$link', subject: 'لعبة: ${g.title}'),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final access = TeamModeService().onlineExamAccessNow;
    if (access.locked) {
      return _Message(
        icon: Icons.lock_outline_rounded,
        title: 'الألعاب مقفولة',
        body: 'الألعاب جزء من الامتحان الإلكتروني — فعّل اشتراك بوابة '
            'أولياء الأمور عشان تشتغل.',
      );
    }
    if (_loading && _games == null) {
      return Center(child: CircularProgressIndicator(color: t.brand));
    }
    if (_error != null && _games == null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'مفيش اتصال',
        body: _error!,
        action: FilledButton(onPressed: reload, child: const Text('حاول تاني')),
      );
    }
    final games = _games ?? const <OnlineGame>[];
    if (games.isEmpty) {
      return _Message(
        icon: Icons.sports_esports_rounded,
        title: 'لسه مفيش ألعاب',
        body: 'حوّل أسئلة بنك الأسئلة أو امتحان إلكتروني للعبة، وابعت '
            'الرابط للطلاب — بيلعبوا من الموبايل وأفضل نتيجة ليهم بتظهر هنا.',
        action: access.canCreate
            ? FilledButton.icon(
                onPressed: () async {
                  await Get.to(() => const OnlineGameEditorPage());
                  reload();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('لعبة جديدة'),
              )
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
            120 + MediaQuery.paddingOf(context).bottom),
        itemCount: games.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
        itemBuilder: (_, i) => _GameCard(
          game: games[i],
          canManage: access.canCreate,
          onLink: () => _showLink(games[i]),
          onResults: () => Get.to(() => GameLeaderboardPage(game: games[i])),
          onToggle: () => _toggleOpen(games[i]),
          onDelete: () => _delete(games[i]),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final OnlineGame game;
  final bool canManage;
  final VoidCallback onLink;
  final VoidCallback onResults;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _GameCard({
    required this.game,
    required this.canManage,
    required this.onLink,
    required this.onResults,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final open = game.open;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.rosterTint,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(
                  game.type == OnlineGameType.race
                      ? Icons.rocket_launch_rounded
                      : Icons.balance_rounded,
                  color: t.rosterInk,
                  size: 22),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(color: t.ink)),
                  Text(
                      '${game.type.title} · ${game.questions.length} سؤال · '
                      '${game.secondsPerQuestion} ث',
                      style: AppType.caption.copyWith(color: t.inkFaint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm + 2, vertical: 2),
              decoration: BoxDecoration(
                color: open ? t.positiveSoft : t.line,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(open ? 'مفتوحة' : 'مقفولة',
                  style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: open ? t.positive : t.inkSoft)),
            ),
          ]),
          if (game.allowedGroupNames.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('لمجموعات: ${game.allowedGroupNames.join('، ')}',
                style: AppType.caption.copyWith(color: t.inkSoft)),
          ],
          const SizedBox(height: AppSpace.md),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onLink,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('الرابط'),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onResults,
                icon: const Icon(Icons.emoji_events_rounded, size: 18),
                label: const Text('الترتيب'),
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'المزيد',
                onSelected: (v) => v == 'toggle' ? onToggle() : onDelete(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(open ? 'قفل اللعبة' : 'فتح اللعبة')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف', style: TextStyle(color: t.danger))),
                ],
              ),
          ]),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _Message(
      {required this.icon,
      required this.title,
      required this.body,
      this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: t.inkFaint),
            const SizedBox(height: AppSpace.lg),
            Text(title, style: AppType.title.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.sm),
            Text(body,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: t.inkSoft)),
            if (action != null) ...[
              const SizedBox(height: AppSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
