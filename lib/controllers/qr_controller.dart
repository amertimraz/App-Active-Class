// lib/controllers/qr_controller.dart
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/controllers/attendance_controller.dart';

enum QRMode { attendance, payment }

class QRController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final Rx<QRMode> mode = QRMode.attendance.obs;
  final RxBool isProcessing = false.obs;
  final Rx<Student?> scannedStudent = Rx<Student?>(null);
  final Rx<Payment?> lastPayment = Rx<Payment?>(null);
  final RxList<DateTime> upcomingMonths = <DateTime>[].obs;
  final RxList<DateTime> selectedMonths = <DateTime>[].obs;
  final RxDouble totalAmount = 0.0.obs;
  final Rx<double?> overrideAmount = Rx<double?>(null);
  final RxString overrideNote = ''.obs;

  // للمجموعات المسعّرة بالحصة — لازم بيانات المجموعة والحضور عشان
  // نحسب المستحق الحقيقي بدل سعر ثابت شهري. Rx عشان الواجهة (اختيار
  // شهر مقابل دفع حصة) تتحدّث فورًا أول ما بيانات المجموعة توصل، مش
  // تفضل واقفة على قيمة الطالب اللي قبله.
  final Rx<Group?> _scannedGroup = Rx<Group?>(null);
  List<Attendance> _scannedAttendance = [];

  Future<void> handleScan(String code) async {
    if (isProcessing.value) return;
    final normalized = code.trim();
    if (normalized.isEmpty) {
      ToastHelper.error('رمز QR غير صالح');
      return;
    }
    isProcessing.value = true;
    try {
      final student = await _dbService.getStudentByCode(normalized);
      scannedStudent.value = student;
      if (student == null) {
        _clearPaymentState();
        ToastHelper.error('الطالب غير موجود لهذا الكود');
        return;
      }
      if (mode.value == QRMode.attendance) {
        await _recordAttendance(student);
      } else {
        await _preparePayment(student);
      }
    } catch (e) {
      ToastHelper.error('تعذر معالجة المسح');
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _recordAttendance(Student student) async {
    final now = DateTime.now();
    final attendance = Attendance(
      studentId: student.id!,
      date: now,
      status: ATTENDANCE_PRESENT,
      notes: 'تم عبر QR',
    );
    try {
      final att = Get.find<AttendanceController>();
      await att.addAttendance(attendance);
    } catch (_) {
      await _dbService.insertAttendance(attendance);
    }
  }

  Future<void> _preparePayment(Student student) async {
    _scannedGroup.value = await _dbService.getGroup(student.groupId);
    _scannedAttendance = _scannedGroup.value != null && _scannedGroup.value!.isPerSession
        ? await _dbService.getAttendanceByStudent(student.id!)
        : [];

    final payments = await _dbService.getPaymentsByStudent(student.id!);
    final latest = payments.isNotEmpty ? payments.first : null;
    lastPayment.value = latest;
    final lastMonth = _extractLastPaidMonth(latest);
    final start = _determineStartMonth(lastMonth);
    final months = _buildUpcomingMonths(start);
    upcomingMonths.assignAll(months);
    selectedMonths.assignAll(months.isNotEmpty ? [months.first] : []);
    _recalculateTotal();
  }

  DateTime? _extractLastPaidMonth(Payment? payment) {
    if (payment == null) return null;
    final note = payment.note ?? '';
    final monthsPart = note.split(';').first;
    if (monthsPart.startsWith('months=')) {
      final raw = monthsPart.substring('months='.length).split(',').where((item) => item.trim().isNotEmpty).toList();
      if (raw.isNotEmpty) {
        final value = raw.last.trim();
        final parts = value.split('-');
        if (parts.length == 2) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          if (year != null && month != null) {
            return DateTime(year, month);
          }
        }
      }
    }
    return DateTime(payment.date.year, payment.date.month);
  }

  DateTime _determineStartMonth(DateTime? lastMonth) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    if (lastMonth == null) return current;
    if (lastMonth.isBefore(current)) return current;
    return DateTime(lastMonth.year, lastMonth.month + 1);
  }

  List<DateTime> _buildUpcomingMonths(DateTime start) {
    return List.generate(4, (i) => DateTime(start.year, start.month + i));
  }

  void toggleMonth(DateTime month) {
    final exists = selectedMonths.any((m) => m.year == month.year && m.month == month.month);
    if (exists) {
      selectedMonths.removeWhere((m) => m.year == month.year && m.month == month.month);
    } else {
      selectedMonths.add(month);
    }
    selectedMonths.sort((a, b) => a.compareTo(b));
    _recalculateTotal();
  }

  void selectFirstMonth() {
    if (upcomingMonths.isEmpty) {
      selectedMonths.clear();
    } else {
      selectedMonths.assignAll([upcomingMonths.first]);
    }
    _recalculateTotal();
  }

  void selectThreeMonths() {
    if (upcomingMonths.isEmpty) {
      selectedMonths.clear();
    } else {
      final take = upcomingMonths.take(3).toList();
      selectedMonths.assignAll(take);
    }
    _recalculateTotal();
  }

  void selectAllUpcoming() {
    selectedMonths.assignAll(upcomingMonths);
    _recalculateTotal();
  }

  void clearSelection() {
    selectedMonths.clear();
    _recalculateTotal();
  }

  String formatMonth(DateTime month) {
    return DateFormat('MMMM yyyy', 'ar').format(month);
  }

  String get lastPaidMonthText {
    final payment = lastPayment.value;
    if (payment == null) return 'لا توجد مدفوعات سابقة';
    final paymentDateText = DateFormat('yyyy-MM-dd HH:mm').format(payment.date);
    // بالحصة: مفيش معنى لاسم "الشهر" هنا — الدفعة كانت لحصة/حصص، مش
    // لاشتراك شهر بعينه. نعرض التاريخ والوقت بس.
    if (isPerSessionGroup) return paymentDateText;
    final month = _extractLastPaidMonth(payment);
    final monthText = month == null ? formatMonth(payment.date) : formatMonth(month);
    return '$monthText - $paymentDateText';
  }

  Future<bool> confirmPayment() async {
    final student = scannedStudent.value;
    if (student == null) {
      ToastHelper.error('لا يوجد طالب محدد');
      return false;
    }
    if (selectedMonths.isEmpty) {
      ToastHelper.info('يرجى اختيار شهر واحد على الأقل');
      return false;
    }
    isProcessing.value = true;
    try {
      final now = DateTime.now();
      final labels = selectedMonths.map(formatMonth).toList();
      final keys = selectedMonths.map(_encodeMonth).toList();
      final custom = overrideAmount.value;
      final customNote = overrideNote.value.trim();
      // للمجموعات بالحصة بيبقى النص "تم دفع X حصة" مش اسم الشهر — عشان
      // ميوهمش المدرس إنه دافع اشتراك الشهر كله وهو أصلاً دافع حصة أو حصص.
      final paymentLabel = isPerSessionGroup
          ? (customNote == 'دفع حصة واحدة'
              ? 'حصة اليوم'
              : '$selectedSessionsCount حصة')
          : _successMessage(labels);

      if (student.siblingId != null && student.siblingsTotal != null) {
        final sibling = await _dbService.getStudent(student.siblingId!);
        if (sibling != null) {
          final total = custom ?? ((student.siblingsTotal!) * selectedMonths.length);
          final each = total / 2.0;
          final extra = [
            if (custom != null) 'custom=1',
            if (customNote.isNotEmpty) 'note=$customNote',
            'siblings=2',
          ].join(';');
          final note = 'months=${keys.join(',')};$extra';
          final p1 = Payment(studentId: student.id!, date: now, amount: each, note: note, createdAt: now);
          final p2 = Payment(studentId: sibling.id!, date: now, amount: each, note: note, createdAt: now);
          await _dbService.insertPayment(p1);
          await _dbService.insertPayment(p2);
          ToastHelper.success('عرض الإخوة: ${student.name} و ${sibling.name} • $paymentLabel ✅', title: 'تم الدفع');
          _clearPaymentState();
          return true;
        }
      }

      final base = _computeBaseAmount(student);
      final amount = custom ?? base;
      final extra = [
        if (custom != null) 'custom=1',
        if (customNote.isNotEmpty) 'note=$customNote',
      ].join(';');
      final note = extra.isEmpty ? 'months=${keys.join(',')}' : 'months=${keys.join(',')};$extra';
      final payment = Payment(
        studentId: student.id!,
        date: now,
        amount: amount,
        note: note,
        createdAt: now,
      );
      await _dbService.insertPayment(payment);
      ToastHelper.success('تم دفع $paymentLabel ✅', title: 'تم الدفع');
      _clearPaymentState();
      return true;
    } catch (_) {
      ToastHelper.error('تعذر تسجيل الدفع');
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  String _encodeMonth(DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final mon = month.month.toString().padLeft(2, '0');
    return '$year-$mon';
  }

  String _successMessage(List<String> labels) {
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels.first} و${labels.last}';
    final allButLast = labels.sublist(0, labels.length - 1).join('، ');
    return '$allButLast و${labels.last}';
  }

  void _recalculateTotal() {
    final custom = overrideAmount.value;
    if (custom != null) {
      totalAmount.value = custom;
      return;
    }
    final s = scannedStudent.value;
    if (s != null && s.siblingId != null && s.siblingsTotal != null) {
      totalAmount.value = (s.siblingsTotal!) * selectedMonths.length;
      return;
    }
    totalAmount.value = _computeBaseAmount(s);
  }

  // المستحق الأساسي (بدون تعديل يدوي/إخوة): شهري ثابت، أو بالحصة على حسب
  // عدد الحصص المحضورة فعليًا في الشهور المختارة. مستخدمة في المعاينة
  // (_recalculateTotal) وفي تسجيل الدفع الفعلي (confirmPayment) عشان
  // القيمتين متطابقين دايمًا.
  double _computeBaseAmount(Student? s) {
    final price = s?.price ?? 0;

    if (s != null && isPerSessionGroup) {
      double sum = 0;
      for (final month in selectedMonths) {
        final sessionsInMonth = _scannedAttendance
            .where((a) =>
                a.status == ATTENDANCE_PRESENT &&
                a.date.year == month.year &&
                a.date.month == month.month)
            .length;
        sum += price * sessionsInMonth;
      }
      return sum;
    }

    return price * selectedMonths.length;
  }

  // هل الطالب الممسوح/المختار من مجموعة مسعّرة بالحصة؟ تُستخدم في الواجهة
  // عشان تبدّل نصوص "شهر" بـ"حصة" في ملخص الدفع وزر التأكيد.
  bool get isPerSessionGroup => _scannedGroup.value?.isPerSession == true;

  // عدد الحصص المحضورة فعليًا ضمن الشهور المختارة — بديل selectedMonths.length
  // في عرض الملخص للمجموعات بالحصة (0 لو المجموعة شهرية).
  int get selectedSessionsCount {
    if (!isPerSessionGroup) return 0;
    int count = 0;
    for (final month in selectedMonths) {
      count += _scannedAttendance
          .where((a) =>
              a.status == ATTENDANCE_PRESENT &&
              a.date.year == month.year &&
              a.date.month == month.month)
          .length;
    }
    return count;
  }

  // دفع سريع لحصة واحدة بس (سعر الحصة الواحدة) — لطلاب المجموعات بالحصة
  // اللي بيدفعوا أول بأول بعد كل حصة، بدل ما المدرس يحسب المبلغ يدويًا.
  void quickPayOneSession() {
    final s = scannedStudent.value;
    if (s == null || !isPerSessionGroup) return;
    if (selectedMonths.isEmpty && upcomingMonths.isNotEmpty) {
      selectedMonths.assignAll([upcomingMonths.first]);
    }
    setOverride(amount: s.price, note: 'دفع حصة واحدة');
  }

  void setOverride({double? amount, String? note}) {
    overrideAmount.value = amount;
    overrideNote.value = note?.trim() ?? '';
    _recalculateTotal();
  }

  void _clearPaymentState() {
    scannedStudent.value = null;
    lastPayment.value = null;
    upcomingMonths.clear();
    selectedMonths.clear();
    totalAmount.value = 0;
    overrideAmount.value = null;
    overrideNote.value = '';
    _scannedGroup.value = null;
    _scannedAttendance = [];
  }
}
