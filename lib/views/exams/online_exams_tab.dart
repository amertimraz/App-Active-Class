// lib/views/exams/online_exams_tab.dart
//
// spec 016 — تبويب "امتحان إلكتروني" داخل شاشة الامتحانات.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/views/exams/online_exam_editor_page.dart';
import 'package:active_class/views/exams/online_exam_results_page.dart';
import 'package:active_class/utils/helpers.dart';

// ─── ألوان الحالة ────────────────────────────────────────────────────────────
Color _statusColor(OnlineExamStatus? s) {
  switch (s) {
    case OnlineExamStatus.published:
      return const Color(0xFF10B981); // إيميرالد
    case OnlineExamStatus.stopped:
      return const Color(0xFFF59E0B); // أمبر
    case OnlineExamStatus.removed:
      return const Color(0xFF94A3B8); // سلايت
    default:
      return const Color(0xFF6366F1); // إنديجو (مسودّة)
  }
}

IconData _statusIcon(OnlineExamStatus? s) {
  switch (s) {
    case OnlineExamStatus.published:
      return Icons.wifi_tethering_rounded;
    case OnlineExamStatus.stopped:
      return Icons.pause_circle_filled_rounded;
    case OnlineExamStatus.removed:
      return Icons.cloud_off_rounded;
    default:
      return Icons.edit_note_rounded;
  }
}

class OnlineExamsTab extends StatefulWidget {
  const OnlineExamsTab({super.key});

  @override
  State<OnlineExamsTab> createState() => _OnlineExamsTabState();
}

class _OnlineExamsTabState extends State<OnlineExamsTab> {
  final _ec = Get.find<ExamController>();
  final _gc = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());

  final Map<int, int> _subCounts = {};
  final Map<int, int> _qCounts = {};
  Timer? _ticker;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _worker = ever(_ec.exams, (_) => _loadCounts());
    // تحديث النصوص الزمنية (يفتح بعد كذا / يقفل بعد كذا) كل 30 ثانية
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _worker?.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final online = _ec.onlineExams;
    for (final e in online) {
      if (e.id == null) continue;
      _qCounts[e.id!] = (await _ec.getQuestions(e.id!)).length;
      if (e.onlineStatus != OnlineExamStatus.draft) {
        _subCounts[e.id!] = (await _ec.getSubmissions(e.id!)).length;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // ignore: unnecessary_statements
      LicenseController.to.parentPortalRecheckTick.value;
      // ignore: unnecessary_statements
      LicenseController.to.licenseVerifiedTick.value;
      if (!LicenseController.to.parentPortalActiveNow) {
        return const _LockedState();
      }
      final exams = _ec.onlineExams;
      if (exams.isEmpty) return const _EmptyState();

      final drafts =
          exams.where((e) => e.onlineStatus == OnlineExamStatus.draft).length;
      final live =
          exams.where((e) => e.onlineStatus == OnlineExamStatus.published).length;
      final ended = exams
          .where((e) =>
              e.onlineStatus == OnlineExamStatus.stopped ||
              e.onlineStatus == OnlineExamStatus.removed)
          .length;
      final totalSubs =
          _subCounts.values.fold<int>(0, (s, v) => s + v);

      return RefreshIndicator(
        onRefresh: () async {
          await _ec.loadExams();
          await _loadCounts();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _StatsHeader(
                drafts: drafts, live: live, ended: ended, submissions: totalSubs),
            const SizedBox(height: 16),
            ...exams.map((e) => _OnlineExamCard(
                  exam: e,
                  groups: _gc.groups.toList(),
                  submissions: _subCounts[e.id] ?? 0,
                  questionCount: _qCounts[e.id] ?? 0,
                  onChanged: () async {
                    await _ec.loadExams();
                    await _loadCounts();
                  },
                )),
          ],
        ),
      );
    });
  }
}

// ─── ترويسة الإحصائيات ───────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  final int drafts, live, ended, submissions;
  const _StatsHeader(
      {required this.drafts,
      required this.live,
      required this.ended,
      required this.submissions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        _stat('$live', 'منشور\nالآن', Icons.wifi_tethering_rounded),
        _divider(),
        _stat('$drafts', 'مسودّة', Icons.edit_note_rounded),
        _divider(),
        _stat('$ended', 'منتهي', Icons.flag_rounded),
        _divider(),
        _stat('$submissions', 'إجمالي\nالتسليمات', Icons.how_to_reg_rounded),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 42, color: Colors.white.withValues(alpha: 0.18));

  Widget _stat(String v, String l, IconData i) => Expanded(
        child: Column(children: [
          Icon(i, size: 17, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 5),
          Text(v,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.05)),
          Text(l,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9.5,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.78))),
        ]),
      );
}

// ─── بطاقة امتحان إلكتروني ───────────────────────────────────────────────────
class _OnlineExamCard extends StatelessWidget {
  final Exam exam;
  final List<Group> groups;
  final int submissions;
  final int questionCount;
  final Future<void> Function() onChanged;

  const _OnlineExamCard({
    required this.exam,
    required this.groups,
    required this.submissions,
    required this.questionCount,
    required this.onChanged,
  });

  ExamController get _ec => Get.find<ExamController>();

  Future<void> _run(Future<String?> Function() action, String okMsg) async {
    final err = await action();
    if (err == null) {
      ToastHelper.success(okMsg);
    } else if (err.startsWith('__WARN__')) {
      ToastHelper.info(err.replaceFirst('__WARN__ ', ''));
    } else {
      ToastHelper.error(err);
    }
    await onChanged();
  }

  void _confirm(BuildContext context,
      {required String title,
      required String body,
      required Color color,
      required IconData icon,
      required VoidCallback onYes}) {
    Get.dialog(AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ]),
      content: Text(body,
          style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 13, height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () {
              Get.back();
              onYes();
            },
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final status = exam.onlineStatus ?? OnlineExamStatus.draft;
    final c = _statusColor(status);
    final fmtShort = DateFormat('d MMM · h:mm a', 'ar');

    final opens = exam.opensAt?.toLocal();
    final closes = exam.closesAt?.toLocal();
    final now = DateTime.now();

    // نص الحالة الزمنية + نسبة تقدّم النافذة
    String timeText = 'بدون توقيت محدّد';
    double? windowProgress;
    if (opens != null && closes != null) {
      if (status == OnlineExamStatus.stopped) {
        timeText = 'موقوف — كان مقرّرًا لـ ${fmtShort.format(opens)}';
      } else if (now.isBefore(opens)) {
        timeText = 'يفتح ${_relative(opens, now)} · ${fmtShort.format(opens)}';
      } else if (now.isBefore(closes)) {
        timeText = 'مفتوح الآن · يقفل ${_relative(closes, now)}';
        final total = closes.difference(opens).inSeconds;
        windowProgress =
            total > 0 ? now.difference(opens).inSeconds / total : null;
      } else {
        timeText = 'انتهى · ${fmtShort.format(closes)}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.22)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: c.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط لوني علوي
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [c, c.withValues(alpha: 0.55)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان + الحالة
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_statusIcon(status), color: c, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(exam.name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                  ),
                  _pill(status.label, c),
                ]),
                const SizedBox(height: 12),

                // نص الحالة الزمنية
                Row(children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(timeText,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ),
                ]),
                if (windowProgress != null) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: windowProgress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: c.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // شرائح المعلومات
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _InfoChip(Icons.help_outline_rounded,
                      '$questionCount سؤال', const Color(0xFF6366F1)),
                  _InfoChip(Icons.grade_rounded,
                      'من ${FormatHelper.formatGrade(exam.maxGrade)}',
                      const Color(0xFF8B5CF6)),
                  if (exam.durationMinutes != null)
                    _InfoChip(Icons.timer_outlined,
                        '${exam.durationMinutes} دقيقة', const Color(0xFF0EA5E9)),
                  if (status != OnlineExamStatus.draft)
                    _InfoChip(Icons.how_to_reg_rounded,
                        '$submissions تسليم', const Color(0xFF10B981)),
                ]),

                // المجموعات
                if (exam.groupIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: groups
                        .where((g) => exam.groupIds.contains(g.id))
                        .map<Widget>((g) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(g.color ?? 0xFF4F46E5)
                                    .withValues(alpha: isDark ? 0.20 : 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.groups_rounded,
                                    size: 11,
                                    color: Color(g.color ?? 0xFF4F46E5)),
                                const SizedBox(width: 4),
                                Text(g.name,
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(g.color ?? 0xFF4F46E5))),
                              ]),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 13),
                Divider(
                    height: 1, color: cs.onSurface.withValues(alpha: 0.07)),
                const SizedBox(height: 11),

                // الأزرار
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _actions(context, status, c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: c)),
      );

  List<Widget> _actions(
      BuildContext context, OnlineExamStatus status, Color c) {
    switch (status) {
      case OnlineExamStatus.draft:
        return [
          _btn('تعديل وإكمال', Icons.edit_outlined, () async {
            await Get.to(() => OnlineExamEditorPage(existing: exam));
            await onChanged();
          }, primary: true),
        ];
      case OnlineExamStatus.published:
      case OnlineExamStatus.stopped:
        return [
          _btn('النتائج', Icons.assignment_turned_in_outlined, () async {
            await Get.to(() => OnlineExamResultsPage(exam: exam));
            await onChanged();
          }, primary: true),
          _btn('رابط الطلاب', Icons.link_rounded, () => _showLink(context)),
          _btn('تعديل الامتحان', Icons.tune_rounded, () async {
            final res = await showDialog<_Schedule>(
              context: context,
              builder: (_) => _RescheduleDialog(exam: exam),
            );
            if (res == null) return;
            await _run(
                () => _ec.rescheduleOnlineExam(exam.id!,
                    opensAt: res.opensAt,
                    closesAt: res.closesAt,
                    durationMinutes: res.duration,
                    name: res.name),
                'اتحفظ التعديل');
          }),
          if (status == OnlineExamStatus.published)
            _btn('إيقاف الآن', Icons.stop_circle_outlined, () {
              _confirm(context,
                  title: 'إيقاف الامتحان',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.pause_circle_filled_rounded,
                  body:
                      'الطلاب اللي ما بدأوش مش هيقدروا يدخلوا. اللي بدأوا يقدروا يكمّلوا ويسلّموا.',
                  onYes: () => _run(
                      () => _ec.stopOnlineExam(exam.id!), 'تم الإيقاف'));
            }),
          _btn('إلغاء النشر', Icons.unpublished_outlined, () {
            _confirm(context,
                title: 'إلغاء النشر',
                color: const Color(0xFF6366F1),
                icon: Icons.unpublished_outlined,
                body:
                    'هيتشال من الويب وترجع مسودّة تقدر تعدّل أسئلتها. التسليمات الحالية تفضل محفوظة.',
                onYes: () => _run(
                    () => _ec.unpublishOnlineExam(exam.id!), 'اترجع مسودّة'));
          }),
          _btn('حذف من الويب', Icons.delete_outline, () {
            _confirm(context,
                title: 'حذف من الويب',
                color: const Color(0xFFEF4444),
                icon: Icons.delete_outline,
                body:
                    'هيتمسح الامتحان وتسليماته من السحابة نهائيًا. الدرجات المعتمَدة والأسئلة تفضل في التطبيق.',
                onYes: () => _run(
                    () => _ec.removeOnlineExamFromWeb(exam.id!),
                    'اتحذف من الويب'));
          }),
        ];
      case OnlineExamStatus.removed:
        return [
          _btn('النتائج', Icons.assignment_turned_in_outlined, () async {
            await Get.to(() => OnlineExamResultsPage(exam: exam));
            await onChanged();
          }),
        ];
    }
  }

  // رابط الطلاب — نفس الرابط لكل امتحانات المدرس الإلكترونية (مشتق من
  // slug المدرس). الطالب يفتحه ويشوف الامتحانات المتاحة لكوده.
  Future<void> _showLink(BuildContext context) async {
    final slug = await ParentPortalService().ensureSlug();
    final link = 'active-class.online/exam/$slug';
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.link_rounded, size: 30, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            const Text('رابط دخول الطلاب',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 4),
            const Text('نفس الرابط لكل امتحاناتك الإلكترونية — الطالب يدخل بكوده',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(link,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'https://$link'));
                    ToastHelper.success('اتنسخ');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('نسخ',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Share.share('https://$link',
                      subject: 'رابط الامتحان الإلكتروني'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text('مشاركة',
                      style: TextStyle(fontFamily: 'Cairo')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap,
      {bool primary = false}) {
    return primary
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: Icon(icon, size: 15),
            label: Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: Icon(icon, size: 15),
            label: Text(label,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          );
  }
}

String _relative(DateTime target, DateTime now) {
  final diff = target.difference(now);
  final mins = diff.inMinutes;
  if (mins < 1) return 'خلال لحظات';
  if (mins < 60) return 'بعد $mins دقيقة';
  final hrs = diff.inHours;
  if (hrs < 24) return 'بعد $hrs ساعة';
  return 'بعد ${diff.inDays} يوم';
}

// ─── شريحة معلومة ────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      );
}

// ─── حالة مقفولة (بدون بوابة أهالي) ─────────────────────────────────────────
class _LockedState extends StatelessWidget {
  const _LockedState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  const Color(0xFF7C3AED).withValues(alpha: 0.15),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded,
                  size: 44, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 18),
            const Text('الامتحانات الإلكترونية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'الميزة دي ضمن إضافة بوابة متابعة أولياء الأمور.\nفعّلها عشان الطلاب يحلّوا الامتحان من موبايلهم والتصحيح يتم تلقائي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  height: 1.7,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── حالة فاضية ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.quiz_rounded,
                  size: 44, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            Text('مفيش امتحانات إلكترونية لسه',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 6),
            Text(
              'اضغط "امتحان إلكتروني جديد" تحت — أضف أسئلة صح/خطأ واختيار من متعدد،\nحدّد الميعاد، وانشر الرابط للطلاب.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.7,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── حوار تعديل الميعاد ─────────────────────────────────────────────────────
class _Schedule {
  final DateTime opensAt;
  final DateTime closesAt;
  final int duration;
  final String name;
  const _Schedule(this.opensAt, this.closesAt, this.duration, this.name);
}

class _RescheduleDialog extends StatefulWidget {
  final Exam exam;
  const _RescheduleDialog({required this.exam});

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _opens;
  late DateTime _closes;
  late int _duration;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _opens = widget.exam.opensAt?.toLocal() ?? now;
    _closes =
        widget.exam.closesAt?.toLocal() ?? now.add(const Duration(hours: 1));
    _duration = widget.exam.durationMinutes ?? 30;
    _nameCtrl = TextEditingController(text: widget.exam.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(bool opens) async {
    final base = opens ? _opens : _closes;
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return;
    setState(() {
      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (opens) {
        _opens = dt;
      } else {
        _closes = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · h:mm a', 'ar');
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.schedule_rounded,
              color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('تعديل الامتحان',
            style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'اسم الامتحان',
              labelStyle: TextStyle(fontFamily: 'Cairo'),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _opens = now;
                if (!_closes.isAfter(now.add(Duration(minutes: _duration)))) {
                  _closes = now.add(Duration(minutes: _duration + 30));
                }
              });
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('تشغيل الآن',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          _rowPick('يفتح', fmt.format(_opens), () => _pick(true), cs),
          const SizedBox(height: 8),
          _rowPick('يقفل', fmt.format(_closes), () => _pick(false), cs),
          const SizedBox(height: 8),
          Row(children: [
            Text('مدة الحل (دقيقة):',
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: cs.onSurface)),
            const Spacer(),
            SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: '$_duration',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) => _duration = int.tryParse(v) ?? _duration,
              ),
            ),
          ]),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context,
                _Schedule(_opens, _closes, _duration, _nameCtrl.text.trim())),
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    );
  }

  Widget _rowPick(
      String label, String value, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        ),
        child: Row(children: [
          Text('$label:',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor)),
          const SizedBox(width: 4),
          const Icon(Icons.edit_calendar_rounded,
              size: 15, color: AppTheme.primaryColor),
        ]),
      ),
    );
  }
}
