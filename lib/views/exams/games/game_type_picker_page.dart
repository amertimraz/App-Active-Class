// lib/views/exams/games/game_type_picker_page.dart
//
// أول خطوة في «لعبة جديدة»: كروت ملوّنة بشكل كل لعبة. المدرس يختار الشكل،
// وبعدها بيكمّل في المحرّر (الاسم، الأسئلة من البنك أو الامتحان، الوقت…).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/views/exams/games/online_game_editor_page.dart';
import 'package:active_class/widgets/app_chrome.dart';

/// ألوان وأيقونة كل لعبة (مشتركة مع هيدر المحرّر).
List<Color> gameTypeGradient(OnlineGameType type) => switch (type) {
      OnlineGameType.race => const [Color(0xFF6D28D9), Color(0xFFDB2777)],
      OnlineGameType.trueFalse => const [Color(0xFF0369A1), Color(0xFF047857)],
      OnlineGameType.balloons => const [Color(0xFFC2410C), Color(0xFFBE123C)],
      OnlineGameType.ladder => const [Color(0xFF1E3A8A), Color(0xFF9A6A12)],
    };

IconData gameTypeIcon(OnlineGameType type) => switch (type) {
      OnlineGameType.race => Icons.rocket_launch_rounded,
      OnlineGameType.trueFalse => Icons.balance_rounded,
      OnlineGameType.balloons => Icons.bubble_chart_rounded,
      OnlineGameType.ladder => Icons.stairs_rounded,
    };

class GameTypePickerPage extends StatelessWidget {
  const GameTypePickerPage({super.key});

  Future<void> _pick(OnlineGameType type) async {
    // المحرّر بيتفتح فوق الكروت (الرجوع منه يرجّع للاختيار)، ولما يرجّع
    // رابط بعد النشر بنقفل الكروت ونمرّر الرابط لقائمة الألعاب.
    final link = await Get.to<String>(() => OnlineGameEditorPage(type: type));
    if (link != null) Get.back(result: link);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'لعبة جديدة'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
            AppSpace.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('اختار شكل اللعبة', style: AppType.title.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.xs),
          Text('بعدها تختار الأسئلة من البنك أو من امتحان إلكتروني.',
              style: AppType.body.copyWith(color: t.inkSoft)),
          const SizedBox(height: AppSpace.lg),
          // كروت في صفوف من اتنين، وكل صف بنفس الارتفاع (أطولهم يحدد).
          for (var r = 0; r < OnlineGameType.values.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = r;
                        i < r + 2 && i < OnlineGameType.values.length;
                        i++) ...[
                      if (i > r) const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _GameCard(
                          type: OnlineGameType.values[i],
                          onTap: () => _pick(OnlineGameType.values[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final OnlineGameType type;
  final VoidCallback onTap;
  const _GameCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = gameTypeGradient(type);
    return Semantics(
      button: true,
      label: '${type.title}. ${type.description}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.board),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(AppRadius.board),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.board),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.board),
              child: Stack(
                children: [
                  // دائرة زخرفية خفيفة في الركن
                  PositionedDirectional(
                    top: -34,
                    end: -34,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(gameTypeIcon(type),
                              size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Text(type.title,
                            style: AppType.title
                                .copyWith(fontSize: 19, color: Colors.white)),
                        const SizedBox(height: AppSpace.xs),
                        Text(type.description,
                            style: AppType.caption.copyWith(
                                height: 1.5,
                                color: Colors.white.withValues(alpha: 0.9))),
                        const SizedBox(height: AppSpace.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm + 2, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text('${type.defaultSeconds} ث لكل سؤال',
                              style: AppType.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
