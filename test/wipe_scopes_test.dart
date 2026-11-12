// test/wipe_scopes_test.dart — «حذف جميع البيانات» المرن بالأقسام:
// منطق الأقسام التابعة (صرف) + حذف فعلي على SQLite حقيقية: الاختيار يحذف
// قسمه بس، حذف الطلاب بيسحب بياناتهم، حذف المجموعات بيمسح كل شيء، الإعدادات
// ما بتتمسش، وفي وضع الفريق بيتطابور حذف للصفوف المُزامَنة.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/wipe_scope.dart';
import 'package:active_class/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الأقسام التابعة (wipeClosure)', () {
    test('قسم عادي ما بيسحبش حاجة', () {
      expect(wipeClosure({WipeScope.attendance}), {WipeScope.attendance});
    });

    test('الطلاب بيسحبوا حضورهم ودفعاتهم وواجباتهم ودرجاتهم ومتابعاتهم', () {
      expect(
        wipeClosure({WipeScope.students}),
        {
          WipeScope.students,
          WipeScope.attendance,
          WipeScope.payments,
          WipeScope.homework,
          WipeScope.examResults,
          WipeScope.followUps,
        },
      );
    });

    test('المجموعات بتسحب الطلاب وكل توابعهم والحصص الاستثنائية', () {
      final c = wipeClosure({WipeScope.groups});
      expect(c, containsAll([
        WipeScope.groups,
        WipeScope.students,
        WipeScope.attendance,
        WipeScope.payments,
        WipeScope.sessionOverrides,
      ]));
      // الامتحانات نفسها وبنك الأسئلة والكراسات مش تابعين للمجموعات
      expect(c.contains(WipeScope.exams), isFalse);
      expect(c.contains(WipeScope.questionBank), isFalse);
      expect(c.contains(WipeScope.booklets), isFalse);
    });

    test('الامتحانات بتسحب النتايج، وكل قسم له ترتيب حذف', () {
      expect(wipeClosure({WipeScope.exams}),
          {WipeScope.exams, WipeScope.examResults});
      expect(kWipeOrder.toSet(), WipeScope.values.toSet());
    });
  });

  group('الحذف على قاعدة حقيقية', () {
    late DatabaseService db;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('ac_wipe_');
      await databaseFactory.setDatabasesPath(dir.path);
      db = DatabaseService();
    });

    tearDownAll(() => DatabaseService.teamModeEnabled = false);

    setUp(() async {
      final raw = await db.database;
      await raw.delete(TABLE_SYNC_OUTBOX);
      await raw.delete(TABLE_EXAMS);
      await raw.delete(TABLE_GROUPS); // CASCADE
      DatabaseService.teamModeEnabled = false;
    });

    Future<int> count(String table) async {
      final raw = await db.database;
      final r = await raw.rawQuery('SELECT COUNT(*) c FROM $table');
      return (r.first['c'] as int?) ?? 0;
    }

    Future<void> seed() async {
      final g = await db.insertGroup(Group(name: 'ثانية', price: 100));
      final s = await db.insertStudent(Student(
        name: 'منى',
        code: 'W1',
        groupId: g,
        price: 100,
        createdAt: DateTime(2026, 9, 1),
        attendanceStart: DateTime(2026, 9, 1),
      ));
      await db.insertAttendance(Attendance(
          studentId: s, date: DateTime(2026, 10, 1), status: ATTENDANCE_PRESENT));
      await db.insertPayment(
          Payment(studentId: s, date: DateTime(2026, 10, 2), amount: 100));
      await db.insertHomework(
          Homework(studentId: s, date: DateTime(2026, 10, 3), status: 'عمل'));
      await db.insertExam(
          Exam(name: 'اختبار', date: DateTime(2026, 10, 4)), [g]);
    }

    test('حذف الحضور بس: الدفعات والطلاب والامتحانات سليمين', () async {
      await seed();
      final r = await db.wipeScopes({WipeScope.attendance});
      expect(r[WipeScope.attendance], 1);
      expect(await count(TABLE_ATTENDANCE), 0);
      expect(await count(TABLE_PAYMENTS), 1);
      expect(await count(TABLE_STUDENTS), 1);
      expect(await count(TABLE_EXAMS), 1);
    });

    test('المعاينة بتعدّ الأقسام التابعة كمان', () async {
      await seed();
      final p = await db.countWipeScopes({WipeScope.students});
      expect(p[WipeScope.students], 1);
      expect(p[WipeScope.attendance], 1);
      expect(p[WipeScope.payments], 1);
      expect(p[WipeScope.homework], 1);
      expect(p.containsKey(WipeScope.groups), isFalse);
    });

    test('حذف الطلاب: بياناتهم تتحذف والمجموعات والامتحانات تفضل', () async {
      await seed();
      await db.wipeScopes({WipeScope.students});
      expect(await count(TABLE_STUDENTS), 0);
      expect(await count(TABLE_ATTENDANCE), 0);
      expect(await count(TABLE_PAYMENTS), 0);
      expect(await count(TABLE_HOMEWORK), 0);
      expect(await count(TABLE_GROUPS), 1);
      expect(await count(TABLE_EXAMS), 1);
    });

    test('حذف المجموعات: الطلاب وتوابعهم يتحذفوا والإعدادات تفضل', () async {
      await seed();
      final raw = await db.database;
      await db.setSetting('wipe_test_key', 'keep-me');
      await db.wipeScopes({WipeScope.groups});
      expect(await count(TABLE_GROUPS), 0);
      expect(await count(TABLE_STUDENTS), 0);
      expect(await count(TABLE_ATTENDANCE), 0);
      expect(await count(TABLE_PAYMENTS), 0);
      expect(await db.getSetting('wipe_test_key'), 'keep-me');
      expect(raw.isOpen, isTrue);
    });

    test('اختيار الكل: كل الجداول فاضية', () async {
      await seed();
      await db.wipeScopes(WipeScope.values.toSet());
      for (final t in [
        TABLE_GROUPS,
        TABLE_STUDENTS,
        TABLE_ATTENDANCE,
        TABLE_PAYMENTS,
        TABLE_HOMEWORK,
        TABLE_EXAMS,
        TABLE_EXAM_GROUPS,
      ]) {
        expect(await count(t), 0, reason: t);
      }
    });

    test('وضع الفريق: بيتطابور حذف للصفوف المُزامَنة', () async {
      await seed();
      DatabaseService.teamModeEnabled = true;
      final raw = await db.database;
      await raw.delete(TABLE_SYNC_OUTBOX);
      await db.wipeScopes({WipeScope.attendance, WipeScope.payments});
      final rows = await raw.query(TABLE_SYNC_OUTBOX,
          where: '$COL_OUTBOX_OP = ?', whereArgs: ['delete']);
      final tables = rows.map((r) => r[COL_OUTBOX_TABLE]).toSet();
      expect(tables, {TABLE_ATTENDANCE, TABLE_PAYMENTS});
      expect(rows.length, 2);
    });
  });
}
