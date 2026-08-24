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
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/utils/pricing_helper.dart';

enum QRMode { attendance, payment }

class QRController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final Rx<QRMode> mode = QRMode.attendance.obs;
  final RxBool isProcessing = false.obs;
  final Rx<Student?> scannedStudent = Rx<Student?>(null);
  final Rx<Payment?> lastPayment = Rx<Payment?>(null);
  final RxBool isPreparingPayment = false.obs;
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
  List<Payment> _scannedPayments = [];

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

    // تأكد إن مجموعة الطالب أصلاً ليها حصة النهاردة (حسب جدولها الأسبوعي)
    // قبل ما نسجّل الحضور تلقائيًا بمجرد المسح. لو المجموعة ملهاش جدول
    // مُدخَل، بنسمح عادي (الميزة اختيارية ومبنية على وجود جدول).
    final group = await _dbService.getGroup(student.groupId);
    if (group != null &&
        Get.isRegistered<AttendanceController>() &&
        !Get.find<AttendanceController>().groupHasSessionOnDay(group, now)) {
      ToastHelper.error('مجموعة "${group.name}" ليس لها حصة اليوم');
      return;
    }

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
    // بنصفّر بيانات الطالب السابق وبنحط علم تحميل قبل أي await — لحد ما
    // بيانات المجموعة/الحضور الجديدة توصل بالكامل. من غير العلم ده،
    // الواجهة ممكن تعرض استنتاج غلط (زي "مدفوع بالكامل لهذا الشهر")
    // بناءً على بيانات ناقصة/قديمة لحظة الانتقال بين طالب وتاني.
    isPreparingPayment.value = true;
    _scannedGroup.value = null;
    _scannedAttendance = [];
    _scannedPayments = [];
    upcomingMonths.clear();
    selectedMonths.clear();
    try {
      _scannedGroup.value = await _dbService.getGroup(student.groupId);
      _scannedAttendance =
          _scannedGroup.value != null && _scannedGroup.value!.isPerSession
              ? await _dbService.getAttendanceByStudent(student.id!)
              : [];

      final payments = await _dbService.getPaymentsByStudent(student.id!);
      _scannedPayments = payments;
      final latest = payments.isNotEmpty ? payments.first : null;
      lastPayment.value = latest;
      final lastMonth = _extractLastPaidMonth(latest);
      final start = _determineStartMonth(lastMonth);
      final months = _buildUpcomingMonths(start);
      upcomingMonths.assignAll(months);
      selectedMonths.assignAll(months.isNotEmpty ? [months.first] : []);
      _sessionsCoveredByQuickPay = 0;
      resetSessionsToPaySelection();
      _recalculateTotal();
    } finally {
      isPreparingPayment.value = false;
    }
  }

  DateTime? _extractLastPaidMonth(Payment? payment) {
    if (payment == null) return null;
    final note = payment.note ?? '';
    final monthsPart = note.split(';').first;
    if (monthsPart.startsWith('months=')) {
      final raw = monthsPart
          .substring('months='.length)
          .split(',')
          .where((item) => item.trim().isNotEmpty)
          .toList();
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
    final exists = selectedMonths
        .any((m) => m.year == month.year && m.month == month.month);
    if (exists) {
      selectedMonths
          .removeWhere((m) => m.year == month.year && m.month == month.month);
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
    final monthText =
        month == null ? formatMonth(payment.date) : formatMonth(month);
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
    // مجموعات بالحصة بس — مينفعش تتسجل دفعة لطالب لسه ماحضرش أي حصة
    // فعليًا في الشهور المختارة (غير كده المبلغ المحسوب هيبقى صفر بصمت).
    // بنسمح بتجاوز الشرط ده لو المدرس حدّد مبلغ يدوي بنفسه (override).
    if (isPerSessionGroup &&
        selectedSessionsCount == 0 &&
        overrideAmount.value == null) {
      ToastHelper.error('الطالب لسه متسجلش حضور لأي حصة في الفترة المختارة');
      return false;
    }
    // للمجموعات بالحصة، لازم يتم الضغط على "دفع حصة اليوم" الأول عشان
    // يحدّد سعر حصة واحدة بالظبط (override). من غيره، الحساب العادي
    // (_computeBaseAmount) بيرجّع إجمالي كل الحصص المحضورة في الشهر
    // بالكامل من غير ما يخصم أي دفعات سابقة — يعني تأكيد مباشر من غير
    // الزرار كان ممكن يحسب نفس المبلغ الكامل تاني في كل ضغطة (دفع
    // مضاعف). ده مش حالة "بالحصة" لسه غير مدعومة إن المدرس يختار
    // يدفع لعدة حصص دفعة واحدة، غير عن طريق الزرار المخصص لده.
    if (isPerSessionGroup && overrideAmount.value == null) {
      ToastHelper.error('اضغط "دفع الحصص المستحقة" الأول');
      return false;
    }
    // نفس منع تكرار الدفع بتاع payAllUnpaidSessions، لكن هنا كمان عشان
    // زر "تأكيد الدفع" العادي ممكن يتضغط مباشرة من غير المرور بيه.
    if (fullyPaidUp) {
      ToastHelper.error('تم تسجيل دفعة لكل الحصص المستحقة بالفعل');
      return false;
    }
    // بنلقط عدد الحصص اللي هنسجل دفعة عنها دلوقتي *قبل* أي إدراج في
    // القاعدة، عشان نحفظه جوه note الدفعة (sessions=N) — ده اللي بيخلي
    // _paidSessionsInSelectedMonths يحسب صح لاحقًا حتى لو دفعة واحدة
    // غطّت أكتر من حصة (زي حصة إمبارح وحصة النهاردة مع بعض). لو الدفعة
    // مش جاية من payAllUnpaidSessions (يعني من حوار "تعديل" اليدوي)،
    // بنستنتج العدد من المبلغ ÷ سعر الحصة كأفضل تقدير.
    final sessionsBeingPaid = !isPerSessionGroup
        ? 0
        : _sessionsCoveredByQuickPay > 0
            ? _sessionsCoveredByQuickPay
            : (overrideAmount.value != null && student.effectivePrice > 0
                ? (overrideAmount.value! / student.effectivePrice)
                    .round()
                    .clamp(1, 999)
                : unpaidSessionsCount);
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
          ? (sessionsBeingPaid == 1 ? 'حصة واحدة' : '$sessionsBeingPaid حصة')
          : _successMessage(labels);

      // عرض الإخوة مبني على سعر باقة شهرية مشتركة — مالوش معنى لمجموعات
      // بالحصة (فيها كل حصة بسعرها المنفصل)، وميصحش يتطبّق على طالب معفى
      // بالكامل (كان هيتحسب عليه نص باقة رغم إعفائه). في الحالتين دول
      // بنسيب الحساب يكمل عادي على الطالب الممسوح لوحده بدل عرض الإخوة.
      if (student.siblingId != null &&
          student.siblingsTotal != null &&
          !isPerSessionGroup &&
          !student.isFullyExempt) {
        final sibling = await _dbService.getStudent(student.siblingId!);
        if (sibling != null) {
          final total =
              custom ?? ((student.siblingsTotal!) * selectedMonths.length);
          final each = total / 2.0;
          final extra = [
            if (custom != null) 'custom=1',
            if (customNote.isNotEmpty) 'note=$customNote',
            'siblings=2',
          ].join(';');
          final note = 'months=${keys.join(',')};$extra';
          final p1 = Payment(
              studentId: student.id!,
              date: now,
              amount: each,
              note: note,
              createdAt: now);
          final p2 = Payment(
              studentId: sibling.id!,
              date: now,
              amount: each,
              note: note,
              createdAt: now);
          await _dbService.insertPayment(p1);
          await _dbService.insertPayment(p2);
          _refreshDashboard();
          ToastHelper.success(
              'عرض الإخوة: ${student.name} و ${sibling.name} • $paymentLabel ✅',
              title: 'تم الدفع');
          _clearPaymentState();
          return true;
        }
      }

      final base = _computeBaseAmount(student);
      final amount = custom ?? base;
      // بنقارن بس لو المدرس عدّل المبلغ يدويًا (custom) — لأن base نفسها
      // ممكن تشمل شهور قادمة لسه ماجاش وقتها لو المدرس بيدفع مقدَّم
      // (selectAllUpcoming)، فمقارنتها بمديونية ماضية/حالية بس (accumulatedDebt)
      // كانت هتمنع الدفع المقدَّم المشروع ده غلط. المرجع الصحيح للتعديل
      // اليدوي هو نفسه إجمالي المستحق على الشهور المختارة (base).
      if (custom != null && custom > base + 0.01) {
        ToastHelper.error(
            'المبلغ أكبر من المستحق على الشهور المختارة (${FormatHelper.formatCurrency(base)})');
        return false;
      }
      final extra = [
        if (custom != null) 'custom=1',
        if (customNote.isNotEmpty) 'note=$customNote',
        if (isPerSessionGroup) 'sessions=$sessionsBeingPaid',
      ].join(';');
      final note = extra.isEmpty
          ? 'months=${keys.join(',')}'
          : 'months=${keys.join(',')};$extra';
      final payment = Payment(
        studentId: student.id!,
        date: now,
        amount: amount,
        note: note,
        createdAt: now,
      );
      await _dbService.insertPayment(payment);
      _refreshDashboard();
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

  void _refreshDashboard() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().loadDashboardData();
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
    if (s != null &&
        s.siblingId != null &&
        s.siblingsTotal != null &&
        !isPerSessionGroup &&
        !s.isFullyExempt) {
      totalAmount.value = (s.siblingsTotal!) * selectedMonths.length;
      return;
    }
    // بالحصة: بنعرض قيمة عدد الحصص المختار دفعها دلوقتي بس (sessionsToPay)،
    // مش إجمالي كل الحصص المستحقة بالضرورة — عشان الرقم المعروض هنا
    // يطابق دايمًا اللي هيتحصّل فعليًا لو المدرس ضغط "دفع الحصص المستحقة".
    if (isPerSessionGroup && s != null) {
      totalAmount.value = s.effectivePrice * effectiveSessionsSelected;
      return;
    }
    totalAmount.value = _computeBaseAmount(s);
  }

  // المستحق الأساسي (بدون تعديل يدوي/إخوة): شهري ثابت، أو بالحصة على حسب
  // عدد الحصص المحضورة فعليًا في الشهور المختارة، مع تطبيق نسبة الإعفاء.
  // بيستخدم PricingHelper (نفس مصدر الحساب في شاشة المدفوعات) عشان
  // القيمتين متطابقين دايمًا ومتشملين خصم الإعفاء الجزئي.
  double _computeBaseAmount(Student? s) {
    if (s == null) return 0;
    double sum = 0;
    for (final month in selectedMonths) {
      sum += PricingHelper.monthlyDue(
        student: s,
        group: _scannedGroup.value,
        month: month,
        allAttendance: _scannedAttendance,
      );
    }
    return sum;
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

  // إجمالي عدد الحصص اللي اتغطّت بدفعات سابقة ضمن الشهور المختارة —
  // بنقرأ العدد المُخزَّن في note كل دفعة ("sessions=N") بدل ما نعتبر
  // كل دفعة = حصة واحدة بالظبط، لأن دفعة واحدة ممكن تغطي كذا حصة مع
  // بعض (زي حصة إمبارح وحصة النهاردة سُددوا في دفعة واحدة).
  int get _paidSessionsInSelectedMonths {
    if (!isPerSessionGroup) return 0;
    var total = 0;
    for (final p in _scannedPayments) {
      final inRange = selectedMonths
          .any((m) => p.date.year == m.year && p.date.month == m.month);
      if (!inRange) continue;
      final match = RegExp(r'sessions=(\d+)').firstMatch(p.note ?? '');
      total += match != null ? int.parse(match.group(1)!) : 1;
    }
    return total;
  }

  // عدد الحصص اللي حضرها الطالب ولسه ماتدفعش عنها — ده اللي المفروض
  // يتحصّل فعليًا (مش كل الحصص اللي حضرها من الأول).
  int get unpaidSessionsCount {
    if (!isPerSessionGroup) return 0;
    final unpaid = selectedSessionsCount - _paidSessionsInSelectedMonths;
    return unpaid < 0 ? 0 : unpaid;
  }

  // عدد الحصص اللي فعليًا هيتحصّل عنها لو ضغط المدرس "دفع الحصص المستحقة"
  // دلوقتي — بياخد في الاعتبار اختياره (sessionsToPay) لو عايز يدفع
  // جزء من المتأخر بس، مش كل حصص unpaidSessionsCount مجبَر عليها.
  int get effectiveSessionsSelected {
    final unpaid = unpaidSessionsCount;
    return unpaid > 0 ? sessionsToPay.value.clamp(1, unpaid) : 0;
  }

  // تواريخ الحصص المستحقة بالظبط (عشان المدرس يشوف "إمبارح + النهاردة"
  // بدل رقم مجرد). مفيش ربط فعلي بين كل دفعة وحصة بعينها في القاعدة،
  // فبنفترض إن الدفعات بتتحصّل على أقدم الحصص الأول (FIFO) — يعني لو
  // اتحصّل حصة واحدة من أصل اتنين، بنعتبرها غطّت الأقدم وسايبة الأحدث.
  List<DateTime> get unpaidSessionDates {
    if (!isPerSessionGroup) return [];
    final dates = <DateTime>[];
    for (final month in selectedMonths) {
      dates.addAll(_scannedAttendance
          .where((a) =>
              a.status == ATTENDANCE_PRESENT &&
              a.date.year == month.year &&
              a.date.month == month.month)
          .map((a) => DateTime(a.date.year, a.date.month, a.date.day)));
    }
    dates.sort();
    final paid = _paidSessionsInSelectedMonths;
    return paid >= dates.length ? dates : dates.sublist(paid);
  }

  // هل الطالب حاضر حصص فعلًا ومدفوعله عنها كلها؟ (يمنع تكرار الدفع سواء
  // عن طريق "دفع الحصص المستحقة" أو زر "تأكيد الدفع" مباشرة).
  bool get fullyPaidUp =>
      isPerSessionGroup &&
      selectedSessionsCount > 0 &&
      unpaidSessionsCount == 0;

  // عدد الحصص اللي المدرس دلوقتي مختار يدفع عنها من أصل unpaidSessionsCount
  // — بيسمح بدفع جزء من الحصص المتأخرة بدل ما يكون إجباري تدفع كل
  // المتأخر مرة واحدة (مثلاً ولي الأمر جاي يدفع حصة واحدة بس من أصل
  // اتنين متأخرين). الافتراضي = كل الحصص المستحقة.
  final RxInt sessionsToPay = 1.obs;

  // عدد الحصص اللي فعليًا هتتغطّي بالدفعة الجاية — بنحفظه عشان نضمن إن
  // note الدفعة (sessions=N) بيطابق بالظبط المبلغ المحسوب هنا، حتى لو
  // المدرس بعدين استخدم "تعديل" وغيّر المبلغ يدويًا (وقتها بنرجع نحسب
  // العدد من المبلغ/السعر بدل الاعتماد على القيمة القديمة هنا).
  int _sessionsCoveredByQuickPay = 0;

  // بيتنادى مرة واحدة بس مع كل طالب جديد بيتمسح — الافتراضي دايمًا "ادفع
  // كل الحصص المستحقة" (مش بس clamp للقيمة القديمة)، عشان القيمة اللي
  // فضلت من طالب سابق (زي 1) متفضلش عالقة كافتراض غلط لطالب جديد عنده
  // أكتر من حصة مستحقة.
  void resetSessionsToPaySelection() {
    final unpaid = unpaidSessionsCount;
    sessionsToPay.value = unpaid > 0 ? unpaid : 1;
  }

  void setSessionsToPay(int count) {
    final unpaid = unpaidSessionsCount;
    if (unpaid <= 0) return;
    sessionsToPay.value = count.clamp(1, unpaid);
    if (overrideAmount.value == null) {
      // لسه ماضغطش زر الدفع — بس نحدّث "الإجمالي" المعروض ليطابق العدد
      // الجديد فورًا.
      _recalculateTotal();
    } else {
      // ضغط الزرار قبل كده وبعدين غيّر العدد — لازم نعيد حساب المبلغ
      // المُعلَّق (override) بنفس العدد الجديد فورًا، وإلا هيفضل المبلغ
      // القديم متزامن مع عدد قديم غلط لحد ما يضغط الزرار تاني.
      payAllUnpaidSessions();
    }
  }

  // دفع عدد الحصص المختار (sessionsToPay) من أصل الحصص المستحقة — بيغطّي
  // حالة إن الطالب اتأخر يدفع كذا حصة (مثلاً حصة إمبارح وحصة النهاردة)
  // لكن ولي الأمر عايز يدفع حصة واحدة بس دلوقتي مش الاتنين مع بعض.
  void payAllUnpaidSessions() {
    final s = scannedStudent.value;
    if (s == null || !isPerSessionGroup) return;
    if (selectedSessionsCount == 0) {
      ToastHelper.error('الطالب لسه متسجلش حضور لأي حصة في الفترة المختارة');
      return;
    }
    final unpaid = unpaidSessionsCount;
    if (unpaid <= 0) {
      ToastHelper.error('تم تسجيل دفعة لكل الحصص المستحقة بالفعل');
      return;
    }
    final count = sessionsToPay.value.clamp(1, unpaid);
    setOverride(
      amount: s.effectivePrice * count,
      note: count == 1 ? 'دفع حصة واحدة' : 'دفع $count حصص',
    );
    // لازم بعد setOverride مباشرة — setOverride بيصفّر القيمة دي لأنه
    // مستخدم كمان من حوار "تعديل" اليدوي اللي مش هنعرف فيه عدد الحصص.
    _sessionsCoveredByQuickPay = count;
  }

  void setOverride({double? amount, String? note}) {
    overrideAmount.value = amount;
    overrideNote.value = note?.trim() ?? '';
    // أي استخدام تاني لـ setOverride غير payAllUnpaidSessions (زي حوار
    // "تعديل" اليدوي) معناه إحنا مش متأكدين بالظبط كام حصة اتغطّت —
    // confirmPayment هيرجع يحسبها من المبلغ/السعر بدل ما يفترض القيمة
    // القديمة دي.
    _sessionsCoveredByQuickPay = 0;
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
