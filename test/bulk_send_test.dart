// طابور الإرسال، بناء الرسائل الجماعية، والحصة الجاية — منطق صرف.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/bulk_send_builders.dart';
import 'package:active_class/utils/debts_overview.dart';
import 'package:active_class/utils/next_session.dart';
import 'package:active_class/utils/send_queue.dart';

Student _s(int id, String name, {String? phone, String? wa, int g = 1}) =>
    Student(
        id: id,
        name: name,
        code: 'S$id',
        groupId: g,
        price: 100,
        guardianPhone: phone,
        guardianWhatsapp: wa);

QueueItem _q(Student s) => QueueItem.forStudent(s, message: 'm ${s.name}');

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('طابور الإرسال', () {
    test('اللي من غير رقم بيتخطّى من الأول والتقدّم بيحسبه', () {
      final q = SendQueue([
        _q(_s(1, 'أ', phone: '0100')),
        _q(_s(2, 'ب')),
        _q(_s(3, 'ج', wa: 'x')),
      ]);
      expect(q.noContactCount, 1);
      expect(q.items[1].status, QueueStatus.skipped);
      expect(q.pendingCount, 2);
      expect(q.current, 0);
    });

    test('فتح وتقدّم وانتهاء', () {
      final q = SendQueue([
        _q(_s(1, 'أ', phone: '1')),
        _q(_s(2, 'ب', phone: '2')),
      ]);
      q.markOpened(0);
      expect(q.advance(), isTrue);
      expect(q.current, 1);
      expect(q.isDone, isFalse);
      q.skip(1);
      expect(q.isDone, isTrue);
      expect(q.advance(), isFalse);
      expect(q.progress, 1.0);
      expect(q.openedCount, 1);
      expect(q.skippedCount, 1);
    });

    test('إعادة واحدة اتفتحت بترجّعها منتظرة، والتالية بتلف للبداية', () {
      final q = SendQueue([
        _q(_s(1, 'أ', phone: '1')),
        _q(_s(2, 'ب', phone: '2')),
        _q(_s(3, 'ج', phone: '3')),
      ]);
      q.markOpened(0);
      q.markOpened(2);
      q.jumpTo(2);
      q.reset(0);
      expect(q.items[0].status, QueueStatus.pending);
      expect(q.nextPending(), 0); // لفّ للبداية
      q.reset(1); // منتظرة أصلًا
      expect(q.items[1].status, QueueStatus.pending);
    });

    test('المرفق بيعدّي من غير رقم', () {
      final it = QueueItem(
        studentId: 1,
        name: 'أ',
        message: 'm',
        attachment: QueueAttachment(fileName: 'a.pdf', bytes: () async => throw 0),
      );
      expect(it.canSend, isTrue);
      expect(SendQueue([it]).noContactCount, 0);
    });

    test('قايمة فاضية = خلصانة', () {
      final q = SendQueue(const []);
      expect(q.isDone, isTrue);
      expect(q.progress, 1.0);
      expect(q.currentItem, isNull);
    });
  });

  group('بناء الرسائل', () {
    final g = Group(id: 1, name: 'أولى ثانوي', code: 'G1', price: 100);

    StudentDebtRow row(Student s, List<double> remaining) => StudentDebtRow(
          student: s,
          group: g,
          monthPrice: 100,
          months: [
            for (var i = 0; i < remaining.length; i++)
              DebtMonthRow(
                  month: DateTime(2026, 9 + i, 1),
                  due: 100,
                  remaining: remaining[i],
                  isSmall: remaining[i] < 99.5)
          ],
        );

    test('تذكير الدفع: شهر واحد يكتب اسمه، أكتر يكتب المجموع وعدد الشهور', () {
      final items = buildPaymentReminderItems(
        rows: [
          row(_s(1, 'أحمد', phone: '0100'), [100]),
          row(_s(2, 'بسمة', phone: '0101'), [100, 50]),
        ],
        money: (v) => '${v.toInt()} ج',
        teacherName: 'أ. سعد',
      );
      expect(items.length, 2);
      expect(items[0].message, contains('أحمد'));
      expect(items[0].message, contains('100 ج'));
      expect(items[0].message, contains('اشتراك شهر'));
      expect(items[1].message, contains('150 ج'));
      expect(items[1].message, isNot(contains('اشتراك شهر')));
      expect(items[1].subtitle, contains('2 شهور'));
    });

    test('فلتر المجموعة وتخطّي اللي متبقيه صفر', () {
      final items = buildPaymentReminderItems(
        rows: [
          row(_s(1, 'أ', phone: '1'), [100]),
          row(_s(2, 'ب', phone: '2', g: 2), [100]),
          row(_s(3, 'ج', phone: '3'), [0.2]),
        ],
        money: (v) => '$v',
        groupId: 1,
      );
      expect(items.map((i) => i.name), ['أ']);
    });

    test('الغياب: غايب اليوم بس، من غير مؤرشفين ولا تكرار', () {
      final day = DateTime(2026, 11, 5);
      Attendance a(int id, String st, DateTime d) =>
          Attendance(studentId: id, date: d, status: st);
      final archived = Student(
          id: 9,
          name: 'مؤرشف',
          code: 'S9',
          groupId: 1,
          price: 100,
          guardianPhone: '9',
          isArchived: true);
      final items = buildAbsenceItems(
        students: [
          _s(1, 'ب', phone: '1'),
          _s(2, 'أ', phone: '2'),
          _s(3, 'ج', phone: '3'),
          archived,
        ],
        groups: [Group(id: 1, name: 'مجموعة', code: 'G', price: 1)],
        attendance: [
          a(1, ATTENDANCE_ABSENT, day),
          a(1, ATTENDANCE_ABSENT, day), // مكرر
          a(2, ATTENDANCE_ABSENT, day),
          a(3, ATTENDANCE_PRESENT, day),
          a(3, ATTENDANCE_ABSENT, DateTime(2026, 11, 4)), // يوم تاني
          a(9, ATTENDANCE_ABSENT, day),
        ],
        date: day,
      );
      expect(items.map((i) => i.name), ['أ', 'ب']); // مرتبين بالاسم
      expect(items.first.message, contains('تنبيه غياب'));
    });
  });

  group('الحصة الجاية', () {
    final day = DateTime(2026, 11, 7);
    final g = Group(id: 1, name: 'ج', code: 'G', price: 1);
    SessionSlot slot(int h1, int h2) => SessionSlot(
        g, DateTime(2026, 11, 7, h1), DateTime(2026, 11, 7, h2));

    test('قراءة المدى بكل الصيغ', () {
      final r = parseSessionRange('16:00-18:00', day)!;
      expect(r.start, DateTime(2026, 11, 7, 16));
      expect(r.end, DateTime(2026, 11, 7, 18));
      expect(parseSessionRange('16:00 - 18:30', day)!.end.minute, 30);
      expect(parseSessionRange('16:00', day)!.end, DateTime(2026, 11, 7, 17, 30));
      // بتعدّي نص الليل
      expect(parseSessionRange('23:00-01:00', day)!.end.day, 8);
      expect(parseSessionRange('غلط', day), isNull);
      expect(parseSessionRange('25:00-26:00', day), isNull);
      expect(parseSessionRange(null, day), isNull);
    });

    test('الشغالة تتفضّل على الجاية، وإلا أقرب جاية، وإلا null', () {
      final slots = [slot(14, 16), slot(18, 20), slot(17, 18)];
      expect(pickNextSlot(slots, DateTime(2026, 11, 7, 15))!.start.hour, 14);
      expect(pickNextSlot(slots, DateTime(2026, 11, 7, 16, 30))!.start.hour, 17);
      expect(pickNextSlot(slots, DateTime(2026, 11, 7, 21)), isNull);
      expect(pickNextSlot(const [], DateTime(2026, 11, 7, 9)), isNull);
    });

    test('نص المدة', () {
      expect(untilText(const Duration(minutes: 40)), 'بعد 40 دقيقة');
      expect(untilText(const Duration(minutes: 60)), 'بعد ساعة');
      expect(untilText(const Duration(minutes: 70)), 'بعد ساعة و10 دقيقة');
      expect(untilText(const Duration(minutes: 120)), 'بعد ساعتين');
      expect(untilText(Duration.zero), 'دلوقتي');
    });
  });
}
