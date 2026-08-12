// lib/views/qr_scanner/qr_scanner_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/utils/helpers.dart';

// ══════════════════════════════════════════════════════════════════
//  QRScannerAttendancePage
// ══════════════════════════════════════════════════════════════════
class QRScannerAttendancePage extends StatefulWidget {
  const QRScannerAttendancePage({super.key});

  @override
  State<QRScannerAttendancePage> createState() =>
      _QRScannerAttendancePageState();
}

class _QRScannerAttendancePageState extends State<QRScannerAttendancePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late MobileScannerController scannerController;
  late final QRController qrCtrl;
  final AttendanceController attCtrl =
      Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>()
          : Get.put(AttendanceController());
  final GroupController groupCtrl   = Get.put(GroupController());
  final StudentController stuCtrl   = Get.put(StudentController());
  late TabController _tabController;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Student> _searchResults = [];
  Student? _manualStudent;
  String? _lastScan;
  DateTime? _lastScanAt;
  bool _hideQr = false;

  @override
  void initState() {
    super.initState();
    _hideQr = Get.isRegistered<SettingsController>() &&
        Get.find<SettingsController>().hideQrInAttendance.value;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _hideQr ? 1 : 0,
    );
    // نفس منطق شاشة الدفع: نوقف الكاميرا لما نبعد عن تاب "مسح QR"
    // عشان متفضلش شغالة في الخلفية وتتعارض مع البحث اليدوي.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 0 && !_hideQr) {
        _safeStartScanner();
      } else {
        _safeStopScanner();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    scannerController = MobileScannerController(autoStart: false);
    qrCtrl = Get.isRegistered<QRController>()
        ? Get.find<QRController>()
        : Get.put(QRController());
    qrCtrl.mode.value = QRMode.attendance;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await stuCtrl.loadAllStudents();
      await groupCtrl.loadGroups();
      await attCtrl.loadAttendance();
      attCtrl.buildStudentMaps(stuCtrl.students);
      if (!_hideQr) _safeStartScanner();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    scannerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── تشغيل/إيقاف الكاميرا بأمان (نفس إصلاح شاشة الدفع) ───────────
  Future<void> _safeStartScanner() async {
    try {
      await scannerController.start();
    } catch (_) {}
  }

  Future<void> _safeStopScanner() async {
    try {
      await scannerController.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _safeStopScanner();
    if (state == AppLifecycleState.resumed && !_hideQr) _safeStartScanner();
  }

  // ── Search ───────────────────────────────────────────────────────
  void _onSearch(String q) {
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    final lq = q.toLowerCase();
    setState(() {
      _searchResults = stuCtrl.students
          .where((s) =>
              s.name.toLowerCase().contains(lq) ||
              s.code.toLowerCase().contains(lq))
          .toList();
    });
  }

  // ── Handle QR scan ───────────────────────────────────────────────
  Future<void> _handleQR(String qr) async {
    if (qrCtrl.isProcessing.value) return;
    final now = DateTime.now();
    if (_lastScan == qr &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!).inMilliseconds < 1500) return;
    _lastScan   = qr;
    _lastScanAt = now;
    await _safeStopScanner();
    await qrCtrl.handleScan(qr);
    if (!mounted) return;

    if (qrCtrl.scannedStudent.value == null) {
      HapticFeedback.vibrate();
      _safeStartScanner();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  // ── Confirm attendance from QR tab (وكذلك التبويب اليدوي) ────────
  // بيحدد الحالة المستهدفة حسب حالة اليوم الحالية (حاضر → غائب، وأي
  // حالة تانية → حاضر) بدل استخدام toggleAttendance اللي بتدور على
  // 3 حالات (حاضر/غائب/حذف) وكانت بتدّي رسالة "تم تسجيل حضور" غلط
  // لما الطالب يتحول من حاضر لغائب.
  Future<void> _confirmAttendance(Student student) async {
    final today = _todayStart();
    final record = attCtrl.attendance.firstWhereOrNull((a) =>
        a.studentId == student.id &&
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day);
    final targetStatus = record?.status == ATTENDANCE_PRESENT
        ? ATTENDANCE_ABSENT
        : ATTENDANCE_PRESENT;

    try {
      await attCtrl.setAttendanceStatus(student.id!, DateTime.now(), targetStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل تسجيل الحضور — حاول تاني'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    // Reset for next scan
    qrCtrl.scannedStudent.value = null;
    setState(() { _lastScan = null; _lastScanAt = null; });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _safeStartScanner();

    if (!mounted) return;
    final isPresent = targetStatus == ATTENDANCE_PRESENT;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(isPresent
              ? 'تم تسجيل حضور: ${student.name}'
              : 'تم تسجيل غياب: ${student.name}'),
        ),
      ]),
      backgroundColor:
          isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('تسجيل الحضور بـ QR',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Badge عدد الحاضرين اليوم
          Obx(() {
            final today = _todayStart();
            final count = attCtrl.attendance
                .where((a) =>
                    a.status == ATTENDANCE_PRESENT &&
                    a.date.year == today.year &&
                    a.date.month == today.month &&
                    a.date.day == today.day)
                .length;
            if (count == 0) return const SizedBox.shrink();
            return GestureDetector(
              onTap: _showSessionSheet,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
              ),
            );
          }),
          // إدخال كود يدوياً
          IconButton(
            tooltip: 'إدخال كود يدوياً',
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
            onPressed: () async {
              final c = TextEditingController();
              final code = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('أدخل كود الطالب'),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'الكود', prefixIcon: Icon(Icons.qr_code)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: const Text('تأكيد')),
                  ],
                ),
              );
              if (code != null && code.isNotEmpty) await _handleQR(code);
            },
          ),
        ],
        bottom: _hideQr
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF10B981),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'مسح QR'),
                  Tab(icon: Icon(Icons.person_search_rounded),   text: 'بحث يدوي'),
                ],
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: _hideQr ? const NeverScrollableScrollPhysics() : null,
        children: [
          // ── QR Tab ─────────────────────────────────────────────
          Column(children: [
            // شريط الإحصاء
            Obx(() {
              final today = _todayStart();
              final count = attCtrl.attendance
                  .where((a) =>
                      a.status == ATTENDANCE_PRESENT &&
                      a.date.year == today.year &&
                      a.date.month == today.month &&
                      a.date.day == today.day)
                  .length;
              if (count == 0) return const SizedBox.shrink();
              return _AttendanceStatsBar(count: count, onTap: _showSessionSheet);
            }),
            // الكاميرا
            Expanded(
              flex: 5,
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue != null) _handleQR(b.rawValue!);
                    }
                  },
                  errorBuilder: (_, __) => _CameraError(
                    onRetry: () => _safeStartScanner(),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(
                        color: Colors.black.withValues(alpha: 0.55)),
                  ),
                ),
                // أزرار الكاميرا
                Positioned(
                  bottom: 12, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: scannerController,
                        builder: (_, state, __) {
                          final on = state.torchState == TorchState.on;
                          return _IconCircleBtn(
                            icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            label: on ? 'إطفاء' : 'إضاءة',
                            onTap: () => scannerController.toggleTorch(),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      _IconCircleBtn(
                        icon: Icons.flip_camera_android_rounded,
                        label: 'تبديل',
                        onTap: () => scannerController.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            // بانيل نتيجة المسح
            Expanded(
              flex: 4,
              child: Obx(() {
                final student = qrCtrl.scannedStudent.value;
                if (student == null) return const _EmptyPanel();
                return _AttendancePanel(
                  student: student,
                  groupCtrl: groupCtrl,
                  attCtrl: attCtrl,
                  onConfirm: () => _confirmAttendance(student),
                  onClear: () {
                    qrCtrl.scannedStudent.value = null;
                    _lastScan = null;
                    _lastScanAt = null;
                    Future.delayed(const Duration(milliseconds: 200),
                        () { if (mounted) _safeStartScanner(); });
                  },
                );
              }),
            ),
          ]),

          // ── Manual Tab ─────────────────────────────────────────
          _ManualTab(
            searchCtrl:    _searchCtrl,
            searchResults: _searchResults,
            onSearch:      _onSearch,
            groupCtrl:     groupCtrl,
            attCtrl:       attCtrl,
            manualStudent: _manualStudent,
            onSelectStudent: (s) async {
              await qrCtrl.handleScan(s.code);
              setState(() => _manualStudent = s);
            },
            onBack: () {
              qrCtrl.scannedStudent.value = null;
              setState(() => _manualStudent = null);
            },
            onConfirm: (s) async {
              await _confirmAttendance(s);
              if (!mounted) return;
              setState(() => _manualStudent = null);
            },
          ),
        ],
      ),
    );
  }

  // ── Session bottom sheet ─────────────────────────────────────────
  void _showSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Obx(() {
        final today = _todayStart();
        final entries = attCtrl.attendance
            .where((a) =>
                a.status == ATTENDANCE_PRESENT &&
                a.date.year == today.year &&
                a.date.month == today.month &&
                a.date.day == today.day)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return _SessionSheet(
            entries: entries, students: stuCtrl.students, groups: groupCtrl.groups);
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _AttendanceStatsBar
// ══════════════════════════════════════════════════════════════════
class _AttendanceStatsBar extends StatelessWidget {
  const _AttendanceStatsBar({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF065F46),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '$count طالب حضروا اليوم',
            style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const Spacer(),
          const Text('عرض الكل',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white70, size: 16),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _AttendancePanel — يظهر بعد المسح الناجح
// ══════════════════════════════════════════════════════════════════
class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({
    required this.student,
    required this.groupCtrl,
    required this.attCtrl,
    required this.onConfirm,
    required this.onClear,
  });
  final Student           student;
  final GroupController   groupCtrl;
  final AttendanceController attCtrl;
  final VoidCallback      onConfirm;
  final VoidCallback      onClear;

  @override
  Widget build(BuildContext context) {
    final surface  = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final group = groupCtrl.groups.firstWhereOrNull((g) => g.id == student.groupId);
    final groupColor = group?.color != null
        ? Color(group!.color!)
        : AppTheme.primaryColor;

    return Obx(() {
      final today2   = _todayStart();
      final record   = attCtrl.attendance.firstWhereOrNull((a) =>
          a.studentId == student.id &&
          a.date.year == today2.year &&
          a.date.month == today2.month &&
          a.date.day == today2.day);
      final isPresent = record?.status == ATTENDANCE_PRESENT;
      final isAbsent  = record?.status == ATTENDANCE_ABSENT;

      return Container(
        color: surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── بطاقة الطالب ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: groupColor.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: groupColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        student.name.isNotEmpty ? student.name[0] : '؟',
                        style: TextStyle(
                            color: groupColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: onSurface)),
                        Text(
                          '${group?.name ?? "—"}  •  ${student.code}',
                          style: TextStyle(
                              fontSize: 11,
                              color: onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                  // حالة اليوم
                  if (isPresent || isAbsent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isPresent
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: (isPresent
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isPresent
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 13,
                          color: isPresent
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPresent ? 'حاضر' : 'غائب',
                          style: TextStyle(
                              color: isPresent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── حالة اليوم ──────────────────────────────────────
              if (isPresent)
                _InfoBanner(
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  text: 'تم تسجيل الحضور اليوم',
                  subText: record != null
                      ? 'في ${FormatHelper.formatTime(record.date)}'
                      : null,
                )
              else if (isAbsent)
                _InfoBanner(
                  icon: Icons.cancel_rounded,
                  color: const Color(0xFFEF4444),
                  text: 'مسجّل غائب اليوم',
                  subText: 'اضغط "تسجيل" لتغيير الحالة',
                ),

              const SizedBox(height: 10),

              // ── زر التسجيل ──────────────────────────────────────
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPresent
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onConfirm,
                  icon: Icon(
                    isPresent
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isPresent
                        ? 'تغيير إلى غائب'
                        : isAbsent
                            ? 'تغيير إلى حاضر'
                            : 'تسجيل حضور',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),

              if (!isPresent && !isAbsent) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    try {
                      await attCtrl.setAttendanceStatus(
                          student.id!, DateTime.now(), ATTENDANCE_ABSENT);
                      onClear();
                    } catch (e) {
                      ToastHelper.error('فشل تسجيل الغياب — حاول تاني');
                    }
                  },
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  label: const Text('تسجيل غياب',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════
//  _ManualTab
// ══════════════════════════════════════════════════════════════════
class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.searchCtrl,
    required this.searchResults,
    required this.onSearch,
    required this.groupCtrl,
    required this.attCtrl,
    required this.manualStudent,
    required this.onSelectStudent,
    required this.onBack,
    required this.onConfirm,
  });
  final TextEditingController searchCtrl;
  final List<Student>         searchResults;
  final void Function(String) onSearch;
  final GroupController       groupCtrl;
  final AttendanceController  attCtrl;
  final Student?              manualStudent;
  final Future<void> Function(Student) onSelectStudent;
  final VoidCallback          onBack;
  final Future<void> Function(Student) onConfirm;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    if (manualStudent != null) {
      return Container(
        color: surface,
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Text('تسجيل الحضور',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ]),
          ),
          Expanded(
            child: _AttendancePanel(
              student:    manualStudent!,
              groupCtrl:  groupCtrl,
              attCtrl:    attCtrl,
              onConfirm:  () => onConfirm(manualStudent!),
              onClear:    onBack,
            ),
          ),
        ]),
      );
    }

    return Container(
      color: surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الطالب أو الكود...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () { searchCtrl.clear(); onSearch(''); })
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            onChanged: onSearch,
          ),
        ),
        Expanded(
          child: searchResults.isEmpty
              ? _SearchEmpty(hasQuery: searchCtrl.text.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: searchResults.length,
                  itemBuilder: (_, i) {
                    final s = searchResults[i];
                    final g = groupCtrl.groups
                        .firstWhereOrNull((g) => g.id == s.groupId);
                    return _StudentSearchCard(
                        student: s, group: g, attCtrl: attCtrl,
                        onSelect: () => onSelectStudent(s));
                  },
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _SessionSheet — سجل الحاضرين اليوم
// ══════════════════════════════════════════════════════════════════
class _SessionSheet extends StatelessWidget {
  const _SessionSheet({
    required this.entries,
    required this.students,
    required this.groups,
  });
  final List entries;
  final List<Student> students;
  final List<Group>   groups;

  @override
  Widget build(BuildContext context) {
    final surface  = Theme.of(context).colorScheme.surface;
    final timeFmt  = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => Column(children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.how_to_reg_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الحاضرون اليوم',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      '${entries.length} طالب',
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('لا يوجد حضور مسجّل اليوم',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final att = entries[i];
                      final s   = students.firstWhereOrNull(
                          (st) => st.id == att.studentId);
                      final g   = groups.firstWhereOrNull(
                          (gr) => gr.id == s?.groupId);
                      final initial = s?.name.isNotEmpty == true
                          ? s!.name[0]
                          : '؟';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s?.name ?? 'طالب',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                  '${g?.name ?? "—"}  •  ${timeFmt.format(att.date)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981), size: 18),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Small widgets
// ══════════════════════════════════════════════════════════════════

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(
      {required this.icon, required this.color, required this.text, this.subText});
  final IconData icon;
  final Color    color;
  final String   text;
  final String?  subText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              if (subText != null)
                Text(subText!,
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ]),
    );
  }
}

class _StudentSearchCard extends StatelessWidget {
  const _StudentSearchCard({
    required this.student,
    required this.group,
    required this.attCtrl,
    required this.onSelect,
  });
  final Student              student;
  final Group?               group;
  final AttendanceController attCtrl;
  final VoidCallback         onSelect;

  @override
  Widget build(BuildContext context) {
    final groupColor = group?.color != null
        ? Color(group!.color!)
        : AppTheme.primaryColor;

    final today = _todayStart();
    final record = attCtrl.attendance.firstWhereOrNull((a) =>
        a.studentId == student.id &&
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day);
    final isPresent = record?.status == ATTENDANCE_PRESENT;
    final isAbsent  = record?.status == ATTENDANCE_ABSENT;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : isAbsent
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: Center(
            child: Text(
              student.name.isNotEmpty ? student.name[0] : '؟',
              style: TextStyle(
                  color: groupColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(student.name,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Row(children: [
              Text(
                '${student.code}  ·  ${group?.name ?? "—"}',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
              ),
              if (isPresent || isAbsent) ...[
                const SizedBox(width: 6),
                Icon(
                  isPresent
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 12,
                  color: isPresent
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 2),
                Text(
                  isPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPresent
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                ),
              ],
            ]),
          ]),
        ),
        ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(
            backgroundColor: isPresent
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            isPresent ? 'تغيير' : 'تسجيل',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                size: 38, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            'وجّه الكاميرا نحو كود QR الطالب',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 5),
          Text(
            'سيظهر تأكيد الحضور فور المسح',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
          ),
        ]),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_search_rounded,
            size: 60, color: Colors.grey.withValues(alpha: 0.25)),
        const SizedBox(height: 10),
        Text(
          hasQuery ? 'لم يُعثر على نتائج' : 'ابحث عن طالب لتسجيل حضوره',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ]),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 44, color: Colors.white54),
        const SizedBox(height: 10),
        const Text('تعذّر الوصول للكاميرا',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ]),
    );
  }
}

class _IconCircleBtn extends StatelessWidget {
  const _IconCircleBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Scanner overlay painter (نفس صفحة الدفع)
// ══════════════════════════════════════════════════════════════════
class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  _ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s    = size.shortestSide * 0.65;
    final left = (size.width - s) / 2;
    final top  = (size.height - s) / 2.2;
    final hole = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, s, s), const Radius.circular(20));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(hole),
      ),
      Paint()..color = color,
    );
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const len = 22.0;
    canvas.drawLine(Offset(left + s - len, top), Offset(left + s, top), p);
    canvas.drawLine(Offset(left + s, top), Offset(left + s, top + len), p);
    canvas.drawLine(Offset(left + len, top), Offset(left, top), p);
    canvas.drawLine(Offset(left, top), Offset(left, top + len), p);
    canvas.drawLine(Offset(left + s - len, top + s), Offset(left + s, top + s), p);
    canvas.drawLine(Offset(left + s, top + s - len), Offset(left + s, top + s), p);
    canvas.drawLine(Offset(left + len, top + s), Offset(left, top + s), p);
    canvas.drawLine(Offset(left, top + s - len), Offset(left, top + s), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Date helper ───────────────────────────────────────────────────
DateTime _todayStart() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
