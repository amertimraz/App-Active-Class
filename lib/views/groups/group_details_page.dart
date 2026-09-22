// lib/views/groups/group_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:get/get.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/sibling_departure_check.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/group_price_helper.dart';
import 'package:active_class/utils/student_sort_helper.dart';
import 'package:active_class/widgets/student_sort_bar.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/views/groups/group_form/group_form_sheet.dart';
import 'package:active_class/views/groups/group_details_widgets.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/clock_text.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/monthly_report_message.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:intl/intl.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'dart:async';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';
import 'package:active_class/widgets/remove_student_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── أيقونات المجموعات (نفس قائمة groups_page) ──────────────────────────────
const _kIconMap = <String, IconData>{
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

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({super.key});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final StudentController studentController = Get.put(StudentController());
  final AttendanceController attendanceController =
      Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());
  List<Payment> _allPayments = [];
  Group? group;
  late final TextEditingController _searchCtrl;

  bool _isSelectionMode = false;
  final Set<int> _selectedStudents = {};
  final Set<int> _paidStudentIds = {};
  late final bool _canSeeFinancials = TeamModeService().canSeeFinancials;
  StudentSort _sortBy = StudentSort.name;
  bool _sortAscending = true;

  void _onSortTap(StudentSort sort) {
    setState(() {
      if (_sortBy == sort) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sort;
        _sortAscending = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    group = Get.arguments as Group?;
    _searchCtrl = TextEditingController(
        text: studentController.searchQuery.value)
      ..selection = TextSelection.fromPosition(
          ui.TextPosition(offset: studentController.searchQuery.value.length));
    _searchCtrl
        .addListener(() => studentController.searchStudents(_searchCtrl.text));
    final g = group;
    // _loadPaidStudents بقت بتلف على studentController.students عشان
    // تحسب المديونية المتراكمة لكل طالب — لازم تستنى تحميل طلاب
    // المجموعة يخلص الأول (مش تتنفّذ بالتوازي زي قبل)، وإلا ممكن تلف
    // على قائمة فاضية أو قديمة من مجموعة تانية كان المستخدم فاتحها.
    if (g != null && g.id != null) {
      studentController.loadStudentsByGroup(g.id!).then((_) {
        if (mounted) _loadPaidStudents();
      });
    } else {
      _loadPaidStudents();
    }
  }

  /// شارة "لم يدفع" لازم تعكس المديونية المتراكمة الحقيقية (كل الشهور
  /// من انضمام الطالب)، مش الشهر الحالي بس — وإلا طالب عليه شهر قديم
  /// بس دافع الشهر ده كان هيبان "دافع" في القايمة وهو لسه عليه فلوس.
  /// لازم ننتظر تحميل الحضور الأول عشان حساب المستحق في مجموعات
  /// "بالحصة" يبقى صحيح.
  Future<void> _loadPaidStudents() async {
    await attendanceController.loadAttendance();
    final allPayments = await DatabaseService().getAllPayments();
    final g = group;
    final graceDays = Get.find<SettingsController>().paymentGraceDays.value;
    final fullyPaid = <int>{};
    for (final s in studentController.students) {
      if (s.groupId != g?.id) continue;
      final overdue = PricingHelper.isOverdue(
        student: s,
        group: g,
        allAttendance: attendanceController.attendance,
        payments: allPayments.where((p) => p.studentId == s.id).toList(),
        graceDays: graceDays,
        siblingGroupMembers: studentController.students,
      );
      if (!overdue) fullyPaid.add(s.id!);
    }
    if (mounted) {
      setState(() {
        _paidStudentIds
          ..clear()
          ..addAll(fullyPaid);
        _allPayments = allPayments;
      });
      // spec 035 — تنبيه "خروج عضو من مجموعة إخوة" لو موجود، لطلاب
      // المجموعة دي تحديدًا.
      unawaited(checkAndShowSiblingDepartureAlert(
          context,
          studentController.students
              .where((s) => s.groupId == g?.id)
              .toList()));
    }
  }

  void _toggleSelection(int studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
        if (_selectedStudents.isEmpty) _isSelectionMode = false;
      } else {
        _selectedStudents.add(studentId);
      }
    });
  }

  Future<void> _recordBulkAttendance(String status) async {
    if (_selectedStudents.isEmpty) return;
    final now = DateTime.now();
    final total = _selectedStudents.length;
    final attCtrl = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());

    // نفس التحقق من جدول المجموعة المستخدم في تاب "تسجيل" اليدوي ومسح
    // الـ QR — من غيره كان ممكن يتسجل حضور جماعي في يوم مفيهوش حصة
    // مجدولة أصلاً، وده بيفسد حساب "عدد الحصص المستحقة" في PricingHelper.
    final g = group;
    if (g != null && !attCtrl.groupHasSessionOnDay(g, now)) {
      ToastHelper.error('مجموعة "${g.name}" ليس لها حصة اليوم');
      return;
    }

    // بنستخدم setAttendanceStatus (تحديث مباشر) بدل insertAttendance
    // المباشر — عشان لو طالب اتسجّل حضوره النهارده بالفعل، العملية
    // تحدّث حالته بدل ما تفشل بصمت بسبب UNIQUE(student_id, date).
    var failed = 0;
    for (final id in _selectedStudents) {
      try {
        await attCtrl.setAttendanceStatus(id, now, status);
      } catch (_) {
        failed++;
      }
    }

    final label = status == ATTENDANCE_PRESENT ? 'الحضور' : 'الغياب';
    if (failed == 0) {
      ToastHelper.success('تم تسجيل $label لـ$total طالب بنجاح');
    } else if (failed == total) {
      ToastHelper.error('فشل تسجيل $label — حاول تاني');
    } else {
      ToastHelper.error(
          'اتسجّل $label لـ${total - failed} من $total طالب — فشل $failed');
    }
    setState(() {
      _selectedStudents.clear();
      _isSelectionMode = false;
    });
  }

  void _refreshGroup() async {
    final g = group;
    if (g?.id == null) return;
    final updated = await DatabaseService().getGroup(g!.id!);
    if (mounted && updated != null) setState(() => group = updated);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ─────────────────────────────────────────────────────────────
  Color get _groupColor {
    final c = group?.color;
    return c != null ? Color(c) : AppTheme.primaryColor;
  }

  IconData get _groupIcon =>
      _kIconMap[group?.icon ?? ''] ?? Icons.groups_rounded;

  String _formatSchedule(String? raw) {
    final r = raw?.trim() ?? '';
    if (r.isEmpty) return '-';
    String fmt(TimeOfDay t) => FormatHelper.formatClock(t);

    TimeOfDay? parse(String v) {
      final p = v.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    return r.split(',').map((s) {
      final txt = s.trim();
      if (txt.isEmpty) return txt;
      final sp = txt.split(' ');
      if (sp.length < 2) return txt;
      final day = sp.first;
      final times = txt.substring(day.length).trim().split('-');
      if (times.length != 2) return txt;
      final from = parse(times[0].trim()), to = parse(times[1].trim());
      if (from == null || to == null) return txt;
      return '$day ${fmt(from)}-${fmt(to)}';
    }).join('  •  ');
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final g = group;
    if (g == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المجموعة')),
        body: const Center(child: Text('لم يتم العثور على بيانات المجموعة')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _groupColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1520) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        title: _isSelectionMode
            ? Text('${_selectedStudents.length} محدد')
            : Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedStudents.clear();
                }),
              )
            : null,
        actions: _isSelectionMode
            ? null
            : [
                IconButton(
                  tooltip: 'تعديل المجموعة',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _showEditGroupSheet(context, g),
                ),
              ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final lic = Get.find<LicenseController>();
                // عدد كل الطلاب (نشط + مؤرشف) — الأرشفة مش بتفضّي مكان في
                // حد الباقة (قرار FR-013)، فمينفعش نستخدم students.length
                // (بقت نشطين بس بعد ميزة الأرشفة).
                final totalCount =
                    Get.find<StudentController>().totalStudentCount;
                final err = lic.checkCanAddStudent(totalCount);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(err, style: const TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'ترقية',
                      textColor: Colors.white,
                      onPressed: () => Get.toNamed(ROUTE_PLANS),
                    ),
                  ));
                  return;
                }
                _showAddStudentSheet(context, g);
              },
              backgroundColor: primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('إضافة طالب',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
      bottomNavigationBar:
          _isSelectionMode ? _buildSelectionBar(primary) : null,
      body: Obx(() {
        final allStudents =
            studentController.students.where((s) => s.groupId == g.id).toList();
        final sortedStudents = sortStudents(
          students: studentController.filteredStudents,
          sortBy: _sortBy,
          ascending: _sortAscending,
          groupOf: (_) => g,
          allAttendance: attendanceController.attendance,
          allPayments: _allPayments,
        );
        // بيستخدم PricingHelper بدل s.price مباشرة عشان يراعي الإعفاء
        // ومجموعات "بالحصة" (بيتحسب فيها على عدد الحصص المحضورة الشهر
        // الحالي، مش سعر الحصة الواحدة كأنه القيمة الشهرية الكاملة).
        final now = DateTime.now();
        final totalFees = allStudents.fold<double>(
            0.0,
            (sum, s) =>
                sum +
                PricingHelper.monthlyDue(
                    student: s,
                    group: g,
                    month: DateTime(now.year, now.month),
                    allAttendance: attendanceController.attendance,
                    siblingGroupMembers: studentController.students));

        // الحصص المسجلة فعليًا للمجموعة دي — أي تاريخ (يوم كامل) فيه على
        // الأقل سجل حضور واحد لطالب من طلابها، بغض النظر هل اليوم ده
        // مطابق لجدول المجموعة بالحرف ولا لأ (المدرس ممكن يسجّل حصة
        // تعويضية في يوم غير الجدول المعتاد). محصورة بآخر 4 شهور (تقريبًا
        // مدة ترم) عشان الكارت والقايمة يفضلوا معبّرين عن الفترة الحالية
        // بدل تاريخ المجموعة بالكامل من أول يوم.
        final fourMonthsAgo =
            DateTime(now.year, now.month - 4, now.day);
        final studentIds = allStudents.map((s) => s.id).toSet();
        final groupAttendance = attendanceController.attendance
            .where((a) =>
                studentIds.contains(a.studentId) &&
                !a.date.isBefore(fourMonthsAgo))
            .toList();
        final byDay = <DateTime, List<Attendance>>{};
        for (final a in groupAttendance) {
          final day = DateTime(a.date.year, a.date.month, a.date.day);
          byDay.putIfAbsent(day, () => []).add(a);
        }
        final sessionDays = byDay.entries
            .map((e) => GDSessionDay(
                  date: e.key,
                  presentCount: e.value
                      .where((a) => attendanceCountsAsPresent(a.status))
                      .length,
                  totalMarked: e.value.length,
                  recordIds: e.value.map((a) => a.id!).toList(),
                ))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
                child: _buildHeader(context, g, allStudents, totalFees,
                    sessionDays, primary, isDark)),

            // ── Action buttons ──────────────────────────────────────────────
            SliverToBoxAdapter(
                child: _buildActionRow(context, g, allStudents, primary)),

            // ── Student list header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text('قائمة الطلاب',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    if (!_isSelectionMode && allStudents.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _isSelectionMode = true),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('تحديد متعدد'),
                        style: TextButton.styleFrom(foregroundColor: primary),
                      ),
                  ],
                ),
              ),
            ),

            // ── Search + ترتيب ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomSearchBar(
                        controller: _searchCtrl,
                        hintText: 'ابحث بالاسم أو الكود...',
                        onChanged: (v) => studentController.searchStudents(v),
                        onClear: () {
                          _searchCtrl.clear();
                          studentController.searchStudents('');
                        },
                      ),
                    ),
                    if (allStudents.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      StudentSortBar(
                        sortBy: _sortBy,
                        ascending: _sortAscending,
                        onChanged: _onSortTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Students ────────────────────────────────────────────────────
            if (studentController.filteredStudents.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: EmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'لا يوجد طلاب',
                    subtitle: 'اضغط على "إضافة طالب" للبدء',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final student = sortedStudents[index];
                      return StudentCard(
                        student: student,
                        groupColor: primary,
                        hasPaid: _paidStudentIds.contains(student.id),
                        canSeeFinancials: _canSeeFinancials,
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedStudents.contains(student.id),
                        onTap: () {
                          if (_isSelectionMode) {
                            if (student.id != null)
                              _toggleSelection(student.id!);
                          } else {
                            Get.toNamed(ROUTE_STUDENT_DETAILS,
                                arguments: student);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode)
                            setState(() => _isSelectionMode = true);
                          if (student.id != null) _toggleSelection(student.id!);
                        },
                        onQr: () => _gdShowQRDialog(context, student),
                        onEdit: () =>
                            _showEditStudentSheet(context, student, g),
                        onArchive: () => _confirmArchiveStudent(student),
                      );
                    },
                    childCount: sortedStudents.length,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ─── Header widget ────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context,
      Group g,
      List<Student> students,
      double totalFees,
      List<GDSessionDay> sessionDays,
      Color primary,
      bool isDark) {
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
            // أيقونة + اسم
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_groupIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(g.code ?? '-',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // مواعيد
            if ((g.schedule?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 14),
              ClockBuilder(
                builder: (_) => Text(_formatSchedule(g.schedule),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],

            const SizedBox(height: 16),

            // إحصائيات — رجعنا لصف واحد بـ4 خانات (بدل شبكة 2×2) بخط أصغر
            // للقيمة تحديدًا، عشان الكارت ميكبرش طولاً. راجع _HeaderStat
            // لتفاصيل حجم الخط الجديد.
            // IntrinsicHeight + stretch — من غيرهم كل خانة كانت بتاخد ارتفاع
            // مستقل حسب عدد أسطر تسميتها ("حصص مسجلة"/"إجمالي الرسوم" بتلف
            // سطرين أحيانًا بعكس "اشتراك"/"الطلاب")، فكانت الخانات تبان مش
            // متساوية الطول رغم إنها متساوية العرض.
            IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeaderStat(
                    label: 'الطلاب',
                    value: '${students.length}',
                    icon: Icons.people_rounded),
                const SizedBox(width: 10),
                HeaderStat(
                    // بدون اسم العملة هنا — الأيقونة والتسمية تحت الرقم
                    // ("إجمالي الرسوم") بتوضّح إنه مبلغ مالي أصلاً، فمفيش
                    // داعي نكرر "جنيه"/"ريال"/... جنب كل رقم في مساحة ضيقة.
                    label: 'إجمالي الرسوم',
                    value: _canSeeFinancials
                        ? FormatHelper.formatCurrencyCompact(totalFees)
                        : '🔒',
                    icon: Icons.payments_rounded,
                    locked: !_canSeeFinancials,
                    onTap: students.isEmpty
                        ? null
                        : () =>
                            _gdShowFeesBreakdownDialog(context, students, g)),
                const SizedBox(width: 10),
                HeaderStat(
                    label: 'اشتراك',
                    value: !_canSeeFinancials
                        ? '🔒'
                        : (g.price != null
                            ? FormatHelper.formatCurrencyCompact(g.price!)
                            : '-'),
                    icon: Icons.monetization_on_rounded,
                    locked: !_canSeeFinancials),
                const SizedBox(width: 10),
                HeaderStat(
                    label: 'حصص مسجلة',
                    value: '${sessionDays.length}',
                    icon: Icons.event_available_rounded,
                    onTap: sessionDays.isEmpty
                        ? null
                        : () => _gdShowSessionsDialog(
                            context, g.name, sessionDays)),
              ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Action row ───────────────────────────────────────────────────────────
  Widget _buildActionRow(
      BuildContext context, Group g, List<Student> students, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // ── زر الواتساب (يتحكم في ظهوره من الإعدادات) ───────────
          Obx(() {
            final settings = Get.find<SettingsController>();
            if (!settings.whatsappEnabled.value) {
              return const SizedBox.shrink();
            }
            final reached = settings.isWhatsappDayReached;
            return GroupActionChip(
              icon: Icons.chat_rounded,
              label: 'واتساب',
              color: reached ? Colors.green : Colors.grey,
              onTap: reached
                  ? () => _startGroupWhatsappBatchSend(context, g.id!)
                  : () => ToastHelper.info('زر الواتساب يظهر يوم '
                      '${settings.whatsappSendDay.value} من الشهر'),
            );
          }),
          const SizedBox(width: 8),
          GroupActionChip(
            icon: Icons.picture_as_pdf_rounded,
            label: 'تصدير PDF',
            color: const Color(0xFF8B5CF6),
            onTap: students.isEmpty
                ? () => ToastHelper.info('لا يوجد طلاب في هذه المجموعة')
                : () => _exportGroupRosterPdf(g, students),
          ),
          const SizedBox(width: 8),
          GroupActionChip(
            icon: Icons.clear_all_rounded,
            label: 'تصفير الطلاب',
            color: Colors.orange,
            onTap: () => _confirmResetStudents(g),
          ),
          const SizedBox(width: 8),
          GroupActionChip(
            icon: Icons.delete_rounded,
            label: 'حذف',
            color: Colors.red,
            onTap: () => _confirmDeleteGroup(g),
          ),
        ],
      ),
    );
  }

  // ─── Selection bottom bar ─────────────────────────────────────────────────
  Widget _buildSelectionBar(Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _recordBulkAttendance(ATTENDANCE_PRESENT),
              icon: const Icon(Icons.check_rounded),
              label: const Text('حضور'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _recordBulkAttendance(ATTENDANCE_ABSENT),
              icon: const Icon(Icons.close_rounded),
              label: const Text('غياب'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs / sheets ─────────────────────────────────────────────────────
  void _confirmDeleteGroup(Group g) {
    if (!requireDeletePermission(context, TeamModeService().canDeleteStudentsNow)) {
      return;
    }
    // لازم نحسب الطلاب المؤرشفين كمان — قيد المفتاح الأجنبي على الجدول
    // بيحذفهم نهائيًا مع المجموعة زيهم زي النشطين بالظبط رغم إنهم كانوا
    // "محفوظين للأبد" عمدًا بدل الحذف، فلازم المدرس ياخد قرار عن علم.
    final activeCount =
        studentController.students.where((s) => s.groupId == g.id).length;
    final archivedCount = studentController.archivedStudents
        .where((s) => s.groupId == g.id)
        .length;
    final count = activeCount + archivedCount;
    Get.defaultDialog(
      title: 'حذف المجموعة',
      middleText: count > 0
          ? 'تحذير: هيتحذف معاها $count طالب${archivedCount > 0 ? ' (منهم $archivedCount من الأرشيف)' : ''} '
              'وكل سجلات حضورهم ودفعاتهم ودرجات امتحاناتهم نهائياً — لا يمكن التراجع عن هذا الإجراء.'
          : 'هل تريد حذف هذه المجموعة؟ لا يمكن التراجع عن هذا الإجراء.',
      textCancel: 'إلغاء',
      textConfirm: 'حذف',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back(); // close dialog
        await Future.delayed(const Duration(milliseconds: 80));
        final ok = await Get.find<GroupController>().deleteGroup(g.id!);
        if (ok) {
          NotificationService().syncAllScheduledNotifications();
          Get.back(); // back to groups list — الخطأ (لو حصل) اتعرض بالفعل
        }
      },
    );
  }

  void _confirmResetStudents(Group g) {
    if (!requireDeletePermission(context, TeamModeService().canDeleteStudentsNow)) {
      return;
    }
    Get.defaultDialog(
      title: 'تصفير الطلاب',
      middleText:
          'سيتم حذف جميع الطلاب وسجلاتهم لهذه المجموعة. هل تريد المتابعة؟',
      textCancel: 'إلغاء',
      textConfirm: 'متابعة',
      confirmTextColor: Colors.white,
      buttonColor: Colors.orange,
      onConfirm: () async {
        Get.back();
        try {
          await DatabaseService().deleteStudentsByGroup(g.id!);
          await studentController.loadStudentsByGroup(g.id!);
          NotificationService().syncAllScheduledNotifications();
          ToastHelper.success('تم حذف الطلاب وتصفير الأكواد');
        } catch (e) {
          ToastHelper.error('فشل تصفير الطلاب — حاول تاني');
        }
      },
    );
  }

  void _confirmArchiveStudent(Student student) {
    if (student.id == null) return;
    showRemoveStudentDialog(
      context,
      student: student,
      canDelete: TeamModeService().canDeleteStudentsNow,
      onArchive: () async {
        final ok = await studentController.archiveStudent(student.id!);
        if (ok) NotificationService().syncAllScheduledNotifications();
        return ok;
      },
      onDeletePermanently: () async {
        final ok = await studentController.deleteStudent(student.id!);
        if (ok) NotificationService().syncAllScheduledNotifications();
        return ok;
      },
    );
  }

  Future<void> _showEditGroupSheet(BuildContext context, Group g) async {
    final groupController = Get.find<GroupController>();
    final oldPrice = g.price;
    // بنسجّل هنا آخر سعر جديد اتحفظ بنجاح (لو حصل) عشان نعرض عرض
    // التحديث الجماعي بعد ما الشيت يتقفل تمامًا — مش وإحنا لسه جوّاه.
    // لو الديالوج ده اتعرض واتنفّذ *جوّه* onSave (اللي بتستناه _GroupEditSheet
    // قبل ما تقفل نفسها)، الشيت كانت بتفضل عالقة في حالة "بيحفظ" لحد
    // ما المدرس يرد على الديالوج ويخلص التحديث الجماعي كله — بيبان
    // وكأن الشاشة "علّقت".
    double? savedNewPrice;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupFormSheet(
        group: g,
        existingGroups: groupController.groups,
        onSave: (updated) async {
          final ok = await groupController.updateGroup(updated);
          if (ok) {
            _refreshGroup();
            ToastHelper.success('تم حفظ التعديلات', title: 'تم');
            savedNewPrice = updated.price;
          }
          return ok;
        },
      ),
    );
    if (!context.mounted) return;
    if (savedNewPrice != null &&
        oldPrice != null &&
        savedNewPrice != oldPrice &&
        g.id != null) {
      await offerBulkStudentPriceUpdate(
          context, studentController, g.id!, savedNewPrice!,
          onUpdated: _loadPaidStudents);
    }
  }

  void _showAddStudentSheet(BuildContext context, Group g) {
    showAddStudentSheet(
      context,
      controller: studentController,
      preselectedGroup: g,
      onAdded: _loadPaidStudents,
    );
  }

  Future<void> _showEditStudentSheet(
      BuildContext context, Student student, Group g) async {
    await showEditStudentSheet(
      context,
      student: student,
      accentColor: _groupColor,
      controller: studentController,
    );
    _loadPaidStudents();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR dialog
// ─────────────────────────────────────────────────────────────────────────────
void _gdShowQRDialog(BuildContext context, Student student) {
  showDialog(
    context: context,
    builder: (ctx) => FutureBuilder<Group?>(
      future: DatabaseService().getGroup(student.groupId),
      builder: (_, snap) {
        final groupName = snap.data?.name ?? '';
        return AlertDialog(
          title: const Text('QR Code'),
          content: SizedBox(
            width: 280,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (groupName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('المجموعة: $groupName',
                    style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 12),
              if (student.code.trim().isEmpty)
                const Text('لا يوجد كود', style: TextStyle(color: Colors.red))
              else
                QrImageView(
                    data: student.code,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white),
              const SizedBox(height: 8),
              Text('الكود: ${student.code}'),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق')),
            FilledButton.icon(
              onPressed: student.code.trim().isEmpty
                  ? null
                  : () async {
                      final ok = await _gdSaveStudentQrImage(student);
                      if (!ctx.mounted) return;
                      if (ok) {
                        ToastHelper.success('تم حفظ صورة QR');
                      } else {
                        ToastHelper.error('تعذر حفظ صورة QR');
                      }
                    },
              icon: const Icon(Icons.download_rounded),
              label: const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Save QR image to gallery
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> _gdSaveStudentQrImage(Student student) async {
  try {
    final group = await DatabaseService().getGroup(student.groupId);
    final groupName = group?.name;
    const int qrSize = 700;
    const double padding = 40, spacing = 24;

    final painter = QrPainter(
      data: student.code,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
    );
    final ui.Image qrImage = await painter.toImage(qrSize.toDouble());

    const textStyleTitle = TextStyle(
        color: Colors.black,
        fontSize: 48,
        fontWeight: FontWeight.w600,
        fontFamily: 'Cairo');
    const textStyleSub =
        TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');

    final tpName = TextPainter(
      text: TextSpan(text: student.name, style: textStyleTitle),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.rtl,
    )..layout(maxWidth: qrSize.toDouble());

    final groupLine = (groupName == null || groupName.isEmpty)
        ? null
        : 'المجموعة: $groupName';
    final TextPainter? tpGroup = groupLine == null
        ? null
        : (TextPainter(
            text: TextSpan(text: groupLine, style: textStyleSub),
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.rtl)
          ..layout(maxWidth: qrSize.toDouble()));

    final tpCode = TextPainter(
      text: TextSpan(text: 'الكود: ${student.code}', style: textStyleSub),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: qrSize.toDouble());

    final double textHeight =
        tpName.height + (tpGroup?.height ?? 0) + tpCode.height + spacing * 2;
    final int widthPx = (qrSize + padding * 2).round();
    final int heightPx =
        (padding + qrSize + spacing + textHeight + padding).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));

    final qrLeft = (widthPx - qrSize) / 2;
    canvas.drawImageRect(
        qrImage,
        Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble()),
        Rect.fromLTWH(qrLeft, padding, qrSize.toDouble(), qrSize.toDouble()),
        Paint());

    double y = padding + qrSize + spacing;
    tpName.paint(canvas, Offset((widthPx - tpName.width) / 2, y));
    y += tpName.height + 8;
    if (tpGroup != null) {
      tpGroup.paint(canvas, Offset((widthPx - tpGroup.width) / 2, y));
      y += tpGroup.height + 8;
    }
    tpCode.paint(canvas, Offset((widthPx - tpCode.width) / 2, y));

    final composed = await recorder.endRecording().toImage(widthPx, heightPx);
    final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;

    await Permission.storage.request();
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'ActiveClass';

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/student_qr_${student.code}.png');
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
          await DatabaseService().updateStudent(student.copyWith(qrPath: path));
        }
      } catch (_) {}
    }
    return success;
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// تصدير PDF لكشف طلاب المجموعة
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _exportGroupRosterPdf(Group g, List<Student> students) async {
  final pdf = pw.Document();
  final font =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final fontBold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  final sorted = List<Student>.from(students)
    ..sort((a, b) => a.code.compareTo(b.code));

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    build: (ctx) => [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: g.color != null
              ? PdfColor.fromInt(g.color!)
              : PdfColor.fromInt(0xFF4F46E5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('كشف طلاب مجموعة',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 16, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(g.name,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 22, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text('عدد الطلاب: ${sorted.length}',
                style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: const PdfColor(1, 1, 1, 0.7))),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
            children: ['#', 'اسم الطالب', 'الكود', 'هاتف ولي الأمر', 'الرسوم']
                .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 11,
                              color: PdfColors.white),
                          textAlign: pw.TextAlign.center),
                    ))
                .toList(),
          ),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final bg =
                i.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFF);
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                '${i + 1}',
                s.name,
                s.code,
                s.guardianPhone?.trim().isNotEmpty == true
                    ? s.guardianPhone!
                    : '-',
                TeamModeService().canSeeFinancials
                    ? s.effectivePrice.toStringAsFixed(0)
                    : '-',
              ]
                  .map((v) => pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(v,
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.center),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    ],
  ));

  await Printing.sharePdf(
      bytes: await pdf.save(), filename: 'مجموعة_${g.name}.pdf');
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp batch send
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _startGroupWhatsappBatchSend(
    BuildContext context, int groupId) async {
  final db = DatabaseService();
  final settings = Get.find<SettingsController>();
  final students = await db.getStudentsByGroup(groupId);
  final valid = students
      .where((s) =>
          !s.isArchived &&
          ((s.guardianPhone ?? '').trim().isNotEmpty ||
              (s.guardianWhatsapp ?? '').trim().isNotEmpty))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (valid.isEmpty) {
    ToastHelper.info('لا يوجد أولياء أمور بأرقام أو واتساب مسجلة');
    return;
  }
  if (!context.mounted) return;
  await _pickAndSend(context, valid, settings);
}

Future<void> _pickAndSend(BuildContext context, List<Student> all,
    SettingsController settings) async {
  final db = DatabaseService();
  final ids = all.map((s) => s.id!).toList();
  // شهر التحصيل هو الحد الأقصى — مفيش إرسال لشهر لسه ما خلصش (spec 013 US3).
  final maxMonth = defaultCollectionMonth();
  final sentMap = await db.getReportSentMap(ids, maxMonth);


  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      List<Student> items = List.of(all);
      // افتراضياً: الطلاب اللي اتبعتلهم الشهر ده ميتشيكوش (عشان ميتكررش الإرسال)
      List<bool> sel = items.map((s) => !sentMap.containsKey(s.id)).toList();
      bool sending = false;
      DateTime selMonth = maxMonth;
      DateTime start = DateTime(selMonth.year, selMonth.month, 1);
      DateTime end =
          DateTime(selMonth.year, selMonth.month + 1, 0, 23, 59, 59);
      return StatefulBuilder(
        builder: (ctx, setSt) {
          Future<void> changeMonth(int delta) async {
            final m = DateTime(selMonth.year, selMonth.month + delta, 1);
            if (m.isAfter(maxMonth)) return;
            final fresh = await db.getReportSentMap(ids, m);
            setSt(() {
              selMonth = m;
              start = DateTime(m.year, m.month, 1);
              end = DateTime(m.year, m.month + 1, 0, 23, 59, 59);
              sentMap
                ..clear()
                ..addAll(fresh);
              for (int i = 0; i < sel.length; i++) {
                sel[i] = !sentMap.containsKey(items[i].id);
              }
            });
          }

          final atMaxMonth = !selMonth
              .isBefore(DateTime(maxMonth.year, maxMonth.month, 1));
          final sentCount =
              items.where((s) => sentMap.containsKey(s.id)).length;
          final remainingCount = items.length - sentCount;
          final selectedCount = sel.where((e) => e).length;
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إرسال تقرير واتساب'),
                const SizedBox(height: 6),
                Row(children: [
                  SendStatBadge(
                      label: 'تم الإرسال',
                      count: sentCount,
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded),
                  const SizedBox(width: 8),
                  SendStatBadge(
                      label: 'لم يُرسل',
                      count: remainingCount,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.schedule_rounded),
                ]),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // منتقي شهر التقرير
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: sending
                            ? null
                            : () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'الشهر السابق',
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'ar').format(selMonth),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      IconButton(
                        onPressed: sending || atMaxMonth
                            ? null
                            : () => changeMonth(1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'الشهر التالي',
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  // أزرار تحديد سريعة
                  Row(children: [
                    TextButton.icon(
                      onPressed: sending
                          ? null
                          : () => setSt(() {
                                for (int i = 0; i < sel.length; i++) {
                                  sel[i] = !sentMap.containsKey(items[i].id);
                                }
                              }),
                      icon: const Icon(Icons.filter_alt_rounded, size: 16),
                      label: const Text('غير المُرسَل فقط'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: sending
                          ? null
                          : () => setSt(() {
                                for (int i = 0; i < sel.length; i++) {
                                  sel[i] = true;
                                }
                              }),
                      child: const Text('تحديد الكل'),
                    ),
                  ]),
                  const Divider(height: 1),
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final s = items[i];
                        final last = sentMap[s.id!];
                        final alreadySent = last != null;
                        return CheckboxListTile(
                          value: sel[i],
                          onChanged: sending
                              ? null
                              : (v) => setSt(() => sel[i] = v ?? false),
                          title: Row(children: [
                            Expanded(child: Text(s.name)),
                            if (alreadySent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 13, color: Color(0xFF10B981)),
                                      SizedBox(width: 3),
                                      Text('تم الإرسال',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF10B981))),
                                    ]),
                              ),
                          ]),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.guardianPhone ?? '-'),
                                if (last != null)
                                  ClockBuilder(
                                    builder: (_) => Text(
                                        'آخر إرسال: ${FormatHelper.formatDateTime(last)}',
                                        style:
                                            Theme.of(ctx).textTheme.bodySmall),
                                  ),
                              ]),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: sending || selectedCount == 0
                    ? null
                    : () async {
                        setSt(() => sending = true);
                        for (int i = 0; i < items.length; i++) {
                          if (!sel[i]) continue;
                          final s = items[i];
                          final group = await db.getGroup(s.groupId);
                          final atts = await db.getAttendanceByStudent(s.id!);
                          final pays = await db.getPaymentsByStudent(s.id!);
                          final hw = await db.getHomeworkByStudent(s.id!);
                          final attsMonth = atts
                              .where((a) =>
                                  !a.date.isBefore(start) &&
                                  !a.date.isAfter(end))
                              .toList();
                          final paysMonth = pays
                              .where((p) =>
                                  !p.date.isBefore(start) &&
                                  !p.date.isAfter(end))
                              .toList();
                          final hwMonth = hw
                              .where((h) =>
                                  !h.date.isBefore(start) &&
                                  !h.date.isAfter(end))
                              .toList();
                          final examsMonth = TeamModeService().canSeeAcademics
                              ? (await db.getStudentExamHistory(s.id!))
                                  .where((r) =>
                                      r.reportMonth.year == selMonth.year &&
                                      r.reportMonth.month == selMonth.month)
                                  .toList()
                              : <StudentExamRecord>[];

                          final message = buildMonthlyReportMessage(
                            student: s,
                            month: selMonth,
                            groupName: group?.name ?? '-',
                            monthAtt: attsMonth,
                            monthHw: hwMonth,
                            monthPays: paysMonth,
                            monthExams: examsMonth,
                            teacherName: settings.teacherFullName.value,
                            teacherSpecialization:
                                settings.teacherSpecialization.value,
                            canSeeFinancials:
                                TeamModeService().canSeeFinancials,
                            canSeeAcademics: TeamModeService().canSeeAcademics,
                          );

                          if (!context.mounted) break;
                          await launchGuardianWhatsapp(
                            context: context,
                            phone: s.guardianPhone,
                            whatsapp: s.guardianWhatsapp,
                            message: message,
                            dialCode: settings.countryDial.value,
                          );
                          await _gdWaitForResume();

                          final sentAt = DateTime.now();
                          await db.upsertReportLog(s.id!, start, sentAt);
                          ToastHelper.success('تم إرسال التقرير لـ ${s.name}');

                          setSt(() {
                            sentMap[s.id!] = sentAt;
                            items.removeAt(i);
                            sel.removeAt(i);
                            i--;
                          });
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                child: Text('ابدأ الإرسال ($selectedCount)'),
              ),
            ],
          );
        },
      );
    },
  );
}

// ─── يوم حصة مسجّلة (لكارت "حصص مسجلة" في هيدر تفاصيل المجموعة) ───────────────

void _gdShowSessionsDialog(
    BuildContext context, String groupName, List<GDSessionDay> sessionDays) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('الحصص المسجلة (آخر 4 شهور) — $groupName'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: sessionDays.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = sessionDays[i];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.event_available_rounded,
                  color: AppTheme.primaryColor),
              title: Text(DateFormat('EEEE، d MMMM yyyy', 'ar').format(d.date)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d.presentCount}/${d.totalMarked} حاضر',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.green)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20),
                    tooltip: 'حذف الحصة',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('حذف الحصة'),
                          content: Text(
                              'هل تريد حذف كل سجلات الحضور المسجّلة يوم '
                              '${DateFormat('EEEE، d MMMM yyyy', 'ar').format(d.date)}؟ '
                              '(${d.totalMarked} سجل)'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('إلغاء')),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await Get.find<AttendanceController>()
                            .deleteAttendanceRecords(d.recordIds);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}


Future<void> _gdWaitForResume() {
  final c = Completer<void>();
  late GDResumeObserver obs;
  obs = GDResumeObserver(() {
    WidgetsBinding.instance.removeObserver(obs);
    if (!c.isCompleted) c.complete();
  });
  WidgetsBinding.instance.addObserver(obs);
  return c.future;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fees breakdown dialog
// ─────────────────────────────────────────────────────────────────────────────
void _gdShowFeesBreakdownDialog(
    BuildContext context, List<Student> students, Group group) {
  showDialog(
    context: context,
    builder: (ctx) {
      final db = DatabaseService();
      final settings = Get.find<SettingsController>();
      final attCtrl = Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());
      DateTime selected = defaultCollectionMonth();


      Future<Map<String, dynamic>> load(DateTime monthStart) async {
        final monthEnd =
            DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);
        final byId = {
          for (final s in students)
            if (s.id != null) s.id!: s
        };
        final Set<int> allowed = {};
        for (final s in students) {
          if (s.id == null) continue;
          final st = s.attendanceStart;
          if (st != null && DateTime(st.year, st.month, 1).isAfter(monthStart))
            continue;
          allowed.add(s.id!);
        }

        // بيستخدم PricingHelper بدل s.price مباشرة عشان يراعي الإعفاء
        // (جزئي أو كامل)، مجموعات "بالحصة" (بيتحسب فيها على عدد الحصص
        // المحضورة الشهر ده، مش سعر الحصة الواحدة كأنه القيمة الكاملة)،
        // وعرض الإخوة (2-3 — بيقسّم الإجمالي المشترك على عدد الأعضاء
        // الفعلي تلقائيًا عبر siblingGroupMembers، راجع
        // specs/007-three-sibling-support).
        final Map<double, int> solo = {};
        final Map<int, double> dueById = {};
        final allStudentsList = byId.values.toList();
        for (final id in allowed) {
          final s = byId[id]!;
          final due = PricingHelper.monthlyDue(
              student: s,
              group: group,
              month: monthStart,
              allAttendance: attCtrl.attendance,
              siblingGroupMembers: allStudentsList);
          if (due > 0) solo[due] = (solo[due] ?? 0) + 1;
          dueById[id] = due;
        }

        double expected = 0;
        solo.forEach((p, c) => expected += p * c);

        int paidCount = 0;
        double paidAmount = 0; // كاش محصّل فعليًا مؤرَّخ في نطاق الشهر ده (تدفق نقدي)
        final List<Student> unpaidStudents = [];
        // مفيش أي مستحق أصلاً (معفى بالكامل، أو بالحصة ولسه محضرش أي
        // حصة الشهر ده) — مش هيتحسب لا مدفوع ولا غير مدفوع.
        var applicableCount = 0;

        for (final id in allowed) {
          final s = byId[id]!;
          final due = dueById[id] ?? 0;
          if (due <= 0) continue;
          applicableCount++;
          final list = await db.getPaymentsByStudent(id);

          // spec 038 — استبعاد صفوف إسقاط المديونية من الكاش المحصَّل
          // فعليًا (مش فلوس حقيقية دخلت).
          paidAmount += list
              .where((p) =>
                  !p.date.isBefore(monthStart) &&
                  !p.date.isAfter(monthEnd) &&
                  p.note != kDebtWriteOffNote)
              .fold<double>(0, (sum, p) => sum + p.amount);

          // "مين لسه عليه فلوس لحد الشهر ده" لازم يعتمد على المديونية
          // المتراكمة (كل الشهور مطروح منها كل المدفوعات بغض النظر عن
          // تاريخها)، نفس منطق PricingHelper المستخدم في باقي التطبيق —
          // بدل مطابقة تاريخ/ملاحظة الدفعة يدويًا، اللي كانت ممكن تفوّت
          // طالب دافع فعلاً (بس مش بالتاريخ/الوسم المتوقَّع) أو العكس.
          final remaining = PricingHelper.accumulatedDebtThrough(
            student: s,
            group: group,
            allAttendance: attCtrl.attendance,
            payments: list,
            month: monthStart,
            siblingGroupMembers: allStudentsList,
          );
          if (remaining <= 0) {
            paidCount++;
          } else {
            unpaidStudents.add(s);
          }
        }

        return {
          'solo': solo,
          // "pairs" (عروض إخوة ثنائية) اتشالت — كل طالب (شامل أعضاء
          // مجموعات الإخوة) بقى بيظهر بنصيبه الفعلي تحت "أسعار فردية"
          // مباشرة (PricingHelper.monthlyDue بيحسب النصيب صح لأي عدد
          // أعضاء 2 أو 3، راجع specs/007-three-sibling-support)، فمفيش
          // داعي لتصنيف منفصل ممكن يبوّظ مع مجموعات الـ3.
          'pairs': const <double, int>{},
          'expected': expected,
          'paidCount': paidCount,
          'unpaidCount': applicableCount - paidCount,
          'paidAmount': paidAmount,
          'month': DateFormat('MMMM yyyy', 'ar').format(monthStart),
          'allowedTotal': applicableCount,
          'unpaidStudents': unpaidStudents,
        };
      }

      return StatefulBuilder(builder: (ctx, setSt) {
        return FutureBuilder<Map<String, dynamic>>(
          future: load(selected),
          builder: (context, snap) {
            final data = snap.data;
            final expected = (data?['expected'] as double?) ?? 0;
            final paidAmount = (data?['paidAmount'] as double?) ?? 0;
            final progress =
                expected > 0 ? (paidAmount / expected).clamp(0.0, 1.0) : 0.0;

            return AlertDialog(
              title: Row(children: [
                const Text('تفاصيل الرسوم'),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        initialDate: selected);
                    if (p != null)
                      setSt(() => selected = DateTime(p.year, p.month, 1));
                  },
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(data == null ? '...' : data['month']),
                ),
              ]),
              content: SizedBox(
                width: 480,
                height: 520,
                child: snap.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : Column(children: [
                        Row(children: [
                          Expanded(
                              child: Row(children: [
                            const Text('تحصيل: '),
                            CurrencyText(paidAmount),
                            const Text(' / '),
                            CurrencyText(expected),
                          ])),
                          const SizedBox(width: 8),
                          Text('${(progress * 100).toStringAsFixed(0)}%'),
                        ]),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                            value: expected > 0 ? progress : null,
                            minHeight: 6),
                        const SizedBox(height: 12),
                        Expanded(
                            child: SingleChildScrollView(
                                child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if ((data?['solo'] as Map<double, int>?)
                                    ?.isNotEmpty ??
                                false) ...[
                              Text('أسعار فردية',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...((data!['solo'] as Map<double, int>)
                                      .entries
                                      .toList()
                                    ..sort((a, b) => (b.key * b.value)
                                        .compareTo(a.key * a.value)))
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(children: [
                                          Expanded(
                                              child: Row(children: [
                                            Text('${e.value} طالب × '),
                                            CurrencyText(e.key)
                                          ])),
                                          CurrencyText(e.key * e.value),
                                        ]),
                                      )),
                              const SizedBox(height: 12),
                            ],
                            if ((data?['pairs'] as Map<double, int>?)
                                    ?.isNotEmpty ??
                                false) ...[
                              Text('عروض الإخوة',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...((data!['pairs'] as Map<double, int>)
                                      .entries
                                      .toList()
                                    ..sort((a, b) => (b.key * b.value)
                                        .compareTo(a.key * a.value)))
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(children: [
                                          Expanded(
                                              child: Row(children: [
                                            Text('${e.value} زوج × '),
                                            CurrencyText(e.key)
                                          ])),
                                          CurrencyText(e.key * e.value),
                                        ]),
                                      )),
                              const SizedBox(height: 12),
                            ],
                            Divider(color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      'مدفوع: ${data?['paidCount'] ?? 0}')),
                              Expanded(
                                  child: Text(
                                      'غير مدفوع: ${data?['unpaidCount'] ?? 0}')),
                            ]),
                            const SizedBox(height: 12),
                            if ((data?['unpaidStudents'] as List<Student>?)
                                    ?.isNotEmpty ??
                                false) ...[
                              Text('غير المدفوعين',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...((data!['unpaidStudents'] as List<Student>))
                                  .map((s) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(s.name),
                                        subtitle: Text('الكود: ${s.code}'),
                                        trailing: IconButton(
                                          icon: const Icon(
                                              Icons.message_rounded,
                                              color: Colors.green),
                                          onPressed: () async {
                                            await launchGuardianWhatsapp(
                                              context: context,
                                              phone: s.guardianPhone,
                                              whatsapp: s.guardianWhatsapp,
                                              message:
                                                  'تذكير برسوم شهر ${data['month']} للطالب ${s.name}.',
                                              dialCode:
                                                  settings.countryDial.value,
                                            );
                                          },
                                        ),
                                      )),
                            ],
                          ],
                        ))),
                      ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('إغلاق'))
              ],
            );
          },
        );
      });
    },
  );
}
