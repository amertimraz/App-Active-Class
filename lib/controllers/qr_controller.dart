// lib/controllers/qr_controller.dart
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/payment_model.dart';
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
    final month = _extractLastPaidMonth(payment);
    final monthText = month == null ? formatMonth(payment.date) : formatMonth(month);
    final paymentDateText = DateFormat('yyyy-MM-dd HH:mm').format(payment.date);
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
          ToastHelper.success('عرض الإخوة: ${student.name} و ${sibling.name} • ${_successMessage(labels)} ✅', title: 'تم الدفع');
          _clearPaymentState();
          return true;
        }
      }

      final base = student.price * selectedMonths.length;
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
      ToastHelper.success('تم دفع ${_successMessage(labels)} ✅', title: 'تم الدفع');
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
    final price = s?.price ?? 0;
    totalAmount.value = price * selectedMonths.length;
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
  }
}
