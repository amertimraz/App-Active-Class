// lib/controllers/booklet_controller.dart
//
// spec 041 — الملازم/الكتب: تسعير + تسليم + تحصيل. مستقل تمامًا عن
// PaymentController/PricingHelper (FR-008). كل الحسابات عبر booklet_math.
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/booklet_math.dart';

enum DeliveryFilter { all, notDelivered, delivered }

enum PayFilter { all, none, partial, full, owing }

class BookletFilter {
  final DeliveryFilter delivery;
  final PayFilter pay;
  const BookletFilter({this.delivery = DeliveryFilter.all, this.pay = PayFilter.all});
}

class BookletStudentRow {
  final Student student;
  final bool delivered;
  final bool excluded;
  final double paid;
  final double remaining;
  final double overpaid;
  final BookletPaymentStatus status;
  final DateTime? lastPaymentAt;
  const BookletStudentRow({
    required this.student,
    required this.delivered,
    required this.excluded,
    required this.paid,
    required this.remaining,
    required this.overpaid,
    required this.status,
    this.lastPaymentAt,
  });
}

class BookletSummary {
  final int eligible;
  final int delivered;
  final int notDelivered;
  final int payNone;
  final int payPartial;
  final int payFull;
  final double collected;
  final double remaining;
  const BookletSummary({
    required this.eligible,
    required this.delivered,
    required this.notDelivered,
    required this.payNone,
    required this.payPartial,
    required this.payFull,
    required this.collected,
    required this.remaining,
  });
}

class BookletStudentLine {
  final Booklet booklet;
  final bool delivered;
  final double paid;
  final double remaining;
  final BookletPaymentStatus status;
  const BookletStudentLine({
    required this.booklet,
    required this.delivered,
    required this.paid,
    required this.remaining,
    required this.status,
  });
}

class BookletController extends GetxController {
  final DatabaseService _db = DatabaseService();

  final RxList<Booklet> booklets = <Booklet>[].obs;
  final RxList<BookletGroupLink> links = <BookletGroupLink>[].obs;
  final RxList<BookletRecord> records = <BookletRecord>[].obs;
  final RxList<BookletPayment> payments = <BookletPayment>[].obs;
  final RxList<Student> _students = <Student>[].obs;
  final RxBool loadedOnce = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      booklets.assignAll(await _db.getAllBooklets());
      links.assignAll(await _db.getAllBookletGroups());
      records.assignAll(await _db.getAllBookletRecords());
      payments.assignAll(await _db.getAllBookletPayments());
      _students.assignAll(await _db.getAllStudents());
    } catch (e) {
      debugPrint('BookletController.load فشل: $e');
    } finally {
      loadedOnce.value = true;
    }
  }

  // ── الملزمة ────────────────────────────────────────────────────────
  Future<int?> createBooklet({
    required String name,
    required double price,
    required List<int> groupIds,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || price < 0) return null;
    final id = await _db.insertBooklet(Booklet(name: trimmed, price: price));
    for (final g in groupIds) {
      await _db.insertBookletGroup(id, g);
    }
    await load();
    return id;
  }

  Future<void> updateBooklet(Booklet b,
      {String? name, double? price, List<int>? groupIds}) async {
    await _db.updateBooklet(b.copyWith(name: name?.trim(), price: price));
    if (groupIds != null) {
      final current = links.where((l) => l.bookletId == b.id).toList();
      for (final l in current) {
        if (!groupIds.contains(l.groupId)) await _db.deleteBookletGroup(l.id!);
      }
      final have = current.map((l) => l.groupId).toSet();
      for (final g in groupIds) {
        if (!have.contains(g)) await _db.insertBookletGroup(b.id!, g);
      }
    }
    await load();
  }

  Future<void> deleteBooklet(int bookletId) async {
    await _db.deleteBooklet(bookletId);
    await load();
  }

  // ── التسليم / الاستثناء ───────────────────────────────────────────
  Future<void> setDelivered(int bookletId, int studentId, bool delivered) async {
    await _db.upsertBookletRecord(bookletId, studentId, delivered: delivered);
    await load();
  }

  /// تسليم كل المؤهَّلين اللي لسه ما استلموش (يوم توزيع الملازم). يرجّع العدد.
  Future<int> deliverAll(int bookletId) async {
    final pending = rowsFor(bookletId).where((r) => !r.delivered).toList();
    for (final r in pending) {
      await _db.upsertBookletRecord(bookletId, r.student.id!, delivered: true);
    }
    await load();
    return pending.length;
  }

  Future<void> setExcluded(int bookletId, int studentId, bool excluded) async {
    await _db.upsertBookletRecord(bookletId, studentId, excluded: excluded);
    await load();
  }

  // ── الدفعات ───────────────────────────────────────────────────────
  /// يرجّع null عند النجاح، أو رسالة خطأ عربية.
  Future<String?> addPayment(int bookletId, int studentId, double amount,
      {DateTime? date}) async {
    if (amount <= 0) return 'المبلغ لازم يكون أكبر من صفر';
    final b = booklets.firstWhereOrNull((x) => x.id == bookletId);
    if (b == null) return 'الملزمة غير موجودة';
    final paid = bookletPaid(_paymentsFor(bookletId, studentId));
    final remaining = bookletRemaining(b.price, paid);
    if (amount > remaining + 0.005) {
      return 'المبلغ أكبر من المتبقي (${_fmt(remaining)})';
    }
    await _db.insertBookletPayment(BookletPayment(
      bookletId: bookletId,
      studentId: studentId,
      amount: amount,
      date: date ?? DateTime.now(),
    ));
    await load();
    return null;
  }

  Future<void> deletePayment(int paymentId) async {
    await _db.deleteBookletPayment(paymentId);
    await load();
  }

  Future<({int delivered, double paid})> deleteImpact(int bookletId) =>
      _db.getBookletDeleteImpact(bookletId);

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // ── استعلامات العرض ───────────────────────────────────────────────
  Iterable<BookletPayment> _paymentsFor(int bookletId, int studentId) =>
      payments.where((p) => p.bookletId == bookletId && p.studentId == studentId);

  Map<int, BookletRecord> _recordsMap(int bookletId) => {
        for (final r in records.where((r) => r.bookletId == bookletId))
          r.studentId: r
      };

  Set<int> _groupIds(int bookletId) =>
      links.where((l) => l.bookletId == bookletId).map((l) => l.groupId).toSet();

  BookletStudentRow _row(Booklet b, Student s, BookletRecord? r) {
    final pays = _paymentsFor(b.id!, s.id!).toList();
    final paid = bookletPaid(pays);
    DateTime? last;
    for (final p in pays) {
      if (last == null || p.date.isAfter(last)) last = p.date;
    }
    return BookletStudentRow(
      student: s,
      delivered: r?.delivered ?? false,
      excluded: r?.excluded ?? false,
      paid: paid,
      remaining: bookletRemaining(b.price, paid),
      overpaid: bookletOverpaid(b.price, paid),
      status: bookletPaymentStatus(b.price, paid),
      lastPaymentAt: last,
    );
  }

  List<Student> _candidates(int bookletId, {bool includeOrphans = false}) {
    final gids = _groupIds(bookletId);
    final orphanIds = <int>{};
    if (includeOrphans) {
      // طلاب عندهم دفعة/تسليم بس مجموعتهم اتشالت من الملزمة — للسجل التاريخي.
      orphanIds
        ..addAll(payments.where((p) => p.bookletId == bookletId).map((p) => p.studentId))
        ..addAll(records
            .where((r) => r.bookletId == bookletId && r.delivered)
            .map((r) => r.studentId));
    }
    return _students
        .where((s) => gids.contains(s.groupId) || orphanIds.contains(s.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// المؤهَّلون (أو السجل التاريخي لو [historical]) مع حالتي التسليم والدفع.
  List<BookletStudentRow> rowsFor(int bookletId,
      {BookletFilter filter = const BookletFilter(), bool historical = false}) {
    final b = booklets.firstWhereOrNull((x) => x.id == bookletId);
    if (b == null) return [];
    final rec = _recordsMap(bookletId);
    final cands = _candidates(bookletId, includeOrphans: historical);
    final students = historical
        ? historicalStudents(
            allCandidateStudents: cands,
            recordsByStudent: rec,
            studentIdsWithPayments: payments
                .where((p) => p.bookletId == bookletId)
                .map((p) => p.studentId)
                .toSet())
        : eligibleStudents(groupStudents: cands, recordsByStudent: rec);
    return students
        .map((s) => _row(b, s, rec[s.id]))
        .where((r) {
          switch (filter.delivery) {
            case DeliveryFilter.notDelivered:
              if (r.delivered) return false;
            case DeliveryFilter.delivered:
              if (!r.delivered) return false;
            case DeliveryFilter.all:
              break;
          }
          switch (filter.pay) {
            case PayFilter.none:
              return r.status == BookletPaymentStatus.none;
            case PayFilter.partial:
              return r.status == BookletPaymentStatus.partial;
            case PayFilter.full:
              return r.status == BookletPaymentStatus.full;
            case PayFilter.owing:
              return r.remaining > 0;
            case PayFilter.all:
              return true;
          }
        })
        .toList();
  }

  /// الطلاب المستثنون (لإلغاء الاستثناء).
  List<Student> excludedStudents(int bookletId) {
    final rec = _recordsMap(bookletId);
    return _candidates(bookletId)
        .where((s) => rec[s.id]?.excluded ?? false)
        .toList();
  }

  BookletSummary summaryFor(int bookletId) {
    final rows = rowsFor(bookletId);
    var delivered = 0, none = 0, partial = 0, full = 0;
    double collected = 0, remaining = 0;
    for (final r in rows) {
      if (r.delivered) delivered++;
      switch (r.status) {
        case BookletPaymentStatus.none:
          none++;
        case BookletPaymentStatus.partial:
          partial++;
        case BookletPaymentStatus.full:
          full++;
      }
      remaining += r.remaining;
    }
    // المحصَّل الفعلي = كل دفعات الملزمة (حتى لو الطالب اتأرشف/استُثني بعدها).
    collected = payments
        .where((p) => p.bookletId == bookletId)
        .fold<double>(0, (t, p) => t + p.amount);
    return BookletSummary(
      eligible: rows.length,
      delivered: delivered,
      notDelivered: rows.length - delivered,
      payNone: none,
      payPartial: partial,
      payFull: full,
      collected: collected,
      remaining: remaining,
    );
  }

  /// ملازم طالب: كل ملزمة هو مؤهَّل لها (أو عنده فيها تسليم/دفعة).
  List<BookletStudentLine> linesForStudent(int studentId) {
    final student = _students.firstWhereOrNull((s) => s.id == studentId);
    if (student == null) return [];
    final out = <BookletStudentLine>[];
    for (final b in booklets) {
      if (!_groupIds(b.id!).contains(student.groupId)) continue;
      final r = _recordsMap(b.id!)[studentId];
      final paid = bookletPaid(_paymentsFor(b.id!, studentId));
      final eligible = !student.isArchived && !(r?.excluded ?? false);
      if (!eligible && !(r?.delivered ?? false) && paid <= 0) continue;
      out.add(BookletStudentLine(
        booklet: b,
        delivered: r?.delivered ?? false,
        paid: paid,
        remaining: eligible ? bookletRemaining(b.price, paid) : 0,
        status: bookletPaymentStatus(b.price, paid),
      ));
    }
    return out;
  }

  double remainingForStudent(int studentId) => studentBookletsRemaining(
      linesForStudent(studentId).map((l) => BookletRemainingLine(l.remaining, 0)));

  List<BookletPayment> paymentsOf(int bookletId, int studentId) =>
      _paymentsFor(bookletId, studentId).toList();

  /// إجمالي كل الملازم: مسلَّم/مؤهَّل، محصَّل، متبقي.
  ({int delivered, int eligible, double collected, double remaining}) overall() {
    var d = 0, e = 0;
    double rem = 0;
    for (final b in booklets) {
      final sum = summaryFor(b.id!);
      d += sum.delivered;
      e += sum.eligible;
      rem += sum.remaining;
    }
    final col = payments.fold<double>(0, (t, p) => t + p.amount);
    return (delivered: d, eligible: e, collected: col, remaining: rem);
  }
}
