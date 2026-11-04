// lib/views/qr_scanner/qr_scanner_payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/constants.dart';
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
import 'package:active_class/utils/hardware_scan_buffer.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/hardware_reader_widgets.dart';
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

  // ── جهاز قارئ باركود خارجي (HID) — spec 027 ──────────────────────
  bool _hardwareEnabled = false;
  bool _pureScannerMode = false;
  bool _qrTabVisible = true;
  HardwareScanBuffer? _scanBuffer;
  DateTime? _lastHardwareScanAt;

  @override
  void initState() {
    super.initState();
    _hideQr = Get.isRegistered<SettingsController>() &&
        Get.find<SettingsController>().hideQrInPayment.value;
    _hardwareEnabled = Get.isRegistered<SettingsController>() &&
        Get.find<SettingsController>().hardwareScannerEnabled.value;
    _pureScannerMode = _hardwareEnabled && _hideQr;
    _qrTabVisible = !_hideQr || _pureScannerMode;
    if (_hardwareEnabled) {
      _scanBuffer = HardwareScanBuffer(onScan: (code) => _handle(code, fromHardware: true));
      HardwareKeyboard.instance.addHandler(_hwKeyHandler);
    }
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _qrTabVisible ? 0 : 1,
    );
    // الكاميرا لازم توقف لما نبعد عن تاب "مسح QR"، وإلا بتفضل شغالة
    // في الخلفية وممكن تمسك كود عشوائي أثناء البحث اليدوي وتعمل
    // تعارض (race) مع اختيار الطالب يدويًا عن طريق قفل isProcessing
    // بتاع QRController، فبيانات الطالب (الشهور) متظهرش صح.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _scanBuffer?.reset();
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
    _hydrateSessionFromToday();
    // لو ماسح QR مخفي من الإعدادات، متشغّلش الكاميرا خالص.
    if (!_hideQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _safeStartScanner());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_hardwareEnabled) HardwareKeyboard.instance.removeHandler(_hwKeyHandler);
    _scanBuffer?.dispose();
    scannerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── ملء سجل الجلسة من دفعات النهاردة الفعلية (مرة واحدة كل تشغيل) ──
  Future<void> _hydrateSessionFromToday() async {
    try {
      final all = await _db.getAllPayments();
      final now = DateTime.now();
      final today = all
          .where((p) =>
              p.date.year == now.year &&
              p.date.month == now.month &&
              p.date.day == now.day &&
              // spec 038 — إسقاط المديونية مش دفعة فعلية، فمالوش مكان في
              // "دفعوا اليوم" ولا إجمالي جلسة الدفع ولا مشاركة واتساب.
              p.note != kDebtWriteOffNote)
          .toList();
      if (today.isEmpty) {
        _session.hydrateOnce(const []);
        return;
      }
      final byId = {
        for (final s in studentController.students) s.id: s,
      };
      final entries = today.map((p) {
        final s = byId[p.studentId];
        final note = p.note ?? '';
        final monthsPart =
            note.split(';').firstWhere((e) => e.startsWith('months='), orElse: () => '');
        final monthCount = monthsPart.isEmpty
            ? 1
            : monthsPart.substring(7).split(',').where((e) => e.trim().isNotEmpty).length;
        return SessionEntry(
          studentName: s?.name ?? 'طالب',
          amount: p.amount,
          monthCount: monthCount < 1 ? 1 : monthCount,
          time: p.date,
          guardianPhone: s?.guardianPhone,
          paymentId: p.id,
        );
      }).toList()
        ..sort((a, b) => b.time.compareTo(a.time));
      _session.hydrateOnce(entries);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ── تشغيل/إيقاف الكاميرا بأمان ─────────────────────────────────
  // لما start()/stop() يتنادوا فوق بعض (مثلاً lifecycle resume بيحصل
  // في نفس لحظة تبديل التاب) بيرمي MobileScannerController استثناء
  // "still initializing" غير ملتقط، وده كان بيكسر الشاشة كلها. بنلف
  // النداءات دي عشان أي تعارض زمني يتجاهل بهدوء بدل ما يكسر الواجهة.
  Future<void> _safeStartScanner() async {
    if (_pureScannerMode) return;
    try {
      await scannerController.start();
    } catch (_) {}
  }

  Future<void> _safeStopScanner() async {
    if (_pureScannerMode) return;
    try {
      await scannerController.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _safeStopScanner();
      _scanBuffer?.reset();
    }
    if (state == AppLifecycleState.resumed) {
      _scanBuffer?.reset();
      if (!_hideQr) _safeStartScanner();
    }
  }

  bool _hwKeyHandler(KeyEvent event) {
    if (!mounted || _scanBuffer == null) return false;
    if (_tabController.index != 0) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    // لو المدرّس بيكتب في حقل (زي حقل "ادفع مبلغًا من المديونية" —
    // spec 026)، مانلمسش الإدخال.
    if (_aTextFieldIsFocused()) return false;
    return _scanBuffer!.feedKey(event);
  }

  /// هل في حقل نص ماسك الفوكس دلوقتي؟ (نبحث لأعلى من عقدة الفوكس عن
  /// EditableTextState — الطريقة الموثوقة بدل فحص نوع الودجت مباشرةً.)
  static bool _aTextFieldIsFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null &&
        ctx.findAncestorStateOfType<EditableTextState>() != null;
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
  Future<void> _handle(String qr, {bool fromHardware = false}) async {
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
      if (fromHardware && mounted) {
        setState(() => _lastHardwareScanAt = DateTime.now());
      }
    }
  }

  // ── Confirm payment ──────────────────────────────────────────
  Future<void> _confirmPayment(Student student) async {
    // لازم يطابق بالظبط نفس الشرط اللي القaller (confirmPayment في
    // QrController) بيستخدمه عشان ياخد مسار عرض الإخوة — وإلا ممكن
    // نعرض حوار "عرض الإخوة" لطالب مش هيتطبّق عليه العرض فعليًا (لو
    // مجموعته بالحصة، أو معفى بالكامل)، أو العكس نستثنيه غلط من فحص
    // "المبلغ أكبر من المستحق".
    final isSiblingSplit = student.siblingGroupId != null &&
        student.siblingsTotal != null &&
        !controller.isPerSessionGroup &&
        !student.isFullyExempt;
    if (isSiblingSplit) {
      final others = await _db.getStudentsInSiblingGroup(
          student.siblingGroupId!,
          excludeId: student.id);
      if (!mounted) return;
      final total = controller.totalAmount.value;
      final otherNames = others.map((s) => s.name).join(' و');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد عرض الإخوة'),
          content: Text(
              'سيتم تطبيق عرض الإخوة بين ${student.name} و ${otherNames.isEmpty ? "الأخ" : otherNames}'
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

    // المبلغ المُعدَّل يدويًا أكبر من المستحق الفعلي على الشهور المختارة —
    // بنعرض تأكيد إضافي بدل ما نرفض على طول، عشان لو المدرس فعلاً قاصد
    // كده (خصم متفَق عليه، أو تصحيح مبلغ) يقدر يكمّل. مش بتتطبّق على
    // عرض الإخوة — ده أصلاً ليه حوار تأكيده الخاص فوق، والمقارنة هنا
    // (baseAmountForSelection) بتحسب مستحق طالب واحد مش الإجمالي
    // المقسوم بين الاتنين، فمكانتش هتبقى مقارنة صح لحالته.
    if (!mounted) return;
    if (!isSiblingSplit && controller.overrideExceedsDue) {
      final due = controller.baseAmountForSelection;
      final amount = controller.totalAmount.value;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('المبلغ أكبر من المستحق'),
          content: Text(
              'المبلغ (${FormatHelper.formatCurrency(amount)}) أكبر من '
              'المستحق على الشهور المختارة (${FormatHelper.formatCurrency(due)}).'
              ' متأكد إنك عايز تسجّل الدفعة دي؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تسجيل على أي حال')),
          ],
        ),
      );
      if (!mounted || proceed != true) return;
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
      final now = DateTime.now();
      final split = controller.lastSiblingSplit;
      if (split.isNotEmpty) {
        // عرض إخوة: عنصر لكل أخ بنصيبه الفعلي. نضيف بترتيب معكوس عشان
        // الطالب الممسوح (أول عنصر في القائمة) يفضل فوق في السجل.
        for (final e in split.reversed) {
          _session.add(SessionEntry(
            studentName: e.studentName,
            amount: e.amount,
            monthCount: monthCount,
            isPerSession: false,
            time: now,
            guardianPhone: e.guardianPhone,
            paymentId: e.paymentId,
          ));
        }
      } else {
        _session.add(SessionEntry(
          studentName: student.name,
          amount: amount,
          monthCount: monthCount,
          isPerSession: isPerSession,
          time: now,
          guardianPhone: student.guardianPhone,
          paymentId: controller.lastConfirmedPaymentId.value,
        ));
      }
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
        bottom: !_qrTabVisible
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
        physics: !_qrTabVisible ? const NeverScrollableScrollPhysics() : null,
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
              // شارة "القارئ الخارجي نشط" — spec 027
              if (_hardwareEnabled && _lastHardwareScanAt != null)
                HardwareActiveBadge(lastScanAt: _lastHardwareScanAt!),
              // Camera — أو بطاقة "القارئ جاهز" في وضع القارئ الخالص
              if (_pureScannerMode)
                Expanded(
                  flex: 5,
                  child: ReaderReadyPanel(lastScanAt: _lastHardwareScanAt),
                )
              else
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
                  if (student.isFullyExempt) {
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
    final t = context.tokens;
    return Material(
      color: t.positiveSoft,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: t.positive, size: 18),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  '$count طالب دفعوا اليوم',
                  style: AppType.body
                      .copyWith(fontWeight: FontWeight.w700, color: t.positive),
                ),
              ),
              Text(
                FormatHelper.formatCurrency(total),
                style: AppType.label.copyWith(color: t.positive),
              ),
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.chevron_left_rounded, color: t.positive, size: 18),
            ],
          ),
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
    final t = context.tokens;
    final surface = t.page;

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
              // نستخدم scannedStudent (اتجاب من القاعدة لحظة الاختيار عبر
              // handleScan) مش manualStudent (نسخة قديمة من نتائج البحث في
              // الذاكرة) — عشان الإعفاء/السعر يظهروا محدَّثين. وكمان نعرض
              // بطاقة المعفى هنا زي تبويب المسح بالظبط.
              child: Obx(() {
                final s = controller.scannedStudent.value ?? manualStudent!;
                if (s.isFullyExempt) {
                  return _ExemptPanel(student: s, onClear: onBack);
                }
                return _PaymentPanel(
                  student: s,
                  controller: controller,
                  db: db,
                  onConfirm: () => onConfirm(s),
                  onOverride: onOverride,
                  onClear: onBack,
                  showBackButton: true,
                );
              }),
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
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
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
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: t.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: t.line)),
                filled: true,
                fillColor: t.surface,
              ),
              onChanged: onSearch,
            ),
          ),
          Expanded(
            child: searchResults.isEmpty
                ? _SearchEmpty(hasQuery: searchCtrl.text.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
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

  // حالة الدفع — بتستخدم نفس مصدر المديونية المتراكمة المستخدم في كل
  // شاشات الدفع التانية (PricingHelper.accumulatedDebt/isOverdue)، بدل
  // حساب منفصل خاص بشاشة الـQR كان بيدّي نتيجة مختلفة (ومغلوطة أحيانًا)
  // عن باقي التطبيق. لمجموعات "بالحصة" مفيش مفهوم "شهر مدفوع" أصلاً،
  // وأثناء تحميل بيانات المجموعة/الحضور مبنقولش أي استنتاج لحد ما
  // البيانات توصل بالكامل (راجع QRController.isPreparingPayment).
  String _paymentStatus() {
    if (controller.isPreparingPayment.value) return 'جارِ التحميل';
    if (controller.isPerSessionGroup) return 'بالحصة';
    if (student.isFullyExempt) return 'معفى';
    final debt = controller.scannedStudentDebt;
    if (debt <= 0.01) return 'مدفوع بالكامل';
    return controller.scannedStudentOverdue ? 'متأخر' : 'لم يدفع';
  }

  Color _statusColor(AppTokens t, String status) {
    switch (status) {
      case 'لم يدفع':
        return t.danger;
      case 'متأخر':
        return t.caution;
      case 'مدفوع بالكامل':
      case 'مدفوع':
        return t.positive;
      case 'معفى':
      case 'بالحصة':
        return t.brand;
      case 'جارِ التحميل':
        return t.inkSoft;
      default:
        return t.caution;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'لم يدفع':
        return Icons.cancel_rounded;
      case 'متأخر':
        return Icons.warning_amber_rounded;
      case 'مدفوع بالكامل':
      case 'مدفوع':
        return Icons.check_circle_rounded;
      case 'معفى':
        return Icons.volunteer_activism_rounded;
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

  // ── بطاقة الطالب: الاسم بيفتح تفاصيل الطالب ─────────────────────
  Widget _header(BuildContext context, AppTokens t) {
    return FutureBuilder<Group?>(
      future: db.getGroup(student.groupId),
      builder: (_, snap) {
        final group = snap.data;
        final groupColor =
            group?.color != null ? Color(group!.color!) : t.brand;
        final isSiblings =
            student.siblingGroupId != null && student.siblingsTotal != null;
        final price = isSiblings
            ? (student.siblingsTotal ?? student.price)
            : student.price;
        final unit = group?.isPerSession == true ? 'الحصة' : 'شهر';
        final sub = student.isExempt && !isSiblings
            ? '${group?.name ?? "—"}  •  معفى ${student.exemptPercent.toInt()}% — ${FormatHelper.formatCurrency(student.effectivePrice)} / $unit'
            : '${group?.name ?? "—"}  •  ${FormatHelper.formatCurrency(price)} / $unit';

        return Obx(() {
          final status = _paymentStatus();
          final sColor = _statusColor(t, status);
          return AppPanel(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      student.name.isNotEmpty ? student.name[0] : '؟',
                      style: AppType.title.copyWith(color: groupColor),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم رابط: بيفتح صفحة تفاصيل الطالب.
                      Semantics(
                        button: true,
                        label: 'تفاصيل الطالب ${student.name}',
                        child: Tooltip(
                          message: 'تفاصيل الطالب',
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                            onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS,
                                arguments: student),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Flexible(
                                  child: Text(student.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.label
                                          .copyWith(color: t.brand)),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_left_rounded,
                                    size: 20, color: t.brand),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppType.caption.copyWith(color: t.inkSoft)),
                      const SizedBox(height: AppSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: sColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_statusIcon(status), size: 14, color: sColor),
                          const SizedBox(width: 4),
                          Text(status,
                              style: AppType.caption.copyWith(
                                  color: sColor,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: showBackButton ? 'رجوع للبحث' : 'إغلاق',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: onClear,
                  icon: Icon(
                      showBackButton
                          ? Icons.arrow_back_rounded
                          : Icons.close_rounded,
                      color: t.inkSoft),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── المديونية + آخر دفع في شريط واحد ────────────────────────────
  Widget _debtStrip(BuildContext context, AppTokens t) {
    return Obx(() {
      final lastPaid = 'آخر دفع: ${controller.lastPaidMonthText}';
      if (student.isFullyExempt || controller.isPreparingPayment.value) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Text(lastPaid,
              style: AppType.caption.copyWith(color: t.inkSoft)),
        );
      }
      final debt = controller.scannedStudentDebt;
      final paidUp = debt <= 0.01;
      final sessions =
          controller.isPerSessionGroup ? controller.scannedStudentDebtSessions : 0;
      final ink = paidUp ? t.positive : t.caution;
      return Container(
        margin: const EdgeInsets.only(top: AppSpace.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: paidUp ? t.positiveSoft : t.cautionSoft,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(children: [
          Icon(paidUp ? Icons.check_circle_rounded : Icons.info_rounded,
              size: 18, color: ink),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paidUp
                      ? 'الطالب مفيهوش أي مديونية حاليًا'
                      : 'متبقي عليه: ${FormatHelper.formatCurrency(debt)}'
                          '${sessions >= 1 ? '  (= $sessions حصة)' : ''}',
                  style: AppType.body
                      .copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
                Text(lastPaid,
                    style: AppType.caption.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
        ]),
      );
    });
  }

  Widget _sectionTitle(AppTokens t, String text, {List<Widget> actions = const []}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Row(children: [
          Expanded(
              child: Text(text, style: AppType.label.copyWith(color: t.ink))),
          ...actions,
        ]),
      );

  Widget _miniAction(AppTokens t, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: t.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: t.brand),
          const SizedBox(width: 4),
          Text(label,
              style: AppType.caption
                  .copyWith(color: t.brand, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── اختيار الحصص (مجموعة بالحصة) ─────────────────────────────────
  Widget _perSessionBlock(BuildContext context, AppTokens t) {
    return Obx(() {
      final fullyPaid = controller.fullyPaidUp;
      final unpaid = controller.unpaidSessionsCount;
      final count = controller.effectiveSessionsSelected;
      final unpaidDates = controller.unpaidSessionDates;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final includesToday = unpaidDates.contains(today);
      final color = fullyPaid ? t.inkFaint : t.brand;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(t, 'الحصص المستحقة'),
          // لو فيه أكتر من حصة متأخرة، بنسيب المدرس يختار كام حصة يدفع
          // دلوقتي بدل ما يكون إجباري يدفعهم كلهم مع بعض.
          if (!fullyPaid && unpaid > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(children: [
                Expanded(
                  child: Text('عدد الحصص المدفوعة دلوقتي',
                      style: AppType.body.copyWith(color: t.inkSoft)),
                ),
                _StepperBtn(
                  icon: Icons.remove_rounded,
                  onTap: count > 1
                      ? () => controller.setSessionsToPay(count - 1)
                      : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  alignment: Alignment.center,
                  child: Text('$count',
                      style: AppType.title.copyWith(color: t.brand)),
                ),
                _StepperBtn(
                  icon: Icons.add_rounded,
                  onTap: count < unpaid
                      ? () => controller.setSessionsToPay(count + 1)
                      : null,
                ),
              ]),
            ),
          Material(
            color: color.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(color: color.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: fullyPaid ? null : controller.payAllUnpaidSessions,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: AppSpace.sm),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                      fullyPaid
                          ? Icons.check_circle_rounded
                          : Icons.flash_on_rounded,
                      size: 18,
                      color: color),
                  const SizedBox(width: AppSpace.sm),
                  Flexible(
                    child: Text(
                      fullyPaid
                          ? 'تم تسجيل دفعة لكل الحصص المستحقة'
                          : count > 1
                              ? 'دفع $count حصص (${FormatHelper.formatCurrency(student.price * count)})'
                              : includesToday
                                  ? 'دفع حصة اليوم (${FormatHelper.formatCurrency(student.price)})'
                                  : 'دفع حصة متأخرة (${FormatHelper.formatCurrency(student.price)})',
                      textAlign: TextAlign.center,
                      style: AppType.label.copyWith(color: color),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // توضيح تاريخ الحصة/الحصص المستحقة بالظبط.
          if (!fullyPaid && unpaidDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                'الحصص المستحقة: ${unpaidDates.map(_formatSessionDateLabel).join('، ')}',
                style: AppType.caption.copyWith(color: t.inkSoft),
                textAlign: TextAlign.center,
              ),
            ),
          // دفع مبلغ حرّ من المديونية المتراكمة — للمجموعات بالحصة فقط.
          if (!fullyPaid &&
              controller.scannedStudentDebt > 0.01 &&
              student.effectivePrice > 0)
            _DebtAmountField(controller: controller),
        ],
      );
    });
  }

  // ── اختيار الشهور (مجموعة شهرية) ─────────────────────────────────
  Widget _monthsBlock(BuildContext context, AppTokens t) {
    return Obx(() {
      final months = controller.upcomingMonths;
      final selected = controller.selectedMonths;

      if (months.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: t.positiveSoft,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: t.positive, size: 18),
            const SizedBox(width: AppSpace.sm),
            Text('مدفوع بالكامل لهذا الشهر',
                style: AppType.body.copyWith(
                    color: t.positive, fontWeight: FontWeight.w700)),
          ]),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(t, 'اختر الشهور', actions: [
            _miniAction(t, Icons.bolt_rounded, 'الأقدم فقط',
                controller.selectFirstMonth),
            const SizedBox(width: AppSpace.sm),
            _miniAction(
                t, Icons.done_all_rounded, 'الكل', controller.selectAllUpcoming),
          ]),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: months.map((m) {
              final isSel = selected
                  .any((s) => s.year == m.year && s.month == m.month);
              final label = DateFormat('MMM yyyy', 'ar').format(m);
              return _MonthChip(
                  label: label,
                  selected: isSel,
                  onTap: () => controller.toggleMonth(m));
            }).toList(),
          ),
        ],
      );
    });
  }

  // ── الإخوة ───────────────────────────────────────────────────────
  Widget _siblingsInfo(BuildContext context, AppTokens t) {
    return Obx(() {
      final total = controller.totalAmount.value;
      return FutureBuilder<List<Student>>(
        future: DatabaseService().getStudentsInSiblingGroup(
            student.siblingGroupId!,
            excludeId: student.id),
        builder: (_, snap) {
          final others = snap.data ?? const <Student>[];
          final memberCount = others.length + 1;
          final names = others.map((s) => s.name).join('، ');
          return Container(
            margin: const EdgeInsets.only(top: AppSpace.md),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(children: [
              Icon(Icons.family_restroom_rounded, color: t.brand, size: 18),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'عرض الإخوة مع: ${names.isEmpty ? "—" : names}  •  نصيب كل: ${FormatHelper.formatCurrency(total / memberCount)}',
                  style: AppType.caption.copyWith(color: t.brand),
                ),
              ),
            ]),
          );
        },
      );
    });
  }

  // ── شريط ثابت تحت: الإجمالي + تعديل + تأكيد ──────────────────────
  Widget _bottomBar(BuildContext context, AppTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final total = controller.totalAmount.value;
                final hasOverride = controller.overrideAmount.value != null;
                final selectedCount = controller.selectedMonths.length;
                return Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('الإجمالي',
                            style:
                                AppType.caption.copyWith(color: t.inkSoft)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(FormatHelper.formatCurrency(total),
                              style: AppType.figure.copyWith(color: t.ink)),
                        ),
                        if (selectedCount > 0)
                          Text(
                              controller.isPerSessionGroup
                                  ? '${controller.effectiveSessionsSelected} حصة'
                                  : '$selectedCount شهر',
                              style: AppType.caption
                                  .copyWith(color: t.inkSoft)),
                      ],
                    ),
                  ),
                  if (hasOverride)
                    TextButton(
                      onPressed: () =>
                          controller.setOverride(amount: null, note: ''),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: t.inkSoft),
                      child: const Text('إعادة تعيين'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onOverride,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.ink,
                      side: BorderSide(color: t.line),
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control)),
                    ),
                  ),
                ]);
              }),
              Obx(() {
                if (controller.overrideNote.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Row(children: [
                    Icon(Icons.notes_rounded, size: 14, color: t.caution),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(controller.overrideNote.value,
                          style:
                              AppType.caption.copyWith(color: t.caution)),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: AppSpace.sm),
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
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.chalk,
                    foregroundColor: t.onChalk,
                    disabledBackgroundColor: t.line,
                    disabledForegroundColor: t.inkSoft,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control)),
                  ),
                  onPressed: canConfirm ? onConfirm : null,
                  icon: processing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.onChalk))
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
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(color: null),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.page,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, t),
                  _debtStrip(context, t),
                  const SizedBox(height: AppSpace.lg),
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                          )
                        : controller.isPerSessionGroup
                            ? _perSessionBlock(context, t)
                            : _monthsBlock(context, t),
                  ),
                  if (student.siblingGroupId != null &&
                      student.siblingsTotal != null)
                    _siblingsInfo(context, t),
                ],
              ),
            ),
          ),
          _bottomBar(context, t),
        ],
      ),
    );
  }
}

/// للاختبارات فقط: لوحة الدفع من غير كاميرا ولا تبويبات.
@visibleForTesting
Widget buildPaymentPanelForTest({
  required Student student,
  required QRController controller,
  required DatabaseService db,
  VoidCallback? onConfirm,
  VoidCallback? onOverride,
  VoidCallback? onClear,
  bool showBackButton = true,
}) =>
    _PaymentPanel(
      student: student,
      controller: controller,
      db: db,
      onConfirm: onConfirm ?? () {},
      onOverride: onOverride ?? () {},
      onClear: onClear ?? () {},
      showBackButton: showBackButton,
    );

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
    final t = context.tokens;
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? t.brand.withValues(alpha: 0.12) : t.line,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Icon(icon, size: 20, color: enabled ? t.brand : t.inkFaint),
      ),
    );
  }
}

// حقل "ادفع مبلغًا من المديونية" — للمجموعات بالحصة. بيعرض معاينة لحظية
// (كام حصة يغطّي + المتبقّي)، وعند "تطبيق" بيضبط override في QRController
// والمدرس بيكمل بزر "تأكيد الدفع" العادي. راجع specs/026.
class _DebtAmountField extends StatefulWidget {
  const _DebtAmountField({required this.controller});
  final QRController controller;

  @override
  State<_DebtAmountField> createState() => _DebtAmountFieldState();
}

class _DebtAmountFieldState extends State<_DebtAmountField> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _parsed {
    final v = double.tryParse(_ctrl.text.trim().replaceAll('٫', '.'));
    if (v == null || v <= 0) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.٫]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'ادفع مبلغًا من المديونية',
                    labelStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        borderSide: BorderSide(color: context.tokens.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        borderSide: BorderSide(color: context.tokens.line)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
                onPressed: _parsed == null
                    ? null
                    : () {
                        final ok = c.applyDebtAmountPayment(_parsed!);
                        if (ok) {
                          FocusScope.of(context).unfocus();
                          _ctrl.clear();
                          setState(() {});
                        }
                      },
                child: const Text('تطبيق'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Obx(() {
            final amount = _parsed;
            final debt = c.scannedStudentDebt;
            if (amount == null) return const SizedBox(height: 2);
            if (amount > debt + 0.01) {
              return Text(
                'المبلغ أكبر من المديونية المتراكمة (${FormatHelper.formatCurrency(debt)})',
                style: AppType.caption.copyWith(color: context.tokens.danger),
              );
            }
            return Text(
              'يغطّي ${c.sessionsCoveredBy(amount)} حصة  •  المتبقّي بعد الدفع: '
              '${FormatHelper.formatCurrency(c.debtRemainingAfter(amount))}',
              style: AppType.caption.copyWith(color: context.tokens.brand),
            );
          }),
        ],
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
    final t = context.tokens;
    final onInk =
        Theme.of(context).brightness == Brightness.dark ? t.page : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: selected ? t.brand : t.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: selected ? t.brand : t.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: selected ? onInk : t.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.body.copyWith(
                color: selected ? onInk : t.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ]),
        ),
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
    final t = context.tokens;
    final groupColor =
        group?.color != null ? Color(group!.color!) : t.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
        onTap: onSelect,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Center(
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '؟',
                  style: AppType.title.copyWith(color: groupColor),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: t.ink)),
                    Text(
                      '${student.code}  ·  ${group?.name ?? "—"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: t.inkSoft),
                    ),
                  ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md, vertical: 6),
              decoration: BoxDecoration(
                color: t.chalk,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text('اختيار',
                  style: AppType.body
                      .copyWith(color: t.onChalk, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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
    final t = context.tokens;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_search_rounded, size: 56, color: t.inkFaint),
        const SizedBox(height: AppSpace.sm),
        Text(
          hasQuery ? 'لم يُعثر على نتائج' : 'ابحث عن طالب لتسجيل الدفع',
          style: AppType.body.copyWith(color: t.inkSoft),
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
