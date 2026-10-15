// test/data_health_db_test.dart — spec 052: تنفيذ الدمج على قاعدة SQLite حقيقية
// (sqflite_common_ffi): الفحص ← الخطة ← applyMergePlan ← فحص الصفوف وطابور
// المزامنة وrollback.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/data_health_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/duplicate_detection.dart';
import 'package:active_class/utils/merge_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_data_health_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = DatabaseService();
  });

  tearDownAll(() {
    DatabaseService.teamModeEnabled = false;
  });

  setUp(() async {
    final raw = await db.database;
    await raw.delete(TABLE_SYNC_OUTBOX);
    await raw.delete(TABLE_GROUPS); // CASCADE على كل التوابع
    DatabaseService.teamModeEnabled = false;
  });

  // ── بيانات الاختبار: مجموعتين "Grade 2" + طالب مكرّر ─────────────────────
  Future<({int gA, int gB, int s1, int s2, int d1, int d3})> seed() async {
    final gA = await db.insertGroup(Group(name: 'Grade 2', price: 100));
    final gB = await db.insertGroup(Group(name: ' grade  2 ', price: 100));
    Student st(String name, String code, int g) => Student(
          name: name,
          code: code,
          groupId: g,
          price: 100,
          createdAt: DateTime(2026, 9, 1),
          attendanceStart: DateTime(2026, 9, 1),
        );
    final s1 = await db.insertStudent(st('منى أحمد', 'G201', gA));
    final s2 = await db.insertStudent(st('علي حسن', 'G202', gA));
    final d1 = await db.insertStudent(st('منى أحمد', 'G201-2', gB)); // مكرّر
    final d3 = await db.insertStudent(st('ياسمين', 'G299', gB)); // جديد

    Future<void> att(int s, int day, String status) => db
        .insertAttendance(Attendance(
            studentId: s, date: DateTime(2026, 10, day), status: status))
        .then((_) {});
    await att(s1, 1, ATTENDANCE_PRESENT);
    await att(s1, 2, ATTENDANCE_PRESENT);
    await att(s2, 1, ATTENDANCE_PRESENT);
    // بيانات إضافية للمجموعة A عشان تبقى هي الأساسية المقترحة (الأكتر بيانات).
    for (var d = 5; d <= 10; d++) {
      await att(s2, d, ATTENDANCE_PRESENT);
    }
    await att(d1, 1, ATTENDANCE_ABSENT); // نفس يوم s1 ← مكرّر + تعارض حالة
    await att(d1, 3, ATTENDANCE_PRESENT); // جديد ← يتنقل
    await att(d3, 1, ATTENDANCE_PRESENT);

    final payDup = DateTime(2026, 10, 1, 10, 0);
    await db.insertPayment(Payment(studentId: s1, date: payDup, amount: 100));
    await db.insertPayment(Payment(studentId: d1, date: payDup, amount: 100));
    await db.insertPayment(
        Payment(studentId: d1, date: DateTime(2026, 10, 5, 9), amount: 100));

    await db.insertHomework(
        Homework(studentId: d1, date: DateTime(2026, 10, 3), status: 'عمل'));
    return (gA: gA, gB: gB, s1: s1, s2: s2, d1: d1, d3: d3);
  }

  Future<int> count(String table, String where, List<Object?> args) async {
    final raw = await db.database;
    final r = await raw.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE $where', args);
    return r.first['c'] as int;
  }

  test('الفحص يلقط المجموعة المكرّرة والطالب بنفس الكود', () async {
    final ids = await seed();
    final scan = await DataHealthService().scan();
    expect(scan.groupCases.length, 1);
    expect(scan.groupCases.first.copies.map((c) => c.id).toSet(),
        {ids.gA, ids.gB});
    final codeCases = scan.studentCases
        .where((c) => c.reason == MatchReason.sameCode)
        .toList();
    expect(codeCases.length, 1);
    expect(codeCases.first.copies.map((c) => c.id).toSet(), {ids.s1, ids.d1});
    // d1 عنده سجلات أكتر من s1 (5 مقابل 3) ← هو الأساسي المقترح بتصميم الأداة.
    expect(codeCases.first.canonicalId, ids.d1);
  });

  test('دمج المجموعة + الطالب: الصفوف والأرقام صح وبلا يتامى', () async {
    final ids = await seed();
    final svc = DataHealthService();
    final scan = await svc.scan();
    final plan = await svc.buildPlan(
      groupCases: scan.groupCases,
      studentCases: const [], // الدمج المطابق بالاسم بيحصل تلقائيًا من المجموعة
    );
    final s = plan.summary;
    expect(s.groupsMerged, 1);
    expect(s.studentsMerged, 1); // منى فقط (المطابقة بالاسم)
    expect(s.studentsMovedToGroup, 1); // ياسمين
    expect(s.dropped['attendance'], 1); // يوم 1
    expect(s.moved['attendance'], 1); // يوم 3
    expect(s.dropped['payments'], 1);
    expect(s.moved['payments'], 1);
    expect(s.moved['homework'], 1);
    expect(s.conflicts, 1);

    final canonGroup = plan.groups.single.canonicalGroupId;
    final dupGroup = plan.groups.single.duplicateGroupId;

    final res = await db.applyMergePlan(plan);
    expect(res.studentsMerged, 1);

    // مجموعة واحدة فقط.
    expect(await count(TABLE_GROUPS, '1=1', const []), 1);
    expect(await count(TABLE_GROUPS, '$COL_GROUP_ID = ?', [canonGroup]), 1);
    expect(await count(TABLE_GROUPS, '$COL_GROUP_ID = ?', [dupGroup]), 0);

    // الطلاب: المكرّر اتشال، وياسمين انتقلت للأساسية.
    final survivor = plan.students.single.canonicalId;
    expect(await count(TABLE_STUDENTS, '1=1', const []), 3);
    expect(
        await count(TABLE_STUDENTS, '$COL_STUDENT_ID = ?',
            [plan.students.single.duplicateId]),
        0);
    expect(
        await count(TABLE_STUDENTS, '$COL_STUDENT_GROUP_ID = ?', [canonGroup]),
        3);

    // حضور الأساسي: يوم 1 (حاضر — سجله هو اللي فضل) + 2 + 3.
    expect(
        await count(
            TABLE_ATTENDANCE, '$COL_ATTENDANCE_STUDENT_ID = ?', [survivor]),
        3);
    expect(
        await count(
            TABLE_ATTENDANCE,
            '$COL_ATTENDANCE_STUDENT_ID = ? AND $COL_ATTENDANCE_STATUS = ?',
            [survivor, ATTENDANCE_ABSENT]),
        0,
        reason: 'حالة الأساسي (حاضر) هي اللي تفضل');
    // دفعتين (يوم 1 مرة واحدة + 5).
    expect(
        await count(TABLE_PAYMENTS, '$COL_PAYMENT_STUDENT_ID = ?', [survivor]),
        2);
    expect(
        await count(TABLE_HOMEWORK, '$COL_HOMEWORK_STUDENT_ID = ?', [survivor]),
        1);

    // مفيش صفوف يتيمة (طالب مش موجود).
    expect(
        await count(
            TABLE_ATTENDANCE,
            '$COL_ATTENDANCE_STUDENT_ID NOT IN (SELECT $COL_STUDENT_ID FROM $TABLE_STUDENTS)',
            const []),
        0);
    // ياسمين بحضورها لسه عندها.
    expect(
        await count(
            TABLE_ATTENDANCE, '$COL_ATTENDANCE_STUDENT_ID = ?', [ids.d3]),
        1);
  });

  test('طابور المزامنة: النقل قبل حذف المكرّر قبل حذف الطالب قبل المجموعة',
      () async {
    await seed();
    DatabaseService.teamModeEnabled = true;
    final svc = DataHealthService();
    final scan = await svc.scan();
    final plan = await svc
        .buildPlan(groupCases: scan.groupCases, studentCases: const []);
    await db.applyMergePlan(plan);

    final raw = await db.database;
    final rows = await raw.query(TABLE_SYNC_OUTBOX, orderBy: 'rowid ASC');
    expect(rows, isNotEmpty);

    // نستخرج (op, table) بالترتيب — أسماء الأعمدة بتتحدد من الجدول الفعلي.
    final cols = rows.first.keys.toList();
    final opCol = cols.firstWhere((c) => c == 'op' || c == 'operation',
        orElse: () => cols.firstWhere((c) => c.contains('op')));
    final tblCol = cols.firstWhere(
        (c) => c == 'table_name' || c == 'table' || c == 'tbl',
        orElse: () => cols.firstWhere((c) => c.contains('table')));
    final seq = [
      for (final r in rows) '${r[opCol]}:${r[tblCol]}',
    ];

    int firstOf(bool Function(String) f) => seq.indexWhere(f);
    int lastOf(bool Function(String) f) => seq.lastIndexWhere(f);

    final lastMoveUpdate =
        lastOf((s) => s.startsWith('update:') && s != 'update:$TABLE_STUDENTS');
    final firstStudentDelete = firstOf((s) => s == 'delete:$TABLE_STUDENTS');
    final groupDelete = lastOf((s) => s == 'delete:$TABLE_GROUPS');
    final firstChildDelete = firstOf((s) =>
        s.startsWith('delete:') &&
        s != 'delete:$TABLE_STUDENTS' &&
        s != 'delete:$TABLE_GROUPS');

    expect(lastMoveUpdate, greaterThanOrEqualTo(0));
    expect(firstStudentDelete, greaterThan(lastMoveUpdate));
    expect(firstChildDelete, greaterThan(lastMoveUpdate));
    expect(firstChildDelete, lessThan(firstStudentDelete));
    expect(groupDelete, greaterThan(firstStudentDelete));
  });

  test('rollback: فشل في النص ما يسيبش نص عملية', () async {
    final ids = await seed();
    final raw = await db.database;
    // حدث أرشفة متطابق عند الأساسي والمكرّر (فهرس UNIQUE).
    const at = '2026-09-10T10:00:00';
    await raw.insert(TABLE_STUDENT_ARCHIVE_EVENTS, {
      COL_SAE_STUDENT_ID: ids.s1,
      COL_SAE_TYPE: 'archived',
      COL_SAE_EVENT_AT: at,
    });
    final dupEv = await raw.insert(TABLE_STUDENT_ARCHIVE_EVENTS, {
      COL_SAE_STUDENT_ID: ids.d1,
      COL_SAE_TYPE: 'archived',
      COL_SAE_EVENT_AT: at,
    });
    final dupAtt = (await raw.query(TABLE_ATTENDANCE,
            where:
                '$COL_ATTENDANCE_STUDENT_ID = ? AND $COL_ATTENDANCE_DATE LIKE ?',
            whereArgs: [ids.d1, '2026-10-03%']))
        .single[COL_ATTENDANCE_ID] as int;

    // خطة مصنوعة بإيد: بتنقل الحضور (ينجح) وبعدين حدث الأرشفة (يفشل UNIQUE).
    final bad = MergePlan(
      students: [
        StudentMergePlan(
          canonicalId: ids.s1,
          duplicateId: ids.d1,
          moves: {
            'attendance': [RowRef(id: dupAtt)],
            'student_archive_events': [RowRef(id: dupEv)],
          },
          drops: const {},
          conflicts: const [],
        )
      ],
      groups: const [],
      summary: const MergeSummary(
          studentsMerged: 1,
          groupsMerged: 0,
          studentsMovedToGroup: 0,
          moved: {},
          dropped: {},
          conflicts: 0),
    );

    await expectLater(db.applyMergePlan(bad), throwsA(anything));

    // لا تغيير: المكرّر لسه موجود وحضوره لسه عنده.
    expect(await count(TABLE_STUDENTS, '$COL_STUDENT_ID = ?', [ids.d1]), 1);
    expect(
        await count(
            TABLE_ATTENDANCE,
            '$COL_ATTENDANCE_ID = ? AND $COL_ATTENDANCE_STUDENT_ID = ?',
            [dupAtt, ids.d1]),
        1);
  });

  test('حماية: أساسي = مكرّر أو أساسي غير موجود ← رفض بلا تعديل', () async {
    final ids = await seed();
    MergePlan planOf(int canon, int dup) => MergePlan(
          students: [
            StudentMergePlan(
                canonicalId: canon,
                duplicateId: dup,
                moves: const {},
                drops: const {},
                conflicts: const [])
          ],
          groups: const [],
          summary: const MergeSummary(
              studentsMerged: 1,
              groupsMerged: 0,
              studentsMovedToGroup: 0,
              moved: {},
              dropped: {},
              conflicts: 0),
        );
    await expectLater(
        db.applyMergePlan(planOf(ids.s1, ids.s1)), throwsA(isA<StateError>()));
    await expectLater(
        db.applyMergePlan(planOf(999999, ids.d1)), throwsA(isA<StateError>()));
    expect(await count(TABLE_STUDENTS, '1=1', const []), 4);
  });

  test('عدّاد المعلّق يعدّ synced=0 بس (الصفوف القديمة المتبعتة مش معلّقة)',
      () async {
    final raw = await db.database;
    Future<void> row(int synced) => raw.insert(TABLE_SYNC_OUTBOX, {
          COL_OUTBOX_TABLE: TABLE_STUDENTS,
          COL_OUTBOX_ROW_ID: 1,
          COL_OUTBOX_OP: 'update',
          COL_OUTBOX_SYNCED: synced,
        }).then((_) {});
    for (var i = 0; i < 5; i++) {
      await row(1); // متبعتة (تراكم نسخ قديمة)
    }
    await row(0);
    await row(0);
    expect(await db.pendingOutboxCount(), 2);
  });
}
