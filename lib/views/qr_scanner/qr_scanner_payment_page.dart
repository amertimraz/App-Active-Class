// lib/views/qr_scanner/qr_scanner_payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/controllers/session_log_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'qr_gallery_page.dart';

// ══════════════════════════════════════════════════════════════════
//  QRScannerPaymentPage
// ══════════════════════════════════════════════════════════════════
class QRScannerPaymentPage extends StatefulWidget {
  const QRScannerPaymentPage({super.key});

  @override
  State<QRScannerPaymentPage> createState() => _QRScannerPaymentPageState();
}

class _QRScannerPaymentPageState extends State<QRScannerPaymentPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late MobileScannerController scannerController;
  late final QRController controller;
  final GroupController groupController = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());
  late TabController _tabController;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Student> _searchResults = [];
  Student? _manualStudent;
  String? _lastScan;
  DateTime? _lastScanAt;
  final DatabaseService _db = DatabaseService();
  late final SessionLogController _session;
  bool _hideQr = false;

  @override
  void initState() {
    super.initState();
    _hideQr = Get.isRegistered<SettingsController>() &&
        Get.find<SettingsController>().hideQrInPayment.value;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _hideQr ? 1 : 0,
    );
    // الكاميرا لازم توقف لما نبعد عن تاب "مسح QR"، وإلا بتفضل شغالة
    // في الخلفية وممكن تمسك كود عشوائي أثناء البحث اليدوي وتعمل
    // تعارض (race) مع اختيار الطالب يدويًا عن طريق قفل isProcessing
    // بتاع QRController، فبيانات الطالب (الشهور) متظهرش صح.
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
    controller = Get.isRegistered<QRController>()
        ? Get.find<QRController>()
        : Get.put(QRController());
    controller.mode.value = QRMode.payment;
    _session = Get.find<SessionLogController>();
    // لو ماسح QR مخفي من الإعدادات، متشغّلش الكاميرا خالص.
    if (!_hideQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _safeStartScanner());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    scannerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── تشغيل/إيقاف الكاميرا بأمان ─────────────────────────────────
  // لما start()/stop() يتنادوا فوق بعض (مثلاً lifecycle resume بيحصل
  // في نفس لحظة تبديل التاب) بيرمي MobileScannerController استثناء
  // "still initializing" غير ملتقط، وده كان بيكسر الشاشة كلها. بنلف
  // النداءات دي عشان أي تعارض زمني يتجاهل بهدوء بدل ما يكسر الواجهة.
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

  // ── Search ───────────────────────────────────────────────────
  void _onSearch(String q) {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final lq = q.toLowerCase();
    setState(() {
      _searchResults = studentController.students
          .where((s) =>
              s.name.toLowerCase().contains(lq) ||
              s.code.toLowerCase().contains(lq))
          .toList();
    });
  }

  // ── Handle QR scan ───────────────────────────────────────────
  Future<void> _handle(String qr) async {
    if (controller.isProcessing.value) return;
    final now = DateTime.now();
    if (_lastScan == qr &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!).inMilliseconds < 1500) return;
    _lastScan = qr;
    _lastScanAt = now;
    await _safeStopScanner();
    await controller.handleScan(qr);
    if (!mounted) return;
    if (controller.scannedStudent.value == null) {
      // كود مش موجود
      HapticFeedback.vibrate();
      SoundHelper.scanError();
      _safeStartScanner();
    } else {
      HapticFeedback.selectionClick();
      SoundHelper.scanSuccess();
    }
  }

  // ── Confirm payment ──────────────────────────────────────────
  Future<void> _confirmPayment(Student student) async {
    if (student.siblingId != null && student.siblingsTotal != null) {
      final sib = await _db.getStudent(student.siblingId!);
      if (!mounted) return;
      final total = controller.totalAmount.value;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد عرض الإخوة'),
          content: Text(
              'سيتم تطبيق عرض الإخوة بين ${student.name} و ${sib?.name ?? "الأخ"}'
              ' بمبلغ إجمالي ${FormatHelper.formatCurrency(total)}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد')),
          ],
        ),
      );
      if (ok != true) return;
    }

    // بنلقط النوع والعدد قبل confirmPayment لأنها بتصفّر بيانات الطالب
    // (_clearPaymentState) بعد النجاح مباشرة.
    final isPerSession = controller.isPerSessionGroup;
    final monthCount = isPerSession
        ? controller.effectiveSessionsSelected
        : controller.selectedMonths.length;
    final amount = controller.totalAmount.value;
    final success = await controller.confirmPayment();
    if (!mounted) return;

    if (success) {
      // Haptic — heavy for success
      HapticFeedback.heavyImpact();

      // Add to session log (يبقى طوال اليوم)
      _session.add(SessionEntry(
        studentName: student.name,
        amount: amount,
        monthCount: monthCount,
        isPerSession: isPerSession,
        time: DateTime.now(),
        guardianPhone: student.guardianPhone,
      ));
      setState(() {
        _lastScan = null;
        _lastScanAt = null;
      });

      // Restart camera
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _safeStartScanner();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('تم تسجيل دفع: ${student.name}')),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } else {
      HapticFeedback.vibrate();
    }
  }

  // ── Override dialog ──────────────────────────────────────────
  Future<void> _showOverrideDialog() async {
    final total = controller.totalAmount.value;
    final amtCtrl = TextEditingController(text: total.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: controller.overrideNote.value);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل المبلغ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: Icon(Icons.attach_money_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'ملاحظة', prefixIcon: Icon(Icons.notes_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      final parsed = double.tryParse(amtCtrl.text.trim());
      if (parsed != null && parsed > 0) {
        controller.setOverride(amount: parsed, note: noteCtrl.text);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('قيمة غير صالحة')));
      }
    }
  }

  // ── Session log sheet ────────────────────────────────────────
  void _showSessionLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Obx(() => _SessionLogSheet(
            entries: _session.entries,
            total: _session.total,
            onShareWhatsApp: _shareWhatsApp,
            onClear: () {
              _session.clear();
              Navigator.pop(context);
            },
          )),
    );
  }

  // ── WhatsApp share ───────────────────────────────────────────
  Future<void> _shareWhatsApp() async {
    final entries = _session.entries;
    if (entries.isEmpty) return;
    final now = DateFormat('yyyy/MM/dd – HH:mm', 'ar').format(DateTime.now());
    final buf = StringBuffer();
    buf.writeln('📋 *ملخص جلسة الدفع*');
    buf.writeln('🗓 $now');
    buf.writeln('─────────────────');
    for (final e in entries.reversed) {
      final time = DateFormat('HH:mm').format(e.time);
      buf.writeln(
          '✅ ${e.studentName}  •  ${FormatHelper.formatCurrency(e.amount)}  ($time)');
    }
    buf.writeln('─────────────────');
    buf.writeln('👥 عدد الطلاب: ${entries.length}');
    buf.writeln('💰 الإجمالي: ${FormatHelper.formatCurrency(_session.total)}');

    final encoded = Uri.encodeComponent(buf.toString());
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('تسجيل الدفع',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Session counter badge
          Obx(() => _session.count > 0
              ? GestureDetector(
                  onTap: _showSessionLog,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${_session.count}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                  ),
                )
              : const SizedBox.shrink()),
          IconButton(
            tooltip: 'إدخال كود يدوياً',
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
            onPressed: () async {
              final c = TextEditingController();
              final code = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('أدخل كود الطالب'),
                  content: TextField(
                    controller: c,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'الكود', prefixIcon: Icon(Icons.qr_code)),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: const Text('تأكيد')),
                  ],
                ),
              );
              if (code != null && code.isNotEmpty) await _handle(code);
            },
          ),
          IconButton(
            tooltip: 'معرض QR',
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            onPressed: () => Get.to(() => const QrGalleryPage()),
          ),
        ],
        bottom: _hideQr
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accentColor,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(
                      icon: Icon(Icons.qr_code_scanner_rounded),
                      text: 'مسح QR'),
                  Tab(
                      icon: Icon(Icons.person_search_rounded),
                      text: 'بحث يدوي'),
                ],
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: _hideQr ? const NeverScrollableScrollPhysics() : null,
        children: [
          // ── QR Tab ─────────────────────────────────────────
          Column(
            children: [
              // Stats bar
              Obx(() => _session.count > 0
                  ? _SessionStatsBar(
                      count: _session.count,
                      total: _session.total,
                      onTap: _showSessionLog,
                    )
                  : const SizedBox.shrink()),
              // Camera
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: scannerController,
                      onDetect: (capture) {
                        for (final b in capture.barcodes) {
                          if (b.rawValue != null) _handle(b.rawValue!);
                        }
                      },
                      errorBuilder: (context, _) =>
                          _CameraError(onRetry: () => _safeStartScanner()),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(
                            color: Colors.black.withValues(alpha: 0.55)),
                      ),
                    ),
                    // Camera controls
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<MobileScannerState>(
                            valueListenable: scannerController,
                            builder: (_, state, __) {
                              final on = state.torchState == TorchState.on;
                              return _IconCircleBtn(
                                icon: on
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                label: on ? 'إطفاء' : 'إضاءة',
                                onTap: () => scannerController.toggleTorch(),
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          ValueListenableBuilder<MobileScannerState>(
                            valueListenable: scannerController,
                            builder: (_, __, ___) => _IconCircleBtn(
                              icon: Icons.flip_camera_android_rounded,
                              label: 'تبديل',
                              onTap: () => scannerController.switchCamera(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Result panel
              Expanded(
                flex: 4,
                child: Obx(() {
                  final student = controller.scannedStudent.value;
                  if (student == null) return _EmptyPanel();
                  if (student.isExempt) {
                    return _ExemptPanel(
                      student: student,
                      onClear: () {
                        controller.scannedStudent.value = null;
                        _lastScan = null;
                        _lastScanAt = null;
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) _safeStartScanner();
                        });
                      },
                    );
                  }
                  return _PaymentPanel(
                    student: student,
                    controller: controller,
                    db: _db,
                    onConfirm: () => _confirmPayment(student),
                    onOverride: _showOverrideDialog,
                    onClear: () {
                      controller.scannedStudent.value = null;
                      _safeStartScanner();
                    },
                  );
                }),
              ),
            ],
          ),

          // ── Manual Tab ─────────────────────────────────────
          _ManualTab(
            searchCtrl: _searchCtrl,
            searchResults: _searchResults,
            onSearch: _onSearch,
            groupController: groupController,
            manualStudent: _manualStudent,
            controller: controller,
            db: _db,
            session: _session,
            onShowLog: _showSessionLog,
            onSelectStudent: (s) async {
              await controller.handleScan(s.code);
              setState(() => _manualStudent = s);
            },
            onBack: () {
              controller.scannedStudent.value = null;
              setState(() => _manualStudent = null);
            },
            onConfirm: _confirmPayment,
            onOverride: _showOverrideDialog,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _SessionStatsBar  — شريط إحصائيات الجلسة
// ══════════════════════════════════════════════════════════════════
class _SessionStatsBar extends StatelessWidget {
  const _SessionStatsBar(
      {required this.count, required this.total, required this.onTap});
  final int count;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.green.shade800,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              '$count طالب دفعوا اليوم',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const Spacer(),
            Text(
              FormatHelper.formatCurrency(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
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
    required this.groupController,
    required this.manualStudent,
    required this.controller,
    required this.db,
    required this.session,
    required this.onShowLog,
    required this.onSelectStudent,
    required this.onBack,
    required this.onConfirm,
    required this.onOverride,
  });

  final TextEditingController searchCtrl;
  final List<Student> searchResults;
  final void Function(String) onSearch;
  final GroupController groupController;
  final Student? manualStudent;
  final QRController controller;
  final DatabaseService db;
  final SessionLogController session;
  final VoidCallback onShowLog;
  final Future<void> Function(Student) onSelectStudent;
  final VoidCallback onBack;
  final Future<void> Function(Student) onConfirm;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    if (manualStudent != null) {
      return Container(
        color: surface,
        child: Column(
          children: [
            Obx(() => session.count > 0
                ? _SessionStatsBar(
                    count: session.count,
                    total: session.total,
                    onTap: onShowLog)
                : const SizedBox.shrink()),
            Expanded(
              child: _PaymentPanel(
                student: manualStudent!,
                controller: controller,
                db: db,
                onConfirm: () => onConfirm(manualStudent!),
                onOverride: onOverride,
                onClear: onBack,
                showBackButton: true,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: surface,
      child: Column(
        children: [
          Obx(() => session.count > 0
              ? _SessionStatsBar(
                  count: session.count, total: session.total, onTap: onShowLog)
              : const SizedBox.shrink()),
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
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      final g = groupController.groups
                          .firstWhereOrNull((g) => g.id == s.groupId);
                      return _StudentSearchCard(
                          student: s,
                          group: g,
                          onSelect: () => onSelectStudent(s));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _PaymentPanel
// ══════════════════════════════════════════════════════════════════
class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.student,
    required this.controller,
    required this.db,
    required this.onConfirm,
    required this.onOverride,
    required this.onClear,
    this.showBackButton = false,
  });

  final Student student;
  final QRController controller;
  final DatabaseService db;
  final VoidCallback onConfirm;
  final VoidCallback onOverride;
  final VoidCallback onClear;
  final bool showBackButton;

  // حالة الدفع للشهر الحالي — لمجموعات "بالحصة" مفيش مفهوم "شهر مدفوع"
  // أصلاً، وأثناء تحميل بيانات المجموعة/الحضور مبنقولش أي استنتاج لحد
  // ما البيانات توصل بالكامل (راجع QRController.isPreparingPayment).
  String _paymentStatus() {
    if (controller.isPreparingPayment.value) return 'جارِ التحميل';
    if (controller.isPerSessionGroup) return 'بالحصة';
    final months = controller.upcomingMonths;
    if (months.isEmpty) return 'مدفوع بالكامل';
    final now = DateTime.now();
    final first = months.first;
    if (first.year == now.year && first.month == now.month) return 'لم يدفع';
    if (first.isAfter(now)) return 'متأخر';
    return 'مدفوع';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'لم يدفع':
        return Colors.red;
      case 'مدفوع بالكامل':
        return Colors.blue;
      case 'مدفوع':
        return Colors.green;
      case 'بالحصة':
        return Colors.teal;
      case 'جارِ التحميل':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'لم يدفع':
        return Icons.cancel_rounded;
      case 'مدفوع بالكامل':
        return Icons.check_circle_rounded;
      case 'مدفوع':
        return Icons.check_circle_rounded;
      case 'بالحصة':
        return Icons.flash_on_rounded;
      case 'جارِ التحميل':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _formatSessionDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'اليوم';
    if (date == yesterday) return 'إمبارح';
    return DateFormat('d MMMM', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Student info card ──────────────────────────────
            FutureBuilder<Group?>(
              future: db.getGroup(student.groupId),
              builder: (_, snap) {
                final group = snap.data;
                final groupColor = group?.color != null
                    ? Color(group!.color!)
                    : AppTheme.primaryColor;
                final isSiblings =
                    student.siblingId != null && student.siblingsTotal != null;
                final price = isSiblings
                    ? (student.siblingsTotal ?? student.price)
                    : student.price;

                return Obx(() {
                  final status = _paymentStatus();
                  final sColor = _statusColor(status);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: groupColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: groupColor.withValues(alpha: 0.3)),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: onSurface)),
                              Text(
                                '${group?.name ?? "—"}  •  ${FormatHelper.formatCurrency(price)} / ${group?.isPerSession == true ? "الحصة" : "شهر"}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: onSurface.withValues(alpha: 0.55)),
                              ),
                            ],
                          ),
                        ),
                        // Payment status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_statusIcon(status), size: 13, color: sColor),
                            const SizedBox(width: 4),
                            Text(status,
                                style: TextStyle(
                                    color: sColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                showBackButton
                                    ? Icons.arrow_back_rounded
                                    : Icons.close_rounded,
                                size: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                });
              },
            ),

            const SizedBox(height: 10),

            // ── Last paid ──────────────────────────────────────
            Obx(() => Row(children: [
                  Icon(Icons.history_rounded,
                      size: 13, color: onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'آخر دفع: ${controller.lastPaidMonthText}',
                      style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withValues(alpha: 0.5)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ])),

            const SizedBox(height: 10),

            // ── مجموعة بالحصة: مفيش "اختيار شهور" خالص — دفع حصة مباشرة ──
            // (Obx عشان تتحدّث فور ما بيانات المجموعة توصل من قاعدة
            // البيانات — مش قيمة المجموعة القديمة لطالب سابق).
            Obx(
              () => controller.isPreparingPayment.value
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : controller.isPerSessionGroup
                      ? Obx(() {
                          final fullyPaid = controller.fullyPaidUp;
                          final unpaid = controller.unpaidSessionsCount;
                          final count = controller.effectiveSessionsSelected;
                          final unpaidDates = controller.unpaidSessionDates;
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final includesToday = unpaidDates.contains(today);
                          final color = fullyPaid ? Colors.grey : Colors.teal;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // لو فيه أكتر من حصة متأخرة، بنسيب المدرس يختار
                              // كام حصة يدفع دلوقتي بدل ما يكون إجباري يدفعهم
                              // كلهم مع بعض (زي ولي أمر جاي يدفع حصة واحدة بس).
                              if (!fullyPaid && unpaid > 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('عدد الحصص المدفوعة دلوقتي:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: onSurface.withValues(
                                                  alpha: 0.6))),
                                      const SizedBox(width: 8),
                                      _StepperBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: count > 1
                                            ? () => controller
                                                .setSessionsToPay(count - 1)
                                            : null,
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.teal
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('$count',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal)),
                                      ),
                                      _StepperBtn(
                                        icon: Icons.add_rounded,
                                        onTap: count < unpaid
                                            ? () => controller
                                                .setSessionsToPay(count + 1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              GestureDetector(
                                onTap: fullyPaid
                                    ? null
                                    : controller.payAllUnpaidSessions,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          fullyPaid
                                              ? Icons.check_circle_rounded
                                              : Icons.flash_on_rounded,
                                          size: 16,
                                          color: color),
                                      const SizedBox(width: 6),
                                      Text(
                                        fullyPaid
                                            ? 'تم تسجيل دفعة لكل الحصص المستحقة'
                                            : count > 1
                                                ? 'دفع $count حصص (${FormatHelper.formatCurrency(student.price * count)})'
                                                : includesToday
                                                    ? 'دفع حصة اليوم (${FormatHelper.formatCurrency(student.price)})'
                                                    : 'دفع حصة متأخرة (${FormatHelper.formatCurrency(student.price)})',
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // توضيح تاريخ الحصة/الحصص المستحقة بالظبط — عشان
                              // المدرس ميفتكرش إن "حصة واحدة مستحقة" معناها
                              // بالضرورة حصة النهاردة لو الطالب كان غايب اليوم
                              // وليه حصة متأخرة من يوم قبل كده.
                              if (!fullyPaid && unpaidDates.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'الحصص المستحقة: ${unpaidDates.map(_formatSessionDateLabel).join('، ')}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            onSurface.withValues(alpha: 0.5)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          );
                        })
                      : Obx(() {
                          final months = controller.upcomingMonths;
                          final selected = controller.selectedMonths;

                          if (months.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.blue, size: 16),
                                SizedBox(width: 8),
                                Text('مدفوع بالكامل لهذا الشهر',
                                    style: TextStyle(
                                        color: Colors.blue, fontSize: 13)),
                              ]),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with Quick Pay button
                              Row(
                                children: [
                                  Text('اختر الشهور',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: onSurface)),
                                  const Spacer(),
                                  // Quick Pay — الشهر الحالي فوراً
                                  GestureDetector(
                                    onTap: () {
                                      controller.selectFirstMonth();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.green
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.bolt_rounded,
                                                size: 14, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text('هذا الشهر فقط',
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Select all
                                  GestureDetector(
                                    onTap: () => controller.selectAllUpcoming(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.done_all_rounded,
                                                size: 14,
                                                color: AppTheme.primaryColor),
                                            const SizedBox(width: 4),
                                            Text('الكل',
                                                style: TextStyle(
                                                    color:
                                                        AppTheme.primaryColor,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: months.map((m) {
                                  final isSel = selected.any((s) =>
                                      s.year == m.year && s.month == m.month);
                                  final label =
                                      DateFormat('MMM yyyy', 'ar').format(m);
                                  return _MonthChip(
                                      label: label,
                                      selected: isSel,
                                      onTap: () => controller.toggleMonth(m));
                                }).toList(),
                              ),
                            ],
                          );
                        }),
            ),

            const SizedBox(height: 10),

            // ── Sibling info ───────────────────────────────────
            if (student.siblingId != null && student.siblingsTotal != null)
              Obx(() {
                final total = controller.totalAmount.value;
                return FutureBuilder<Student?>(
                  future: DatabaseService().getStudent(student.siblingId!),
                  builder: (_, snap) {
                    final sibName = snap.data?.name ?? '—';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.family_restroom_rounded,
                            color: Colors.purple, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'عرض الإخوة مع: $sibName  •  نصيب كل: ${FormatHelper.formatCurrency(total / 2)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.purple),
                          ),
                        ),
                      ]),
                    );
                  },
                );
              }),

            // ── Total + override ───────────────────────────────
            Obx(() {
              final total = controller.totalAmount.value;
              final hasOverride = controller.overrideAmount.value != null;
              final selectedCount = controller.selectedMonths.length;
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الإجمالي',
                            style: TextStyle(
                                fontSize: 11,
                                color: onSurface.withValues(alpha: 0.5))),
                        Text(
                          FormatHelper.formatCurrency(total),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppTheme.primaryColor),
                        ),
                        if (selectedCount > 0)
                          Text(
                              controller.isPerSessionGroup
                                  ? '${controller.effectiveSessionsSelected} حصة'
                                  : '$selectedCount شهر',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                    const Spacer(),
                    if (hasOverride)
                      TextButton(
                        onPressed: () =>
                            controller.setOverride(amount: null, note: ''),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('إعادة تعيين',
                            style: TextStyle(fontSize: 11)),
                      ),
                    OutlinedButton.icon(
                      onPressed: onOverride,
                      icon: const Icon(Icons.edit_rounded, size: 13),
                      label:
                          const Text('تعديل', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              );
            }),

            // Override note
            Obx(() {
              if (controller.overrideNote.value.isEmpty)
                return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.notes_rounded,
                      size: 13, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(controller.overrideNote.value,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange)),
                  ),
                ]),
              );
            }),

            const SizedBox(height: 12),

            // ── Confirm button ─────────────────────────────────
            Obx(() {
              final selectedCount = controller.selectedMonths.length;
              final processing = controller.isProcessing.value;
              final blockedNoSessions = controller.isPerSessionGroup &&
                  controller.selectedSessionsCount == 0 &&
                  controller.overrideAmount.value == null;
              final blockedAlreadyPaid = controller.fullyPaidUp;
              // بالحصة لازم يتحدد المبلغ عن طريق "دفع الحصص المستحقة" الأول —
              // التأكيد المباشر من غيره ممكن يحسب إجمالي كل حصص الشهر
              // تاني من غير ما يخصم أي دفعات سابقة (راجع QRController.confirmPayment).
              final needsQuickPayFirst = controller.isPerSessionGroup &&
                  controller.overrideAmount.value == null &&
                  !blockedNoSessions &&
                  !blockedAlreadyPaid;
              final canConfirm = selectedCount > 0 &&
                  !processing &&
                  !blockedNoSessions &&
                  !blockedAlreadyPaid &&
                  !needsQuickPayFirst;
              return SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canConfirm
                        ? AppTheme.primaryColor
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: canConfirm ? onConfirm : null,
                  icon: processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.payments_rounded, size: 18),
                  label: Text(
                    processing
                        ? 'جاري التسجيل...'
                        : blockedAlreadyPaid
                            ? 'تم تسجيل دفعة لكل الحصص المستحقة'
                            : blockedNoSessions
                                ? 'لسه متسجلش حضور لأي حصة'
                                : needsQuickPayFirst
                                    ? 'اضغط "دفع الحصص المستحقة" الأول'
                                    : selectedCount > 0
                                        ? controller.isPerSessionGroup
                                            ? 'تأكيد الدفع  (${controller.effectiveSessionsSelected} حصة)'
                                            : 'تأكيد الدفع  ($selectedCount شهر)'
                                        : controller.isPerSessionGroup
                                            ? 'اضغط دفع حصة اليوم'
                                            : 'اختر شهراً للدفع',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _SessionLogSheet  — سجل جلسة الدفع
// ══════════════════════════════════════════════════════════════════
class _SessionLogSheet extends StatelessWidget {
  const _SessionLogSheet({
    required this.entries,
    required this.total,
    required this.onShareWhatsApp,
    required this.onClear,
  });

  final List<SessionEntry> entries;
  final double total;
  final VoidCallback onShareWhatsApp;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final timeFmt = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سجل جلسة الدفع',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '${entries.length} طالب  •  ${FormatHelper.formatCurrency(total)}',
                          style: const TextStyle(
                              color: Colors.green,
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
                ],
              ),
            ),
            const Divider(height: 1),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShareWhatsApp,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('مشاركة واتساب'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('مسح'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text('لا توجد دفعات في هذه الجلسة',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    e.studentName.isNotEmpty
                                        ? e.studentName[0]
                                        : '؟',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.studentName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                      '${e.monthCount} ${e.isPerSession ? "حصة" : "شهر"}  •  ${timeFmt.format(e.time)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                FormatHelper.formatCurrency(e.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Small widgets
// ══════════════════════════════════════════════════════════════════

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16, color: enabled ? Colors.teal : Colors.grey.shade400),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: selected ? Colors.white : AppTheme.primaryColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.primaryColor,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    );
  }
}

class _StudentSearchCard extends StatelessWidget {
  const _StudentSearchCard(
      {required this.student, required this.group, required this.onSelect});
  final Student student;
  final Group? group;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final groupColor =
        group?.color != null ? Color(group!.color!) : AppTheme.primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                '${student.code}  ·  ${group?.name ?? "—"}',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
              ),
            ]),
          ),
          ElevatedButton(
            onPressed: onSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: groupColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('اختيار', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
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
            child: Icon(Icons.qr_code_scanner_rounded,
                size: 38, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            'وجّه الكاميرا نحو كود QR الطالب',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 5),
          Text(
            'سيظهر ملخص الدفع هنا فور المسح',
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
          hasQuery ? 'لم يُعثر على نتائج' : 'ابحث عن طالب لتسجيل الدفع',
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
        const Icon(Icons.error_outline_rounded,
            size: 44, color: Colors.white54),
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
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _ExemptPanel — بطاقة الطالب المعفى من الرسوم
// ══════════════════════════════════════════════════════════════════
class _ExemptPanel extends StatelessWidget {
  const _ExemptPanel({required this.student, required this.onClear});
  final Student student;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const exemptColor = Color(0xFF2E7D32);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: exemptColor.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
        border:
            Border.all(color: exemptColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: exemptColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: exemptColor.withValues(alpha: 0.4), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.volunteer_activism_rounded,
                  color: exemptColor, size: 34),
            ),
          ),
          const SizedBox(height: 14),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: exemptColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              student.isFullyExempt
                  ? 'معفى من الرسوم كلياً'
                  : 'معفى ${student.exemptPercent.toInt()}% من الرسوم',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Student name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              student.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            student.code,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          // Reason card
          if (student.exemptReason != null &&
              student.exemptReason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: exemptColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: exemptColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: exemptColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'السبب: ${student.exemptReason}',
                    style: const TextStyle(
                      color: exemptColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Effective price note if partial
          if (!student.isFullyExempt) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                'السعر بعد الخصم: ${FormatHelper.formatCurrency(student.effectivePrice)}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const Spacer(),
          // Clear button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: exemptColor,
                  side: BorderSide(color: exemptColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onClear,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('سكان طالب آخر'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Scanner overlay painter
// ══════════════════════════════════════════════════════════════════
class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  _ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * 0.65;
    final left = (size.width - s) / 2;
    final top = (size.height - s) / 2.2;
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
    // Corner lines
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
    canvas.drawLine(
        Offset(left + s - len, top + s), Offset(left + s, top + s), p);
    canvas.drawLine(
        Offset(left + s, top + s - len), Offset(left + s, top + s), p);
    canvas.drawLine(Offset(left + len, top + s), Offset(left, top + s), p);
    canvas.drawLine(Offset(left, top + s - len), Offset(left, top + s), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
