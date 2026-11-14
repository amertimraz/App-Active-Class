// lib/widgets/whats_new_dialog.dart
//
// نافذة «الجديد في هذا التحديث»: بتظهر مرة واحدة بعد ما التطبيق يتحدّث لإصدار
// ليه ملاحظات (lib/utils/whats_new.dart). أول تثبيت بيسجّل الإصدار من غير نافذة.
// بتتخطّى (من غير ما تعتبر إنها اتشافت) لو فيه شاشة/حوار فوق الرئيسية.
//
// التصميم: رأس «سبورة» فيه عنوان وشارة الإصدار بلون الطباشير، تحته قايمة
// ميزات (أيقونة معبّرة + عنوان + شرح) بفواصل خفيفة، وزر واحد أساسي تحت.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/whats_new.dart';

const _kSeenVersion = 'whats_new_seen_version';

Future<void> maybeShowWhatsNew(BuildContext context) async {
  try {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final prefs = await SharedPreferences.getInstance();
    // المدرس اللي بيتحدّث من إصدار قبل الميزة دي ما عندوش إصدار متسجّل، لكن
    // عدّاد التشغيل (نافذة التقييم) بيقول إنه مش تثبيت جديد → نعتبره «0.0.0».
    var lastSeen = prefs.getString(_kSeenVersion);
    if (lastSeen == null && (prefs.getInt('rate_launches') ?? 0) > 1) {
      lastSeen = '0.0.0';
    }
    final notes = notesToShow(lastSeen: lastSeen, current: current);

    if (notes.isEmpty) {
      // أول تثبيت أو إصدار بلا ملاحظات: سجّل الإصدار الحالي وخلاص.
      if (lastSeen == null || compareVersions(current, lastSeen) > 0) {
        await prefs.setString(_kSeenVersion, current);
      }
      return;
    }
    if (!context.mounted) return;
    await prefs.setString(_kSeenVersion, current);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => WhatsNewDialog(version: current, notes: notes),
    );
  } catch (e) {
    debugPrint('maybeShowWhatsNew: $e');
  }
}

/// فتح النافذة يدويًا (من «حول التطبيق») على آخر إصدار له ملاحظات، بغض النظر
/// عن اللي اتشاف قبل كده.
Future<void> showWhatsNewNow(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  final shown = [
    for (final n in kReleaseNotes)
      if (compareVersions(n.version, info.version) <= 0) n
  ];
  if (!context.mounted) return;
  final notes = shown.isEmpty ? [kReleaseNotes.first] : [shown.first];
  await showDialog<void>(
    context: context,
    builder: (ctx) =>
        WhatsNewDialog(version: notes.first.version, notes: notes),
  );
}

/// أيقونة كل ميزة (مفاتيح ReleaseItem.icon).
IconData whatsNewIcon(String key) => switch (key) {
      'chat' => Icons.chat_rounded,
      'reports' => Icons.insights_rounded,
      'income' => Icons.payments_rounded,
      'exam' => Icons.document_scanner_rounded,
      'delete' => Icons.delete_sweep_rounded,
      'settings' => Icons.tune_rounded,
      _ => Icons.auto_awesome_rounded,
    };

class WhatsNewDialog extends StatelessWidget {
  final String version;
  final List<ReleaseNote> notes;
  const WhatsNewDialog({super.key, required this.version, required this.notes});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    return Dialog(
      backgroundColor: t.surface,
      clipBehavior: Clip.antiAlias,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.board),
        side: BorderSide(color: t.line),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var n = 0; n < notes.length; n++) ...[
                      if (notes.length > 1)
                        Padding(
                          padding: EdgeInsets.only(
                              top: n == 0 ? AppSpace.sm : AppSpace.lg,
                              bottom: AppSpace.xs),
                          child: Text('إصدار ${notes[n].version}',
                              style:
                                  AppType.label.copyWith(color: t.inkSoft)),
                        ),
                      for (var i = 0; i < notes[n].items.length; i++) ...[
                        _item(t, notes[n].items[i]),
                        if (i != notes[n].items.length - 1)
                          Divider(height: 1, thickness: 1, color: t.line),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
                child: const Text('تمام، يلا نبدأ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // رأس السبورة: العنوان + شارة الإصدار بلون الطباشير.
  Widget _header(AppTokens t) {
    return Semantics(
      header: true,
      label: 'الجديد في هذا التحديث، الإصدار $version',
      child: Container(
        color: t.board,
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.boardLine,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: t.chalk, size: 26),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الجديد في هذا التحديث',
                    style: AppType.title.copyWith(color: t.boardInk)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: t.chalk),
                  ),
                  child: Text('الإصدار $version',
                      style: AppType.caption.copyWith(color: t.chalk)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _item(AppTokens t, ReleaseItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.rosterTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(whatsNewIcon(item.icon), color: t.rosterInk, size: 22),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: 2),
              Text(item.body,
                  style: AppType.body
                      .copyWith(color: t.inkSoft, height: 1.5, fontSize: 14)),
            ],
          ),
        ),
      ]),
    );
  }
}
