// lib/views/exams/online_exams_tab.dart
//
// spec 016 — تبويب "امتحان إلكتروني" داخل شاشة الامتحانات.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/views/exams/online_exam_editor_page.dart';
import 'package:active_class/views/exams/online_exam_results_page.dart';
import 'package:active_class/utils/helpers.dart';

class OnlineExamsTab extends StatelessWidget {
  const OnlineExamsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ec = Get.find<ExamController>();
    return Obx(() {
      // ignore: unused_local_variable
      final _ = LicenseController.to.parentPortalRecheckTick.value;
      if (!LicenseController.to.parentPortalActiveNow) {
        return const _LockedState();
      }
      final exams = ec.onlineExams;
      if (exams.isEmpty) {
        return const _EmptyState();
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: exams.length,
        itemBuilder: (_, i) => _OnlineExamCard(exam: exams[i]),
      );
    });
  }
}

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
            Icon(Icons.lock_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            const Text(
              'الامتحانات الإلكترونية ضمن إضافة بوابة متابعة أولياء الأمور',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text('فعّل الإضافة عشان تقدر تعمل امتحانات الطلاب يحلّوها من موبايلهم.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text('مفيش امتحانات إلكترونية لسه',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('اضغط "امتحان إلكتروني جديد" عشان تبدأ.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _OnlineExamCard extends StatelessWidget {
  final Exam exam;
  const _OnlineExamCard({required this.exam});

  ExamController get _ec => Get.find<ExamController>();

  Color _statusColor(OnlineExamStatus? s) {
    switch (s) {
      case OnlineExamStatus.published:
        return const Color(0xFF10B981);
      case OnlineExamStatus.stopped:
        return const Color(0xFFF59E0B);
      case OnlineExamStatus.removed:
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Future<void> _run(Future<String?> Function() action, String okMsg) async {
    final err = await action();
    if (err == null) {
      ToastHelper.success(okMsg);
    } else if (err.startsWith('__WARN__')) {
      ToastHelper.info(err.replaceFirst('__WARN__ ', ''));
    } else {
      ToastHelper.error(err);
    }
  }

  void _confirm(BuildContext context,
      {required String title,
      required String body,
      required VoidCallback onYes}) {
    Get.dialog(AlertDialog(
      title: Text(title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Text(body, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        FilledButton(
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
    final status = exam.onlineStatus ?? OnlineExamStatus.draft;
    final fmt = DateFormat('d MMM h:mm a', 'ar');
    final windowText = (exam.opensAt != null && exam.closesAt != null)
        ? '${fmt.format(exam.opensAt!.toLocal())}  ←  ${fmt.format(exam.closesAt!.toLocal())}'
        : 'بدون توقيت محدّد';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(exam.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status))),
              ),
            ]),
            const SizedBox(height: 6),
            Text(windowText,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
            const Divider(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _actions(context, status),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, OnlineExamStatus status) {
    switch (status) {
      case OnlineExamStatus.draft:
        return [
          _btn('تعديل', Icons.edit_outlined, () async {
            await Get.to(() => OnlineExamEditorPage(existing: exam));
            _ec.loadExams();
          }),
          _btn('نشر', Icons.publish_rounded, () async {
            await Get.to(() => OnlineExamEditorPage(existing: exam));
            _ec.loadExams();
          }, primary: true),
        ];
      case OnlineExamStatus.published:
      case OnlineExamStatus.stopped:
        return [
          _btn('النتائج', Icons.assignment_turned_in_outlined, () {
            Get.to(() => OnlineExamResultsPage(exam: exam));
          }, primary: true),
          _btn('تعديل الميعاد', Icons.schedule_rounded, () async {
            final res = await showDialog<_Schedule>(
              context: context,
              builder: (_) => _RescheduleDialog(exam: exam),
            );
            if (res == null) return;
            await _run(
                () => _ec.rescheduleOnlineExam(exam.id!,
                    opensAt: res.opensAt,
                    closesAt: res.closesAt,
                    durationMinutes: res.duration),
                'اتعدّل الميعاد');
          }),
          if (status == OnlineExamStatus.published)
            _btn('إيقاف الآن', Icons.stop_circle_outlined, () {
              _confirm(context,
                  title: 'إيقاف الامتحان',
                  body:
                      'الطلاب اللي ما بدأوش مش هيقدروا يدخلوا. اللي بدأوا يقدروا يكمّلوا.',
                  onYes: () => _run(() => _ec.stopOnlineExam(exam.id!),
                      'تم الإيقاف'));
            }),
          _btn('إلغاء النشر', Icons.unpublished_outlined, () {
            _confirm(context,
                title: 'إلغاء النشر',
                body:
                    'هيتشال من الويب. التسليمات الحالية تفضل. تقدر تعدّل وتعيد النشر.',
                onYes: () => _run(
                    () => _ec.unpublishOnlineExam(exam.id!), 'اترجع مسودّة'));
          }),
          _btn('حذف من الويب', Icons.delete_outline, () {
            _confirm(context,
                title: 'حذف من الويب',
                body:
                    'هيتمسح الامتحان وتسليماته من السحابة. الدرجات المعتمَدة والأسئلة تفضل في التطبيق.',
                onYes: () => _run(() => _ec.removeOnlineExamFromWeb(exam.id!),
                    'اتحذف من الويب'));
          }),
        ];
      case OnlineExamStatus.removed:
        return [
          _btn('النتائج', Icons.assignment_turned_in_outlined, () {
            Get.to(() => OnlineExamResultsPage(exam: exam));
          }),
        ];
    }
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap,
      {bool primary = false}) {
    return primary
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact),
            icon: Icon(icon, size: 16),
            label: Text(label,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact),
            icon: Icon(icon, size: 16),
            label: Text(label,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          );
  }
}

class _Schedule {
  final DateTime opensAt;
  final DateTime closesAt;
  final int duration;
  const _Schedule(this.opensAt, this.closesAt, this.duration);
}

/// حوار تعديل ميعاد امتحان منشور — تأجيل أو "تشغيل الآن".
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _opens = widget.exam.opensAt?.toLocal() ?? now;
    _closes = widget.exam.closesAt?.toLocal() ?? now.add(const Duration(hours: 1));
    _duration = widget.exam.durationMinutes ?? 30;
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
    return AlertDialog(
      title: const Text('تعديل الميعاد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
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
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('يفتح:',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            const Spacer(),
            TextButton(
                onPressed: () => _pick(true),
                child: Text(fmt.format(_opens),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12))),
          ]),
          Row(children: [
            const Text('يقفل:',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            const Spacer(),
            TextButton(
                onPressed: () => _pick(false),
                child: Text(fmt.format(_closes),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12))),
          ]),
          Row(children: [
            const Text('المدة (دقيقة):',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
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
            onPressed: () => Navigator.pop(
                context, _Schedule(_opens, _closes, _duration)),
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    );
  }
}
