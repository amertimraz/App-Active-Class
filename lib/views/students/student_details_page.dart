// lib/views/students/student_details_page.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';
import 'package:active_class/widgets/remove_student_dialog.dart';
import 'package:active_class/widgets/locked_feature.dart';
import 'package:active_class/views/exams/student_exam_history_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';

// أيقونات المجموعات
const _kGroupIconMap = <String, IconData>{
  'group': Icons.groups_rounded,
  'class': Icons.class_rounded,
  'book': Icons.menu_book_rounded,
  'math': Icons.calculate_rounded,
  'science': Icons.science_rounded,
  'language': Icons.language_rounded,
  'code': Icons.code_rounded,
  'star': Icons.star_rounded,
  'music': Icons.music_note_rounded,
  'art': Icons.brush_rounded,
  'sport': Icons.sports_soccer_rounded,
  'english': Icons.translate_rounded,
};

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({super.key});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage>
    with SingleTickerProviderStateMixin {
  final AttendanceController attendanceController =
      Get.put(AttendanceController());
  final PaymentController paymentController = Get.put(PaymentController());
  final HomeworkController homeworkController = Get.put(HomeworkController());

  Student? student;
  Group? _group;
  List<Group> _groups = [];
  late TabController _tabController;
  // بيتقرا مرة واحدة بس وقت فتح الشاشة — متطابق مع باقي أماكن فحص
  // صلاحيات وضع الفريق في التطبيق (بتتحدّث بس عند إعادة الاتصال/فتح
  // التطبيق تاني، مش لحظيًا وسط الاستخدام).
  late final bool _canSeeFinancials = TeamModeService().canSeeFinancials;
  late final bool _canSeeAcademics = TeamModeService().canSeeAcademics;

  @override
  void initState() {
    super.initState();
    student = Get.arguments as Student?;
    _tabController = TabController(length: 3, vsync: this);
    if (attendanceController.attendance.isEmpty)
      attendanceController.loadAttendance();
    if (paymentController.payments.isEmpty) paymentController.loadPayments();
    if (homeworkController.homework.isEmpty) homeworkController.loadHomework();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final s = student;
    if (s == null) return;
    final results = await Future.wait([
      DatabaseService().getGroup(s.groupId),
      DatabaseService().getAllGroups(),
    ]);
    if (mounted) {
      setState(() {
        _group = results[0] as Group?;
        _groups = results[1] as List<Group>;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    final c = _group?.color;
    return c != null ? Color(c) : AppTheme.primaryColor;
  }

  Future<void> _shareMonthlyReport(Student s) async {
    final rawPhone = s.guardianPhone?.trim() ?? '';
    if (rawPhone.isEmpty) {
      ToastHelper.info('أضف رقم ولي الأمر أولاً');
      return;
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final atts = attendanceController.attendance
        .where((a) =>
            a.studentId == s.id &&
            !a.date.isBefore(start) &&
            !a.date.isAfter(end))
        .toList();
    final pays = paymentController.payments
        .where((p) =>
            p.studentId == s.id &&
            !p.date.isBefore(start) &&
            !p.date.isAfter(end))
        .toList();
    final hw = homeworkController.homework
        .where((h) =>
            h.studentId == s.id &&
            !h.date.isBefore(start) &&
            !h.date.isAfter(end))
        .toList();

    final present = atts.where((a) => a.status == ATTENDANCE_PRESENT).length;
    final absent = atts.where((a) => a.status == ATTENDANCE_ABSENT).length;
    final total = present + absent;
    final percent = total == 0 ? 0.0 : (present / total) * 100.0;
    final totalPaid = pays.fold<double>(0.0, (sum, p) => sum + p.amount);
    final homeworkDone = hw.where((h) => h.status == HOMEWORK_DONE).length;
    final homeworkNotDone =
        hw.where((h) => h.status == HOMEWORK_NOT_DONE).length;
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(start);
    final groupName = _group?.name ?? '-';

    final attsSorted = List.of(atts)..sort((a, b) => b.date.compareTo(a.date));
    final paysSorted = List.of(pays)..sort((a, b) => b.date.compareTo(a.date));
    final hwSorted = List.of(hw)..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer()
      ..writeln('🧾 تقرير الشهر: $monthLabel')
      ..writeln('👤 الاسم: ${s.name}')
      ..writeln('🆔 الكود: ${s.code}')
      ..writeln('👥 المجموعة: $groupName')
      ..writeln(
          '📅 بداية الحضور: ${FormatHelper.formatDate(s.attendanceStart ?? s.createdAt)}')
      ..writeln('')
      ..writeln(
          '📊 الحضور: ✅ حاضر $present • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%');

    if (attsSorted.isNotEmpty) {
      buffer.writeln('\n📅 سجلات الحضور:');
      for (final a in attsSorted.take(10)) {
        buffer.writeln(
            '• ${DateFormat('yyyy-MM-dd').format(a.date)} — ${a.status == ATTENDANCE_PRESENT ? '✅ حاضر' : '❌ غياب'}');
      }
      if (attsSorted.length > 10)
        buffer.writeln('• … ${attsSorted.length - 10} سجلات إضافية');
    }

    if (hwSorted.isNotEmpty) {
      buffer.writeln(
          '\n📖 الواجب: عمل $homeworkDone • لم يعمل $homeworkNotDone');
      for (final h in hwSorted.take(10)) {
        buffer.writeln(
            '• ${DateFormat('yyyy-MM-dd').format(h.date)} — ${h.status == HOMEWORK_DONE ? '📗 عمل' : '📙 لم يعمل'}');
      }
      if (hwSorted.length > 10)
        buffer.writeln('• … ${hwSorted.length - 10} سجلات إضافية');
    }

    if (_canSeeFinancials) {
      buffer.writeln(
          '\n💰 المدفوعات: إجمالي ${FormatHelper.formatCurrency(totalPaid)}');
      for (final p in paysSorted) {
        buffer.writeln(
            '• ${DateFormat('yyyy-MM-dd HH:mm').format(p.date)} — ${FormatHelper.formatCurrency(p.amount)}');
      }
    }

    // لو معندوش صلاحية يشوف الامتحانات، مش هيقدر يبعت تقرير فيه
    // درجات الطالب حتى لو عن طريق واتساب — نفس القيد اللي على الشاشة.
    final examsMonth = _canSeeAcademics
        ? ((await DatabaseService().getStudentExamHistory(s.id!))
                .where((r) =>
                    !r.examDate.isBefore(start) && !r.examDate.isAfter(end))
                .toList()
              ..sort((a, b) => b.examDate.compareTo(a.examDate)))
        : <StudentExamRecord>[];
    if (examsMonth.isNotEmpty) {
      buffer.writeln('\n📝 الامتحانات:');
      for (final r in examsMonth) {
        final dateStr = DateFormat('yyyy-MM-dd').format(r.examDate);
        if (r.isAbsent) {
          buffer.writeln('• $dateStr — ${r.examName}: غائب');
        } else if (r.grade != null) {
          buffer.writeln(
              '• $dateStr — ${r.examName}: ${FormatHelper.formatGrade(r.grade!)}/${r.maxGrade.toStringAsFixed(0)} (${r.category.label})');
        } else {
          buffer.writeln('• $dateStr — ${r.examName}: لم تُدخل الدرجة بعد');
        }
      }
    }

    final settings = Get.find<SettingsController>();
    final tName = settings.teacherFullName.value.trim();
    final tSpec = settings.teacherSpecialization.value.trim();
    if (tName.isNotEmpty || tSpec.isNotEmpty) {
      buffer
        ..writeln('\n👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
        ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
    }
    buffer.writeln('\nتم الإرسال من تطبيق Active Class');

    String normalize(String input, String defaultDial) {
      var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
      if (p.startsWith('+')) p = p.substring(1);
      if (p.startsWith('00')) p = p.substring(2);
      if (p.startsWith(defaultDial)) return p;
      if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
      return defaultDial + p.replaceFirst(RegExp(r'^0+'), '');
    }

    final phone = normalize(rawPhone, settings.countryDial.value);
    final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ─── حذف الطالب (أرشفة / حذف نهائي) ──────────────────────────────────────
  void _confirmRemove(Student s) {
    if (s.id == null) return;
    // نمسك الـNavigator بتاع الصفحة قبل أي await — استخدام context مباشرة
    // بعده بيولّد تحذير use_build_context_synchronously.
    final pageNavigator = Navigator.of(context);
    // الصفحة دي ممكن توصلها من مسارات معملتش Get.put(StudentController())
    // قبلها خالص (زي بحث الصفحة الرئيسية) — لازم isRegistered بدل find
    // المباشر، وإلا هترمي استثناء.
    final studentCtrl = Get.isRegistered<StudentController>()
        ? Get.find<StudentController>()
        : Get.put(StudentController());
    showRemoveStudentDialog(
      context,
      student: s,
      canDelete: TeamModeService().canDeleteStudentsNow,
      onArchive: () => studentCtrl.archiveStudent(s.id!),
      onDeletePermanently: () => studentCtrl.deleteStudent(s.id!),
      onRemoved: () => pageNavigator.pop(),
    );
  }

  // ─── تعديل الطالب ────────────────────────────────────────────────────────
  Future<void> _editStudent(Student s) async {
    final updated = await showEditStudentSheet(
      context,
      student: s,
      accentColor: _accentColor,
      groups: _groups,
    );
    if (updated != null && mounted) {
      setState(() => student = updated);
      _loadGroup();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = student;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: const Center(child: Text('لم يتم العثور على بيانات الطالب')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _accentColor;
    final initials = s.name.trim().isNotEmpty ? s.name.trim()[0] : '؟';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1520) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تعديل بيانات الطالب',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _editStudent(s),
          ),
          IconButton(
            tooltip: 'عرض QR',
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: () => _showQRDialog(context, s),
          ),
          if (!s.isArchived)
            IconButton(
              tooltip: 'حذف الطالب',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmRemove(s),
            ),
        ],
      ),
      body: Obx(() {
        final studentAtts = attendanceController.attendance
            .where((a) => a.studentId == s.id)
            .toList();
        final studentPays = paymentController.payments
            .where((p) => p.studentId == s.id)
            .toList();
        final studentHomework = homeworkController.homework
            .where((h) => h.studentId == s.id)
            .toList();
        final presentCount =
            studentAtts.where((a) => a.status == ATTENDANCE_PRESENT).length;
        final absentCount =
            studentAtts.where((a) => a.status == ATTENDANCE_ABSENT).length;
        final attRate = studentAtts.isEmpty
            ? 0.0
            : (presentCount / studentAtts.length) * 100;
        final totalPaid =
            studentPays.fold<double>(0.0, (sum, p) => sum + p.amount);
        final accumulatedDebt = PricingHelper.accumulatedDebt(
          student: s,
          group: _group,
          allAttendance: studentAtts,
          payments: studentPays,
          siblingGroupMembers: Get.isRegistered<StudentController>()
              ? Get.find<StudentController>().students
              : null,
        );

        return NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
              child: Column(children: [
                // ── Header ─────────────────────────────────────────────
                _buildHeader(context, s, initials, primary, isDark,
                    presentCount, absentCount, attRate, totalPaid),
                // ── Actions ────────────────────────────────────────────
                _buildActions(context, s, primary),
                // ── TabBar ─────────────────────────────────────────────
                _buildTabBar(primary, isDark),
              ]),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _AttendanceTab(
                  attendance: studentAtts,
                  presentCount: presentCount,
                  absentCount: absentCount,
                  attRate: attRate,
                  accentColor: primary),
              _HomeworkTab(homework: studentHomework, accentColor: primary),
              _canSeeFinancials
                  ? _PaymentsTab(
                      payments: studentPays,
                      totalPaid: totalPaid,
                      accumulatedDebt: accumulatedDebt,
                      accentColor: primary)
                  : const LockedSectionPlaceholder(),
            ],
          ),
        );
      }),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context,
      Student s,
      String initials,
      Color primary,
      bool isDark,
      int presentCount,
      int absentCount,
      double attRate,
      double totalPaid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + اسم
            Row(children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      _HeaderBadge(Icons.qr_code_rounded, s.code),
                      if (_group != null) ...[
                        const SizedBox(width: 8),
                        _HeaderBadge(
                            _kGroupIconMap[_group!.icon ?? ''] ??
                                Icons.groups_rounded,
                            _group!.name),
                      ],
                    ]),
                  ])),
            ]),

            // معلومات إضافية
            if ((s.guardianPhone?.isNotEmpty ?? false) ||
                s.birthDate != null ||
                s.attendanceStart != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 6, children: [
                if (s.guardianPhone?.isNotEmpty ?? false)
                  _InfoChip(Icons.phone_rounded, s.guardianPhone!),
                if (s.attendanceStart != null)
                  _InfoChip(Icons.date_range_rounded,
                      'منذ ${FormatHelper.formatDate(s.attendanceStart)}'),
                if (s.birthDate != null)
                  _InfoChip(
                      Icons.cake_rounded, FormatHelper.formatDate(s.birthDate)),
              ]),
            ],

            const SizedBox(height: 16),

            // Stats
            Row(children: [
              _HeaderStat(
                  label: 'نسبة الحضور',
                  value: '${attRate.toStringAsFixed(0)}%',
                  icon: Icons.show_chart_rounded),
              const SizedBox(width: 8),
              _HeaderStat(
                  label: 'حضور',
                  value: '$presentCount',
                  icon: Icons.check_circle_rounded),
              const SizedBox(width: 8),
              _HeaderStat(
                  label: 'غياب',
                  value: '$absentCount',
                  icon: Icons.cancel_rounded),
              const SizedBox(width: 8),
              _HeaderStat(
                  label: 'مدفوع',
                  value: _canSeeFinancials
                      ? FormatHelper.formatCurrency(totalPaid)
                      : '🔒',
                  icon: Icons.payments_rounded),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context, Student s, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        _ActionChip(
          icon: Icons.chat_rounded,
          label: 'تقرير واتساب',
          color: Colors.green,
          onTap: () => _shareMonthlyReport(s),
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.qr_code_rounded,
          label: 'QR Code',
          color: primary,
          onTap: () => _showQRDialog(context, s),
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.assignment_rounded,
          label: 'الامتحانات',
          color: const Color(0xFF8B5CF6),
          locked: !_canSeeAcademics,
          onTap: () => Get.to(() =>
              StudentExamHistoryPage(studentId: s.id!, studentName: s.name)),
        ),
        if (s.guardianPhone?.isNotEmpty ?? false) ...[
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.phone_rounded,
            label: 'اتصال',
            color: Colors.blue,
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: s.guardianPhone);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ],
      ]),
    );
  }

  // ─── TabBar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2540) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: 'سجل الحضور'),
            const Tab(text: 'الواجب'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('المدفوعات'),
                  if (!_canSeeFinancials) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_rounded, size: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QR Dialog ────────────────────────────────────────────────────────────
  void _showQRDialog(BuildContext context, Student s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Code', textAlign: TextAlign.center),
        content: SizedBox(
          width: 280,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
            if (_group != null) ...[
              const SizedBox(height: 4),
              Text('المجموعة: ${_group!.name}',
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
            if (s.code.trim().isEmpty)
              const Text('لا يوجد كود', style: TextStyle(color: Colors.red))
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                    data: s.code,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white),
              ),
            const SizedBox(height: 10),
            Text(s.code,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق')),
          FilledButton.icon(
            onPressed: s.code.trim().isEmpty
                ? null
                : () async {
                    final ok = await _saveStudentQrImage(s);
                    if (!ctx.mounted) return;
                    if (ok) {
                      ToastHelper.success('تم حفظ صورة QR');
                    } else {
                      ToastHelper.error('تعذر حفظ صورة QR');
                    }
                  },
            style: FilledButton.styleFrom(backgroundColor: _accentColor),
            icon: const Icon(Icons.download_rounded),
            label: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ─── Save QR ──────────────────────────────────────────────────────────────
  Future<bool> _saveStudentQrImage(Student s) async {
    try {
      const int qrSize = 700;
      const double padding = 40, spacing = 24;
      final painter = QrPainter(
        data: s.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
      );
      final ui.Image qrImage = await painter.toImage(qrSize.toDouble());

      const tsTitle = TextStyle(
          color: Colors.black,
          fontSize: 48,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cairo');
      const tsSub =
          TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: s.name, style: tsTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine = (_group?.name.isNotEmpty ?? false)
          ? 'المجموعة: ${_group!.name}'
          : null;
      final TextPainter? tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: tsSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl)
            ..layout(maxWidth: qrSize.toDouble()));

      final tpCode = TextPainter(
        text: TextSpan(text: 'الكود: ${s.code}', style: tsSub),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: qrSize.toDouble());

      final double textH =
          tpName.height + (tpGroup?.height ?? 0) + tpCode.height + spacing * 2;
      final int w = (qrSize + padding * 2).round();
      final int h = (padding + qrSize + spacing + textH + padding).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF));
      final qrL = (w - qrSize) / 2;
      canvas.drawImageRect(
          qrImage,
          Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble()),
          Rect.fromLTWH(qrL, padding, qrSize.toDouble(), qrSize.toDouble()),
          Paint());

      double y = padding + qrSize + spacing;
      tpName.paint(canvas, Offset((w - tpName.width) / 2, y));
      y += tpName.height + 8;
      if (tpGroup != null) {
        tpGroup.paint(canvas, Offset((w - tpGroup.width) / 2, y));
        y += tpGroup.height + 8;
      }
      tpCode.paint(canvas, Offset((w - tpCode.width) / 2, y));

      final byteData = await (await recorder.endRecording().toImage(w, h))
          .toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;

      await Permission.storage.request();
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'ActiveClass';

      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/student_qr_${s.code}.png');
      await tmpFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      var saveInfo = await MediaStore().saveFile(
          tempFilePath: tmpFile.path,
          dirType: DirType.photo,
          dirName: DirType.photo.defaults);
      if (saveInfo?.uri == null) {
        saveInfo = await MediaStore().saveFile(
            tempFilePath: tmpFile.path,
            dirType: DirType.download,
            dirName: DirType.download.defaults);
      }

      final success = saveInfo?.uri != null;
      if (success) {
        try {
          final path = await MediaStore()
              .getFilePathFromUri(uriString: saveInfo!.uri.toString());
          if (path != null && path.isNotEmpty) {
            await DatabaseService().updateStudent(s.copyWith(qrPath: path));
          }
        } catch (_) {}
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header helpers
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 13),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
    ]);
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeaderStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action chip
// ─────────────────────────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool locked;
  const _ActionChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LockBadge(
        locked: locked,
        child: GestureDetector(
          onTap: locked ? showLockedPermissionHint : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance tab
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  final List<Attendance> attendance;
  final int presentCount;
  final int absentCount;
  final double attRate;
  final Color accentColor;

  const _AttendanceTab({
    required this.attendance,
    required this.presentCount,
    required this.absentCount,
    required this.attRate,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = List.of(attendance)
      ..sort((a, b) => b.date.compareTo(a.date));

    // تجميع بالشهر
    final Map<String, List<Attendance>> byMonth = {};
    for (final a in sorted) {
      final label = DateFormat('MMMM yyyy', 'ar').format(a.date);
      (byMonth[label] ??= []).add(a);
    }
    final months = byMonth.keys.toList();

    if (sorted.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.calendar_today_rounded,
          title: 'لا توجد سجلات حضور',
          subtitle: 'سيظهر هنا سجل الحضور عند التسجيل',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // شريط التقدم
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2540) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)
                  ],
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: _MiniStat('حضور', '$presentCount', Colors.green)),
              Expanded(child: _MiniStat('غياب', '$absentCount', Colors.red)),
              Expanded(
                  child: _MiniStat(
                      'النسبة',
                      '${attRate.toStringAsFixed(0)}%',
                      attRate >= 75
                          ? Colors.green
                          : attRate >= 50
                              ? Colors.orange
                              : Colors.red)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: attendance.isEmpty ? 0 : attRate / 100,
                minHeight: 8,
                backgroundColor: Colors.red.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(attRate >= 75
                    ? Colors.green
                    : attRate >= 50
                        ? Colors.orange
                        : Colors.red),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // قائمة بالشهر
        ...months.map((month) {
          final list = byMonth[month]!;
          final mPresent =
              list.where((a) => a.status == ATTENDANCE_PRESENT).length;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(children: [
                    Text(month,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$mPresent/${list.length}',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2540) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8)
                          ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, indent: 56),
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final isPresent = a.status == ATTENDANCE_PRESENT;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isPresent ? Colors.green : Colors.red)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPresent
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: isPresent ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Text(FormatHelper.formatFullDate(a.date),
                            style: const TextStyle(fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPresent ? Colors.green : Colors.red)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(a.status,
                              style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ]);
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Homework tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeworkTab extends StatelessWidget {
  final List<Homework> homework;
  final Color accentColor;

  const _HomeworkTab({
    required this.homework,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = List.of(homework)..sort((a, b) => b.date.compareTo(a.date));

    final doneCount = sorted.where((h) => h.status == HOMEWORK_DONE).length;
    final notDoneCount =
        sorted.where((h) => h.status == HOMEWORK_NOT_DONE).length;
    final total = doneCount + notDoneCount;
    final rate = total == 0 ? 0.0 : (doneCount / total) * 100;

    final Map<String, List<Homework>> byMonth = {};
    for (final h in sorted) {
      final label = DateFormat('MMMM yyyy', 'ar').format(h.date);
      (byMonth[label] ??= []).add(h);
    }
    final months = byMonth.keys.toList();

    if (sorted.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'لا توجد سجلات واجب',
          subtitle: 'سيظهر هنا سجل الواجب عند التسجيل',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2540) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)
                  ],
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: _MiniStat('عمل', '$doneCount', Colors.blue)),
              Expanded(
                  child: _MiniStat('لم يعمل', '$notDoneCount', Colors.orange)),
              Expanded(
                  child: _MiniStat(
                      'النسبة',
                      '${rate.toStringAsFixed(0)}%',
                      rate >= 75
                          ? Colors.green
                          : rate >= 50
                              ? Colors.orange
                              : Colors.red)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : rate / 100,
                minHeight: 8,
                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(rate >= 75
                    ? Colors.green
                    : rate >= 50
                        ? Colors.orange
                        : Colors.red),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ...months.map((month) {
          final list = byMonth[month]!;
          final mDone = list.where((h) => h.status == HOMEWORK_DONE).length;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(children: [
                    Text(month,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$mDone/${list.length}',
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2540) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8)
                          ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, indent: 56),
                    itemBuilder: (_, i) {
                      final h = list[i];
                      final isDone = h.status == HOMEWORK_DONE;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isDone ? Colors.blue : Colors.orange)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDone
                                ? Icons.menu_book_rounded
                                : Icons.menu_book_outlined,
                            color: isDone ? Colors.blue : Colors.orange,
                            size: 18,
                          ),
                        ),
                        title: Text(FormatHelper.formatFullDate(h.date),
                            style: const TextStyle(fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDone ? Colors.blue : Colors.orange)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(h.status,
                              style: TextStyle(
                                  color: isDone ? Colors.blue : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ]);
        }),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 18)),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payments tab
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentsTab extends StatelessWidget {
  final List<Payment> payments;
  final double totalPaid;
  final double accumulatedDebt;
  final Color accentColor;

  const _PaymentsTab({
    required this.payments,
    required this.totalPaid,
    required this.accumulatedDebt,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = List.of(payments)..sort((a, b) => b.date.compareTo(a.date));

    // تجميع بالشهر
    final Map<String, List<Payment>> byMonth = {};
    for (final p in sorted) {
      final label = DateFormat('MMMM yyyy', 'ar').format(p.date);
      (byMonth[label] ??= []).add(p);
    }
    final months = byMonth.keys.toList();

    if (sorted.isEmpty && accumulatedDebt <= 0) {
      return const Center(
        child: EmptyState(
          icon: Icons.payments_rounded,
          title: 'لا توجد مدفوعات',
          subtitle: 'سيظهر هنا سجل المدفوعات عند الإضافة',
        ),
      );
    }

    // Obx هنا عشان تواريخ الدفعات تتحدث تلقائيًا لما نظام الساعة 12/24
    // يتغيّر من الإعدادات — الويدجت دي بتتبني مرة واحدة جوه TabBarView
    // ومكانتش بتتحدّث تلقائيًا من غير ده.
    return Obx(() {
      Get.find<SettingsController>().use24hFormat.value;
      return _buildList(isDark, months, byMonth);
    });
  }

  Widget _buildList(
      bool isDark, List<String> months, Map<String, List<Payment>> byMonth) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // مديونية متراكمة — بتظهر بس لو فيه فعلاً مبلغ متأخر (مجموع
        // "المستحق - المدفوع" لكل شهر من انضمام الطالب لحد دلوقتي)
        if (accumulatedDebt > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.report_gmailerrorred_rounded,
                    color: Colors.red, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مديونية متراكمة',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      CurrencyText(accumulatedDebt,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.red)),
                    ]),
              ),
              // زر تعديل المديونية مخفي مؤقتًا لحد ما يتظبط (بيفتح شيت
              // تعديل الطالب الكامل بدل ما يعدّل الرقم نفسه).
            ]),
          ),
          const SizedBox(height: 16),
        ],
        // إجمالي
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2540) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)
                  ],
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments_rounded,
                  color: Colors.green, size: 22),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إجمالي المدفوعات',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              CurrencyText(totalPaid,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.green)),
            ]),
            const Spacer(),
            Text('${payments.length} دفعة',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 16),

        // قائمة بالشهر
        ...months.map((month) {
          final list = byMonth[month]!;
          final mTotal = list.fold<double>(0, (s, p) => s + p.amount);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(children: [
                    Text(month,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const Spacer(),
                    CurrencyText(mTotal,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                            fontSize: 13)),
                  ]),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2540) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8)
                          ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, indent: 56),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.green, size: 18),
                        ),
                        title: Text(FormatHelper.formatPaymentDate(p.date),
                            style: const TextStyle(fontSize: 13)),
                        subtitle: p.note != null && p.note!.isNotEmpty
                            ? Text(p.note!,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500))
                            : null,
                        trailing: CurrencyText(p.amount,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                fontSize: 14)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ]);
        }),
      ],
    );
  }
}
