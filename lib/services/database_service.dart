// lib/services/database_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/services/auto_backup_service.dart';
import 'package:active_class/services/parent_portal_service.dart';

/// ملخص أعداد البيانات (مجموعات، طلاب، إلخ) في لحظة معيّنة.
class DataSummary {
  final int groups;
  final int students;
  final int attendanceRecords;
  final int payments;
  final int exams;
  const DataSummary({
    required this.groups,
    required this.students,
    required this.attendanceRecords,
    required this.payments,
    required this.exams,
  });
}

const String _attendanceDayUniqueIndexSql = '''
  CREATE UNIQUE INDEX IF NOT EXISTS idx_${TABLE_ATTENDANCE}_${COL_ATTENDANCE_STUDENT_ID}_day
  ON $TABLE_ATTENDANCE($COL_ATTENDANCE_STUDENT_ID, substr($COL_ATTENDANCE_DATE, 1, 10))
''';

const String _homeworkDayUniqueIndexSql = '''
  CREATE UNIQUE INDEX IF NOT EXISTS idx_${TABLE_HOMEWORK}_${COL_HOMEWORK_STUDENT_ID}_day
  ON $TABLE_HOMEWORK($COL_HOMEWORK_STUDENT_ID, substr($COL_HOMEWORK_DATE, 1, 10))
''';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DATABASE_NAME);

    return await openDatabase(
      path,
      version: DATABASE_VERSION,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Groups (v2 schema)
    await db.execute('''
      CREATE TABLE $TABLE_GROUPS (
        $COL_GROUP_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_GROUP_NAME TEXT NOT NULL UNIQUE,
        $COL_GROUP_CODE TEXT UNIQUE,
        $COL_GROUP_PRICE REAL,
        $COL_GROUP_COLOR INTEGER,
        $COL_GROUP_ICON TEXT,
        $COL_GROUP_SCHEDULE TEXT,
        $COL_GROUP_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_GROUP_PRICING_TYPE TEXT DEFAULT 'monthly',
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID TEXT
      )
    ''');

    // Students
    await db.execute('''
      CREATE TABLE $TABLE_STUDENTS (
        $COL_STUDENT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_STUDENT_NAME TEXT NOT NULL,
        $COL_STUDENT_CODE TEXT NOT NULL UNIQUE,
        $COL_STUDENT_GROUP_ID INTEGER NOT NULL,
        $COL_STUDENT_PRICE REAL NOT NULL,
        $COL_STUDENT_QR_PATH TEXT,
        $COL_STUDENT_SIBLING_ID INTEGER,
        $COL_STUDENT_SIBLINGS_TOTAL REAL,
        $COL_STUDENT_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_STUDENT_ATTENDANCE_START TEXT,
        $COL_STUDENT_GUARDIAN_PHONE TEXT,
        $COL_STUDENT_BIRTH_DATE TEXT,
        $COL_STUDENT_EXEMPT_PERCENT REAL DEFAULT 0,
        $COL_STUDENT_EXEMPT_REASON TEXT,
        $COL_STUDENT_IS_ARCHIVED INTEGER NOT NULL DEFAULT 0,
        $COL_STUDENT_ARCHIVED_AT TEXT,
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID TEXT,
        FOREIGN KEY($COL_STUDENT_GROUP_ID) REFERENCES $TABLE_GROUPS($COL_GROUP_ID) ON DELETE CASCADE
      )
    ''');

    // Attendance
    await db.execute('''
      CREATE TABLE $TABLE_ATTENDANCE (
        $COL_ATTENDANCE_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_ATTENDANCE_STUDENT_ID INTEGER NOT NULL,
        $COL_ATTENDANCE_DATE TEXT NOT NULL,
        $COL_ATTENDANCE_STATUS TEXT NOT NULL CHECK($COL_ATTENDANCE_STATUS IN ('$ATTENDANCE_PRESENT', '$ATTENDANCE_ABSENT')),
        $COL_ATTENDANCE_NOTES TEXT,
        $COL_ATTENDANCE_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID TEXT,
        UNIQUE($COL_ATTENDANCE_STUDENT_ID, $COL_ATTENDANCE_DATE),
        FOREIGN KEY($COL_ATTENDANCE_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');
    // القيد UNIQUE فوق على $COL_ATTENDANCE_DATE بالطابع الزمني الكامل (بالثانية)
    // ما بيمنعش فعليًا تكرار حضور نفس الطالب في نفس اليوم. الفهرس ده بياخد
    // أول 10 حروف بس من التاريخ (yyyy-MM-dd) فيمنع التكرار على مستوى اليوم فعليًا.
    await db.execute(_attendanceDayUniqueIndexSql);

    // الواجب — تسجيل حالة (عمل/لم يعمل) بس لكل طالب في كل تاريخ، من غير
    // نص الواجب نفسه (ده فاضل في الكشكول الورقي عمدًا، مش جوه التطبيق).
    await db.execute('''
      CREATE TABLE $TABLE_HOMEWORK (
        $COL_HOMEWORK_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_HOMEWORK_STUDENT_ID INTEGER NOT NULL,
        $COL_HOMEWORK_DATE TEXT NOT NULL,
        $COL_HOMEWORK_STATUS TEXT NOT NULL CHECK($COL_HOMEWORK_STATUS IN ('$HOMEWORK_DONE', '$HOMEWORK_NOT_DONE')),
        $COL_HOMEWORK_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID TEXT,
        FOREIGN KEY($COL_HOMEWORK_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');
    await db.execute(_homeworkDayUniqueIndexSql);

    // Payments
    await db.execute('''
      CREATE TABLE $TABLE_PAYMENTS (
        $COL_PAYMENT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_PAYMENT_STUDENT_ID INTEGER NOT NULL,
        $COL_PAYMENT_DATE TEXT NOT NULL,
        $COL_PAYMENT_AMOUNT REAL NOT NULL CHECK($COL_PAYMENT_AMOUNT > 0),
        $COL_PAYMENT_NOTE TEXT,
        $COL_PAYMENT_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID TEXT,
        FOREIGN KEY($COL_PAYMENT_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');

    // Report Logs
    await db.execute('''
      CREATE TABLE $TABLE_REPORT_LOGS (
        $COL_REPORT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_REPORT_STUDENT_ID INTEGER NOT NULL,
        $COL_REPORT_MONTH_START TEXT NOT NULL,
        $COL_REPORT_SENT_AT TEXT NOT NULL,
        UNIQUE($COL_REPORT_STUDENT_ID, $COL_REPORT_MONTH_START),
        FOREIGN KEY($COL_REPORT_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');

    // Exams
    await db.execute('''
      CREATE TABLE $TABLE_EXAMS (
        $COL_EXAM_ID            INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_EXAM_NAME          TEXT NOT NULL,
        $COL_EXAM_DATE          TEXT NOT NULL,
        $COL_EXAM_MAX_GRADE     REAL NOT NULL DEFAULT 100,
        $COL_EXAM_PASSING_GRADE REAL NOT NULL DEFAULT 50,
        $COL_EXAM_CREATED_AT    TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_SYNC_UPDATED_AT    TEXT,
        $COL_SYNC_REMOTE_ID     TEXT
      )
    ''');

    // Exam-Group junction
    await db.execute('''
      CREATE TABLE $TABLE_EXAM_GROUPS (
        $COL_EG_ID       INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_EG_EXAM_ID  INTEGER NOT NULL,
        $COL_EG_GROUP_ID INTEGER NOT NULL,
        $COL_SYNC_UPDATED_AT TEXT,
        $COL_SYNC_REMOTE_ID  TEXT,
        UNIQUE($COL_EG_EXAM_ID, $COL_EG_GROUP_ID),
        FOREIGN KEY($COL_EG_EXAM_ID)  REFERENCES $TABLE_EXAMS($COL_EXAM_ID)   ON DELETE CASCADE,
        FOREIGN KEY($COL_EG_GROUP_ID) REFERENCES $TABLE_GROUPS($COL_GROUP_ID) ON DELETE CASCADE
      )
    ''');

    // Exam Grades
    await db.execute('''
      CREATE TABLE $TABLE_EXAM_GRADES (
        $COL_GRADE_ID         INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_GRADE_EXAM_ID    INTEGER NOT NULL,
        $COL_GRADE_STUDENT_ID INTEGER NOT NULL,
        $COL_GRADE_VALUE      REAL,
        $COL_GRADE_NOTES      TEXT,
        $COL_GRADE_IS_ABSENT  INTEGER NOT NULL DEFAULT 0,
        $COL_GRADE_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
        $COL_SYNC_UPDATED_AT  TEXT,
        $COL_SYNC_REMOTE_ID   TEXT,
        UNIQUE($COL_GRADE_EXAM_ID, $COL_GRADE_STUDENT_ID),
        FOREIGN KEY($COL_GRADE_EXAM_ID)    REFERENCES $TABLE_EXAMS($COL_EXAM_ID)       ON DELETE CASCADE,
        FOREIGN KEY($COL_GRADE_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');

    // App settings (key/value) — اسم المعلم، العملة، تفضيلات الواجهة...
    await db.execute('''
      CREATE TABLE $TABLE_APP_SETTINGS (
        $COL_SETTING_KEY TEXT PRIMARY KEY,
        $COL_SETTING_VALUE TEXT
      )
    ''');

    // "وضع الفريق" — طابور التغييرات المحلية اللي محتاجة تتبعت
    // لسيرفر Supabase. الجدول ده فاضل دايمًا لغير مستخدمي وضع الفريق.
    await _createSyncOutboxTable(db);

    // Create indexes for performance optimization
    await _createIndexes(db);
  }

  Future<void> _createSyncOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $TABLE_SYNC_OUTBOX (
        $COL_OUTBOX_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_OUTBOX_TABLE TEXT NOT NULL,
        $COL_OUTBOX_ROW_ID INTEGER NOT NULL,
        $COL_OUTBOX_OP TEXT NOT NULL,
        $COL_OUTBOX_PAYLOAD TEXT,
        $COL_OUTBOX_CREATED_AT TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        $COL_OUTBOX_SYNCED INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_CODE TEXT');
      await db.execute(
          'ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_PRICE REAL');
      await db.execute(
          'ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_COLOR INTEGER');
      await db
          .execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_ICON TEXT');
      await db.execute(
          'ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_SCHEDULE TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_${TABLE_GROUPS}_$COL_GROUP_CODE '
        'ON $TABLE_GROUPS($COL_GROUP_CODE) '
        'WHERE $COL_GROUP_CODE IS NOT NULL',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_SIBLING_ID INTEGER');
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_SIBLINGS_TOTAL REAL');
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_ATTENDANCE_START TEXT');
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_GUARDIAN_PHONE TEXT');
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_BIRTH_DATE TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_EXEMPT_PERCENT REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_EXEMPT_REASON TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_REPORT_LOGS (
          $COL_REPORT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
          $COL_REPORT_STUDENT_ID INTEGER NOT NULL,
          $COL_REPORT_MONTH_START TEXT NOT NULL,
          $COL_REPORT_SENT_AT TEXT NOT NULL,
          UNIQUE($COL_REPORT_STUDENT_ID, $COL_REPORT_MONTH_START),
          FOREIGN KEY($COL_REPORT_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 7) {
      await _createIndexes(db);
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_EXAMS (
          $COL_EXAM_ID            INTEGER PRIMARY KEY AUTOINCREMENT,
          $COL_EXAM_NAME          TEXT NOT NULL,
          $COL_EXAM_DATE          TEXT NOT NULL,
          $COL_EXAM_MAX_GRADE     REAL NOT NULL DEFAULT 100,
          $COL_EXAM_PASSING_GRADE REAL NOT NULL DEFAULT 50,
          $COL_EXAM_CREATED_AT    TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_EXAM_GROUPS (
          $COL_EG_ID       INTEGER PRIMARY KEY AUTOINCREMENT,
          $COL_EG_EXAM_ID  INTEGER NOT NULL,
          $COL_EG_GROUP_ID INTEGER NOT NULL,
          UNIQUE($COL_EG_EXAM_ID, $COL_EG_GROUP_ID),
          FOREIGN KEY($COL_EG_EXAM_ID)  REFERENCES $TABLE_EXAMS($COL_EXAM_ID)   ON DELETE CASCADE,
          FOREIGN KEY($COL_EG_GROUP_ID) REFERENCES $TABLE_GROUPS($COL_GROUP_ID) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_EXAM_GRADES (
          $COL_GRADE_ID         INTEGER PRIMARY KEY AUTOINCREMENT,
          $COL_GRADE_EXAM_ID    INTEGER NOT NULL,
          $COL_GRADE_STUDENT_ID INTEGER NOT NULL,
          $COL_GRADE_VALUE      REAL,
          $COL_GRADE_NOTES      TEXT,
          $COL_GRADE_IS_ABSENT  INTEGER NOT NULL DEFAULT 0,
          $COL_GRADE_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE($COL_GRADE_EXAM_ID, $COL_GRADE_STUDENT_ID),
          FOREIGN KEY($COL_GRADE_EXAM_ID)    REFERENCES $TABLE_EXAMS($COL_EXAM_ID)       ON DELETE CASCADE,
          FOREIGN KEY($COL_GRADE_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 10) {
      // إضافة عمود is_absent
      try {
        await db.execute(
            'ALTER TABLE $TABLE_EXAM_GRADES ADD COLUMN $COL_GRADE_IS_ABSENT INTEGER NOT NULL DEFAULT 0');
      } catch (_) {} // قد يكون موجود لو التطبيق أُنشئ من الصفر بنسخة جديدة
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
            "ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_PRICING_TYPE TEXT DEFAULT 'monthly'");
      } catch (_) {}
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_APP_SETTINGS (
          $COL_SETTING_KEY TEXT PRIMARY KEY,
          $COL_SETTING_VALUE TEXT
        )
      ''');
    }
    if (oldVersion < 13) {
      // "وضع الفريق" — أعمدة مزامنة إضافية على الجداول القابلة
      // للمشاركة، وجدول طابور التغييرات. لا تأثير على أي حد لسه
      // مفعّلش الميزة دي — الأعمدة بتفضل null والجدول فاضي.
      for (final table in [
        TABLE_GROUPS,
        TABLE_STUDENTS,
        TABLE_ATTENDANCE,
        TABLE_PAYMENTS,
      ]) {
        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN $COL_SYNC_UPDATED_AT TEXT');
        } catch (_) {}
        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN $COL_SYNC_REMOTE_ID TEXT');
        } catch (_) {}
      }
      await _createSyncOutboxTable(db);
    }
    if (oldVersion < 14) {
      // نظف أي تكرار حضور موجود فعلاً (نفس الطالب/نفس اليوم) قبل إنشاء
      // الفهرس UNIQUE الجديد — وإلا فشل إنشاء الفهرس لو فيه تكرار سابق.
      // بيسيب أقدم سجل (أصغر id) ويحذف الباقي.
      await db.execute('''
        DELETE FROM $TABLE_ATTENDANCE
        WHERE $COL_ATTENDANCE_ID NOT IN (
          SELECT MIN($COL_ATTENDANCE_ID) FROM $TABLE_ATTENDANCE
          GROUP BY $COL_ATTENDANCE_STUDENT_ID, substr($COL_ATTENDANCE_DATE, 1, 10)
        )
      ''');
      await db.execute(_attendanceDayUniqueIndexSql);
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $TABLE_HOMEWORK (
          $COL_HOMEWORK_ID INTEGER PRIMARY KEY AUTOINCREMENT,
          $COL_HOMEWORK_STUDENT_ID INTEGER NOT NULL,
          $COL_HOMEWORK_DATE TEXT NOT NULL,
          $COL_HOMEWORK_STATUS TEXT NOT NULL CHECK($COL_HOMEWORK_STATUS IN ('$HOMEWORK_DONE', '$HOMEWORK_NOT_DONE')),
          $COL_HOMEWORK_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
          $COL_SYNC_UPDATED_AT TEXT,
          $COL_SYNC_REMOTE_ID TEXT,
          FOREIGN KEY($COL_HOMEWORK_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
        )
      ''');
      await db.execute(_homeworkDayUniqueIndexSql);
    }
    if (oldVersion < 16) {
      // مشاركة الامتحانات ودرجاتها في "وضع الفريق" — أعمدة مزامنة
      // إضافية على جداول الامتحانات، زي ما حصل مع باقي الجداول
      // المشتركة (v13) والواجب (v15). لا تأثير على أي حد لسه مفعّلش
      // وضع الفريق — الأعمدة بتفضل null.
      for (final table in [
        TABLE_EXAMS,
        TABLE_EXAM_GROUPS,
        TABLE_EXAM_GRADES,
      ]) {
        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN $COL_SYNC_UPDATED_AT TEXT');
        } catch (_) {}
        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN $COL_SYNC_REMOTE_ID TEXT');
        } catch (_) {}
      }
    }
    if (oldVersion < 17) {
      // أرشفة الطلاب (بديل الحذف النهائي) — عمودا حالة بس، بلا تأثير
      // على أي تثبيت لسه مستخدمش الميزة (كل الطلاب الحاليين is_archived=0).
      try {
        await db.execute(
            'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_IS_ARCHIVED INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_ARCHIVED_AT TEXT');
      } catch (_) {}
    }
  }

  // ─── إشعار الحفظ التلقائي ──────────────────────────────────────
  void _notifyChanged() => AutoBackupService().onDataChanged();

  // ─── "وضع الفريق" — طابور المزامنة ───────────────────────────────
  // بيتفعّل من TeamModeService لحظة تشغيل وضع الفريق بس — تكلفة صفر
  // (فحص bool واحد) لأي حد الميزة دي مش مفعّلة عنده.
  static bool teamModeEnabled = false;

  Future<void> _queueSync(
    String table,
    int rowId,
    String op, {
    Map<String, dynamic>? payload,
  }) async {
    if (!teamModeEnabled) return;
    final db = await database;
    await db.insert(TABLE_SYNC_OUTBOX, {
      COL_OUTBOX_TABLE: table,
      COL_OUTBOX_ROW_ID: rowId,
      COL_OUTBOX_OP: op,
      COL_OUTBOX_PAYLOAD: payload != null ? jsonEncode(payload) : null,
      COL_OUTBOX_CREATED_AT: DateTime.now().toIso8601String(),
      COL_OUTBOX_SYNCED: 0,
    });
  }

  /// نفس _queueSync بس مخصّصة للحذف — بتحفظ remote_id (لو الصف كان
  /// متزامن قبل الحذف) جوه الـ payload، عشان محرك المزامنة يقدر
  /// يستهدف الصف الصح على السيرفر حتى لو الصف الأصلي جه من جهاز تاني
  /// (زميل في نفس الفريق) — بدل ما يعتمد بس على origin_device_id
  /// الحالي، اللي بيفشل صامت في الحالة دي (راجع _pushOne).
  Future<void> _queueDelete(String table, int id, String? remoteId) {
    return _queueSync(table, id, 'delete',
        payload: remoteId != null ? {'remote_id': remoteId} : null);
  }

  // ========== GROUPS ==========
  Future<int> insertGroup(Group group) async {
    final db = await database;
    final map = {
      ...group.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final id = await db.insert(TABLE_GROUPS, map);
    _notifyChanged();
    await _queueSync(TABLE_GROUPS, id, 'insert', payload: {...map, COL_GROUP_ID: id});
    return id;
  }

  Future<List<Group>> getAllGroups() async {
    final db = await database;
    final result = await db.query(TABLE_GROUPS);
    return result.map((map) => Group.fromMap(map)).toList();
  }

  Future<Group?> getGroup(int id) async {
    final db = await database;
    final result = await db.query(
      TABLE_GROUPS,
      where: '$COL_GROUP_ID = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Group.fromMap(result.first);
  }

  Future<int> updateGroup(Group group) async {
    final db = await database;
    final map = {
      ...group.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final n = await db.update(
      TABLE_GROUPS,
      map,
      where: '$COL_GROUP_ID = ?',
      whereArgs: [group.id],
    );
    _notifyChanged();
    await _queueSync(TABLE_GROUPS, group.id!, 'update', payload: map);
    return n;
  }

  Future<int> deleteGroup(int id) async {
    final db = await database;
    // لازم نلقط أبناء المجموعة (طلاب/حضور/مدفوعات) قبل الحذف — لأن
    // PRAGMA foreign_keys=ON بيخلي SQLite يحذفهم تلقائيًا (CASCADE)
    // جوه محرك الداتابيز نفسه، من غير ما كود الداني يعدي عليهم، يعني
    // من غير الحذف اليدوي ده مستحيل نعرف إيه اللي اتحذف عشان نبلّغ
    // محرك المزامنة — وهتفضل نسخ يتيمة عند زمايل الفريق.
    final cascade = await _collectGroupCascadeIds(db, id);
    final groupRemoteId = await _remoteIdOf(db, TABLE_GROUPS, COL_GROUP_ID, id);
    // كمان لازم نلقط بيانات الطلاب (كود + تليفون ولي الأمر) قبل الحذف
    // — عشان بوابة متابعة أولياء الأمور، وإلا ملخصاتهم على Firestore
    // تفضل معروضة للأبد بعد ما يتمسحوا مع المجموعة.
    final studentRows =
        await db.query(TABLE_STUDENTS, where: '$COL_STUDENT_GROUP_ID = ?', whereArgs: [id]);
    final n = await db.delete(
      TABLE_GROUPS,
      where: '$COL_GROUP_ID = ?',
      whereArgs: [id],
    );
    _notifyChanged();
    for (final entry in cascade.attendanceIds.entries) {
      await _queueDelete(TABLE_ATTENDANCE, entry.key, entry.value);
    }
    for (final entry in cascade.paymentIds.entries) {
      await _queueDelete(TABLE_PAYMENTS, entry.key, entry.value);
    }
    for (final entry in cascade.studentIds.entries) {
      await _queueDelete(TABLE_STUDENTS, entry.key, entry.value);
    }
    await _queueDelete(TABLE_GROUPS, id, groupRemoteId);
    for (final row in studentRows) {
      unawaited(
          ParentPortalService().removeStudentSummary(Student.fromMap(row)));
    }
    return n;
  }

  /// remote_id الحالي لصف معيّن، لو كان متزامن قبل كده — لازم يتقرا
  /// قبل الحذف مباشرة، وإلا الصف يكون اتمسح محليًا ومفيش طريقة نعرفه
  /// بيها تاني.
  Future<String?> _remoteIdOf(
      DatabaseExecutor db, String table, String pkCol, int id) async {
    final rows = await db.query(table,
        columns: [COL_SYNC_REMOTE_ID], where: '$pkCol = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first[COL_SYNC_REMOTE_ID] as String?;
  }

  Future<_GroupCascadeIds> _collectGroupCascadeIds(Database db, int groupId) async {
    final students = await db.query(
      TABLE_STUDENTS,
      columns: [COL_STUDENT_ID, COL_SYNC_REMOTE_ID],
      where: '$COL_STUDENT_GROUP_ID = ?',
      whereArgs: [groupId],
    );
    final studentIds = {
      for (final e in students)
        e[COL_STUDENT_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
    };
    if (studentIds.isEmpty) {
      return _GroupCascadeIds(studentIds: {}, attendanceIds: {}, paymentIds: {});
    }
    final ids = studentIds.keys.toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final attendanceRows = await db.query(
      TABLE_ATTENDANCE,
      columns: [COL_ATTENDANCE_ID, COL_SYNC_REMOTE_ID],
      where: '$COL_ATTENDANCE_STUDENT_ID IN ($placeholders)',
      whereArgs: ids,
    );
    final paymentRows = await db.query(
      TABLE_PAYMENTS,
      columns: [COL_PAYMENT_ID, COL_SYNC_REMOTE_ID],
      where: '$COL_PAYMENT_STUDENT_ID IN ($placeholders)',
      whereArgs: ids,
    );
    return _GroupCascadeIds(
      studentIds: studentIds,
      attendanceIds: {
        for (final e in attendanceRows)
          e[COL_ATTENDANCE_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
      },
      paymentIds: {
        for (final e in paymentRows)
          e[COL_PAYMENT_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
      },
    );
  }

  Future<void> deleteStudentsByGroup(int groupId) async {
    final db = await database;
    // لبوابة متابعة أولياء الأمور — محتاجين كود/تليفون كل طالب قبل
    // ما يتمسحوا، وإلا ملخصاتهم تفضل معروضة للأبد على Firestore.
    final studentRowsForPortal = await db.query(TABLE_STUDENTS,
        where: '$COL_STUDENT_GROUP_ID = ?', whereArgs: [groupId]);
    Map<int, String?> studentIds = {};
    Map<int, String?> attendanceIds = {};
    Map<int, String?> paymentIds = {};
    await db.transaction((txn) async {
      final students = await txn.query(
        TABLE_STUDENTS,
        columns: [COL_STUDENT_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_STUDENT_GROUP_ID = ?',
        whereArgs: [groupId],
      );
      studentIds = {
        for (final e in students)
          e[COL_STUDENT_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
      };
      if (studentIds.isEmpty) return;
      final ids = studentIds.keys.toList();
      final placeholders = List.filled(ids.length, '?').join(',');

      final attendanceRows = await txn.query(
        TABLE_ATTENDANCE,
        columns: [COL_ATTENDANCE_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_ATTENDANCE_STUDENT_ID IN ($placeholders)',
        whereArgs: ids,
      );
      attendanceIds = {
        for (final e in attendanceRows)
          e[COL_ATTENDANCE_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
      };

      final paymentRows = await txn.query(
        TABLE_PAYMENTS,
        columns: [COL_PAYMENT_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_PAYMENT_STUDENT_ID IN ($placeholders)',
        whereArgs: ids,
      );
      paymentIds = {
        for (final e in paymentRows)
          e[COL_PAYMENT_ID] as int: e[COL_SYNC_REMOTE_ID] as String?
      };

      await txn.delete(
        TABLE_ATTENDANCE,
        where: '$COL_ATTENDANCE_STUDENT_ID IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete(
        TABLE_PAYMENTS,
        where: '$COL_PAYMENT_STUDENT_ID IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete(
        TABLE_STUDENTS,
        where: '$COL_STUDENT_ID IN ($placeholders)',
        whereArgs: ids,
      );
    });
    _notifyChanged();
    // لازم نبلّغ محرك المزامنة بكل صف اتحذف هنا — وإلا في وضع الفريق
    // هتفضل نسخ يتيمة (orphaned) من الطلاب/الحضور/المدفوعات دي على
    // جهاز المدرس نفسه (لو اتزامنت الطلاب قبل كده) وعلى أجهزة زمايله،
    // لأن الحذف الجماعي ده كان بيتم مباشرة من غير المرور بـ _queueSync.
    for (final entry in attendanceIds.entries) {
      await _queueDelete(TABLE_ATTENDANCE, entry.key, entry.value);
    }
    for (final entry in paymentIds.entries) {
      await _queueDelete(TABLE_PAYMENTS, entry.key, entry.value);
    }
    for (final entry in studentIds.entries) {
      await _queueDelete(TABLE_STUDENTS, entry.key, entry.value);
    }
    for (final row in studentRowsForPortal) {
      unawaited(
          ParentPortalService().removeStudentSummary(Student.fromMap(row)));
    }
  }

  Future<void> renumberStudentCodesByGroup({required int groupId}) async {
    final db = await database;
    final grp = await getGroup(groupId);
    final prefix = grp?.code;
    if (prefix == null || prefix.isEmpty) {
      throw Exception('لا يوجد كود للمجموعة');
    }
    final students = await db.query(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_GROUP_ID = ?',
      whereArgs: [groupId],
      orderBy: '$COL_STUDENT_CREATED_AT ASC, $COL_STUDENT_ID ASC',
    );
    int i = 1;
    for (final s in students) {
      final id = s[COL_STUDENT_ID] as int;
      final code = '$prefix${i.toString().padLeft(2, '0')}'
          .replaceAll(RegExp(r'\s+'), '');
      await db.update(
        TABLE_STUDENTS,
        {COL_STUDENT_CODE: code},
        where: '$COL_STUDENT_ID = ?',
        whereArgs: [id],
      );
      i++;
    }
    _notifyChanged();
  }

  // ========== STUDENTS ==========
  Future<int> insertStudent(Student student) async {
    final db = await database;
    final map = {
      ...student.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final id = await db.insert(TABLE_STUDENTS, map);
    _notifyChanged();
    await _queueSync(TABLE_STUDENTS, id, 'insert',
        payload: {...map, COL_STUDENT_ID: id});
    return id;
  }

  Future<List<Student>> getStudentsByGroup(int groupId) async {
    final db = await database;
    final result = await db.query(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_GROUP_ID = ?',
      whereArgs: [groupId],
      orderBy: COL_STUDENT_NAME,
    );
    return result.map((map) => Student.fromMap(map)).toList();
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final result = await db.query(TABLE_STUDENTS);
    return result.map((map) => Student.fromMap(map)).toList();
  }

  Future<Student?> getStudent(int id) async {
    final db = await database;
    final result = await db.query(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_ID = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Student.fromMap(result.first);
  }

  Future<Student?> getStudentByCode(String code) async {
    final db = await database;
    final result = await db.query(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_CODE = ?',
      whereArgs: [code],
    );
    if (result.isEmpty) return null;
    return Student.fromMap(result.first);
  }

  Future<int> updateStudent(Student student) async {
    final db = await database;
    final map = {
      ...student.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final n = await db.update(
      TABLE_STUDENTS,
      map,
      where: '$COL_STUDENT_ID = ?',
      whereArgs: [student.id],
    );
    _notifyChanged();
    await _queueSync(TABLE_STUDENTS, student.id!, 'update', payload: map);
    return n;
  }

  /// يربط طالبين كإخوة بتحديث الاثنين في عملية واحدة ذرية —
  /// إما يتحدّثوا مع بعض أو ولا واحد، عشان ميحصلش ربط باتجاه واحد بس
  /// لو فشل التحديث الثاني.
  Future<void> linkSiblings(Student s1, Student s2) async {
    final db = await database;
    final map1 = {...s1.toMap(), COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String()};
    final map2 = {...s2.toMap(), COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String()};
    await db.transaction((txn) async {
      await txn.update(TABLE_STUDENTS, map1,
          where: '$COL_STUDENT_ID = ?', whereArgs: [s1.id]);
      await txn.update(TABLE_STUDENTS, map2,
          where: '$COL_STUDENT_ID = ?', whereArgs: [s2.id]);
    });
    _notifyChanged();
    // كان الربط ده مش بيتبلّغ لمحرك المزامنة خالص — يفضل الإخوة مربوطين
    // على الجهاز ده بس ومش بيوصل للزميل.
    await _queueSync(TABLE_STUDENTS, s1.id!, 'update', payload: map1);
    await _queueSync(TABLE_STUDENTS, s2.id!, 'update', payload: map2);
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    // نفس سبب deleteGroup: الحضور والمدفوعات بتاعة الطالب ده هتتحذف
    // تلقائيًا بالـ CASCADE، فلازم نلقطهم الأول عشان نبلّغ المزامنة.
    final attendanceRows = await db.query(TABLE_ATTENDANCE,
        columns: [COL_ATTENDANCE_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_ATTENDANCE_STUDENT_ID = ?',
        whereArgs: [id]);
    final paymentRows = await db.query(TABLE_PAYMENTS,
        columns: [COL_PAYMENT_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_PAYMENT_STUDENT_ID = ?',
        whereArgs: [id]);
    final studentRemoteId =
        await _remoteIdOf(db, TABLE_STUDENTS, COL_STUDENT_ID, id);
    final n = await db.delete(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_ID = ?',
      whereArgs: [id],
    );
    _notifyChanged();
    for (final row in attendanceRows) {
      await _queueDelete(TABLE_ATTENDANCE, row[COL_ATTENDANCE_ID] as int,
          row[COL_SYNC_REMOTE_ID] as String?);
    }
    for (final row in paymentRows) {
      await _queueDelete(TABLE_PAYMENTS, row[COL_PAYMENT_ID] as int,
          row[COL_SYNC_REMOTE_ID] as String?);
    }
    await _queueDelete(TABLE_STUDENTS, id, studentRemoteId);
    return n;
  }

  /// أرشفة طالب (بديل ناعم للحذف) — بياناته وسجله التاريخي (حضور،
  /// مدفوعات، درجات) يفضلوا كاملين بدون حذف، بس بيختفي من الشاشات
  /// النشطة. لو مرتبط بعرض إخوة، بيتفكّ الربط على الطرفين — وإلا
  /// الطالب النشط الباقي كان هيتحسب عليه نصيبه من siblingsTotal (نص
  /// السعر) رغم إنه بيدفع لوحده دلوقتي، وتتراكم عليه مديونية غلط
  /// (نفس فئة الباج اللي اتصلح في عرض الإخوة العادي هذه الجلسة).
  Future<void> archiveStudent(int studentId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final rows = await db.query(TABLE_STUDENTS,
        where: '$COL_STUDENT_ID = ?', whereArgs: [studentId], limit: 1);
    if (rows.isEmpty) return;
    final student = Student.fromMap(rows.first);

    await db.transaction((txn) async {
      await txn.update(
        TABLE_STUDENTS,
        {
          COL_STUDENT_IS_ARCHIVED: 1,
          COL_STUDENT_ARCHIVED_AT: now,
          COL_SYNC_UPDATED_AT: now,
        },
        where: '$COL_STUDENT_ID = ?',
        whereArgs: [studentId],
      );
      if (student.siblingId != null) {
        await txn.update(
          TABLE_STUDENTS,
          {
            COL_STUDENT_SIBLING_ID: null,
            COL_STUDENT_SIBLINGS_TOTAL: null,
            COL_SYNC_UPDATED_AT: now,
          },
          where: '$COL_STUDENT_ID = ?',
          whereArgs: [studentId],
        );
        await txn.update(
          TABLE_STUDENTS,
          {
            COL_STUDENT_SIBLING_ID: null,
            COL_STUDENT_SIBLINGS_TOTAL: null,
            COL_SYNC_UPDATED_AT: now,
          },
          where: '$COL_STUDENT_ID = ?',
          whereArgs: [student.siblingId],
        );
      }
    });
    _notifyChanged();

    await _queueSync(TABLE_STUDENTS, studentId, 'update', payload: {
      ...student.toMap(),
      COL_STUDENT_IS_ARCHIVED: 1,
      COL_STUDENT_ARCHIVED_AT: now,
      COL_STUDENT_SIBLING_ID: null,
      COL_STUDENT_SIBLINGS_TOTAL: null,
      COL_SYNC_UPDATED_AT: now,
    });
    if (student.siblingId != null) {
      final sibRows = await db.query(TABLE_STUDENTS,
          where: '$COL_STUDENT_ID = ?', whereArgs: [student.siblingId], limit: 1);
      if (sibRows.isNotEmpty) {
        await _queueSync(TABLE_STUDENTS, student.siblingId!, 'update', payload: {
          ...Student.fromMap(sibRows.first).toMap(),
          COL_SYNC_UPDATED_AT: now,
        });
      }
    }
  }

  /// استعادة طالب مؤرشف — يرجع نشط بسجله القديم كامل زي ما كان (عرض
  /// الإخوة اللي اتفك وقت الأرشفة مش بيترجع تلقائيًا؛ المدرس يقدر
  /// يربطه تاني يدويًا لو لسه محتاج).
  Future<void> unarchiveStudent(int studentId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final map = {
      COL_STUDENT_IS_ARCHIVED: 0,
      COL_STUDENT_ARCHIVED_AT: null,
      COL_SYNC_UPDATED_AT: now,
    };
    await db.update(TABLE_STUDENTS, map,
        where: '$COL_STUDENT_ID = ?', whereArgs: [studentId]);
    _notifyChanged();

    final rows = await db.query(TABLE_STUDENTS,
        where: '$COL_STUDENT_ID = ?', whereArgs: [studentId], limit: 1);
    if (rows.isNotEmpty) {
      await _queueSync(TABLE_STUDENTS, studentId, 'update',
          payload: Student.fromMap(rows.first).toMap()
            ..[COL_SYNC_UPDATED_AT] = now);
    }
  }

  Future<List<Student>> getActiveStudents() async {
    final db = await database;
    final result = await db.query(TABLE_STUDENTS,
        where: '$COL_STUDENT_IS_ARCHIVED = 0');
    return result.map((map) => Student.fromMap(map)).toList();
  }

  Future<List<Student>> getArchivedStudents() async {
    final db = await database;
    final result = await db.query(TABLE_STUDENTS,
        where: '$COL_STUDENT_IS_ARCHIVED = 1');
    return result.map((map) => Student.fromMap(map)).toList();
  }

  /// عدد كل الطلاب (نشط + مؤرشف) — يُستخدم لفحص حد الباقة، اللي المفروض
  /// يستمر يحسب الطالب المؤرشف زيه زي أي طالب نشط تمامًا (الأرشفة مش
  /// بتفضّي مكان في حد الترخيص).
  Future<int> getAllStudentsCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $TABLE_STUDENTS');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getGroupStudentCount(int groupId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $TABLE_STUDENTS WHERE $COL_STUDENT_GROUP_ID = ?',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// عدد الطلاب المؤرشفين في مجموعة معيّنة — يُستخدم لمنع حذف المجموعة
  /// طالما فيها مؤرشفون (راجع specs/006-archived-group-delete-protection):
  /// حذف المجموعة بيمسح كل طلابها نهائيًا (ON DELETE CASCADE) بما فيهم
  /// المؤرشفين، رغم إن الأرشفة مصمَّمة كـ"بديل الحذف النهائي".
  Future<int> getArchivedStudentCountForGroup(int groupId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $TABLE_STUDENTS '
      'WHERE $COL_STUDENT_GROUP_ID = ? AND $COL_STUDENT_IS_ARCHIVED = 1',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== ATTENDANCE ==========
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    final map = {
      ...attendance.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final id = await db.insert(TABLE_ATTENDANCE, map);
    _notifyChanged();
    await _queueSync(TABLE_ATTENDANCE, id, 'insert',
        payload: {...map, COL_ATTENDANCE_ID: id});
    return id;
  }

  Future<List<Attendance>> getAttendanceByStudent(int studentId) async {
    final db = await database;
    final result = await db.query(
      TABLE_ATTENDANCE,
      where: '$COL_ATTENDANCE_STUDENT_ID = ?',
      whereArgs: [studentId],
      orderBy: '$COL_ATTENDANCE_DATE DESC',
    );
    return result.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAllAttendance() async {
    final db = await database;
    final result = await db.query(
      TABLE_ATTENDANCE,
      orderBy: '$COL_ATTENDANCE_DATE DESC',
    );
    return result.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<Attendance?> getAttendance(int id) async {
    final db = await database;
    final result = await db.query(
      TABLE_ATTENDANCE,
      where: '$COL_ATTENDANCE_ID = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Attendance.fromMap(result.first);
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final db = await database;
    final map = {
      ...attendance.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final n = await db.update(
      TABLE_ATTENDANCE,
      map,
      where: '$COL_ATTENDANCE_ID = ?',
      whereArgs: [attendance.id],
    );
    _notifyChanged();
    await _queueSync(TABLE_ATTENDANCE, attendance.id!, 'update', payload: map);
    return n;
  }

  Future<int> deleteAttendance(int id) async {
    final db = await database;
    final remoteId = await _remoteIdOf(db, TABLE_ATTENDANCE, COL_ATTENDANCE_ID, id);
    final n = await db.delete(
      TABLE_ATTENDANCE,
      where: '$COL_ATTENDANCE_ID = ?',
      whereArgs: [id],
    );
    _notifyChanged();
    await _queueDelete(TABLE_ATTENDANCE, id, remoteId);
    return n;
  }

  // ========== HOMEWORK ==========
  Future<int> insertHomework(Homework homework) async {
    final db = await database;
    final map = {
      ...homework.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final id = await db.insert(TABLE_HOMEWORK, map);
    _notifyChanged();
    await _queueSync(TABLE_HOMEWORK, id, 'insert',
        payload: {...map, COL_HOMEWORK_ID: id});
    return id;
  }

  Future<int> updateHomework(Homework homework) async {
    final db = await database;
    final map = {
      ...homework.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final n = await db.update(
      TABLE_HOMEWORK,
      map,
      where: '$COL_HOMEWORK_ID = ?',
      whereArgs: [homework.id],
    );
    _notifyChanged();
    await _queueSync(TABLE_HOMEWORK, homework.id!, 'update', payload: map);
    return n;
  }

  Future<int> deleteHomework(int id) async {
    final db = await database;
    final remoteId = await _remoteIdOf(db, TABLE_HOMEWORK, COL_HOMEWORK_ID, id);
    final n = await db.delete(
      TABLE_HOMEWORK,
      where: '$COL_HOMEWORK_ID = ?',
      whereArgs: [id],
    );
    _notifyChanged();
    await _queueDelete(TABLE_HOMEWORK, id, remoteId);
    return n;
  }

  Future<List<Homework>> getHomeworkByStudent(int studentId) async {
    final db = await database;
    final result = await db.query(
      TABLE_HOMEWORK,
      where: '$COL_HOMEWORK_STUDENT_ID = ?',
      whereArgs: [studentId],
      orderBy: '$COL_HOMEWORK_DATE DESC',
    );
    return result.map((map) => Homework.fromMap(map)).toList();
  }

  Future<List<Homework>> getAllHomework() async {
    final db = await database;
    final result = await db.query(TABLE_HOMEWORK, orderBy: '$COL_HOMEWORK_DATE DESC');
    return result.map((map) => Homework.fromMap(map)).toList();
  }

  // ========== PAYMENTS ==========
  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    final map = {
      ...payment.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final id = await db.insert(TABLE_PAYMENTS, map);
    _notifyChanged();
    await _queueSync(TABLE_PAYMENTS, id, 'insert',
        payload: {...map, COL_PAYMENT_ID: id});
    return id;
  }

  Future<List<Payment>> getPaymentsByStudent(int studentId) async {
    final db = await database;
    final result = await db.query(
      TABLE_PAYMENTS,
      where: '$COL_PAYMENT_STUDENT_ID = ?',
      whereArgs: [studentId],
      orderBy: '$COL_PAYMENT_DATE DESC',
    );
    return result.map((map) => Payment.fromMap(map)).toList();
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final result = await db.query(
      TABLE_PAYMENTS,
      orderBy: '$COL_PAYMENT_DATE DESC',
    );
    return result.map((map) => Payment.fromMap(map)).toList();
  }

  Future<Payment?> getPayment(int id) async {
    final db = await database;
    final result = await db.query(
      TABLE_PAYMENTS,
      where: '$COL_PAYMENT_ID = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Payment.fromMap(result.first);
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await database;
    final map = {
      ...payment.toMap(),
      COL_SYNC_UPDATED_AT: DateTime.now().toIso8601String(),
    };
    final n = await db.update(
      TABLE_PAYMENTS,
      map,
      where: '$COL_PAYMENT_ID = ?',
      whereArgs: [payment.id],
    );
    _notifyChanged();
    await _queueSync(TABLE_PAYMENTS, payment.id!, 'update', payload: map);
    return n;
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    final remoteId = await _remoteIdOf(db, TABLE_PAYMENTS, COL_PAYMENT_ID, id);
    final n = await db.delete(
      TABLE_PAYMENTS,
      where: '$COL_PAYMENT_ID = ?',
      whereArgs: [id],
    );
    _notifyChanged();
    await _queueDelete(TABLE_PAYMENTS, id, remoteId);
    return n;
  }

  /// ملخص أعداد البيانات الحالية — يُستخدم في رسائل تأكيد النسخ
  /// الاحتياطي والحذف عشان المستخدم يشوف بالظبط قد إيه اتحفظ/اتحذف.
  Future<DataSummary> getDataSummary() async {
    final db = await database;
    Future<int> count(String table) async {
      final r = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
      return (r.first['c'] as int?) ?? 0;
    }

    final counts = await Future.wait([
      count(TABLE_GROUPS),
      count(TABLE_STUDENTS),
      count(TABLE_ATTENDANCE),
      count(TABLE_PAYMENTS),
      count(TABLE_EXAMS),
    ]);
    return DataSummary(
      groups: counts[0],
      students: counts[1],
      attendanceRecords: counts[2],
      payments: counts[3],
      exams: counts[4],
    );
  }

  /// Delete all app data from the database in a safe order
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete children first to avoid FK issues (even if FKs are disabled)
      await txn.delete(TABLE_ATTENDANCE);
      await txn.delete(TABLE_PAYMENTS);
      await txn.delete(TABLE_EXAM_GRADES);
      await txn.delete(TABLE_EXAM_GROUPS);
      await txn.delete(TABLE_EXAMS);
      await txn.delete(TABLE_REPORT_LOGS);
      await txn.delete(TABLE_STUDENTS);
      await txn.delete(TABLE_GROUPS);
    });
    // لا نُشعر الحفظ التلقائي هنا — البيانات محذوفة
  }

  /// خاص بوضع الفريق — على جهاز المساعد بس. بتمسح كل البيانات اللي
  /// جاية من مزامنة الفريق (لها sync_remote_id) بدون ما تلمس أي بيانات
  /// محلية بحتة كان عند المساعد قبل ما ينضم للفريق أصلاً (مفيهاش
  /// remote_id لأنها ماتبعتتش/اتزامنتش أبدًا). بتتنادى عند تسجيل خروج
  /// المساعد، أو تعطيل وضع الفريق عنده، أو إزالته من الفريق — عشان
  /// بيانات المدرس متفضلش ظاهرة على جهازه بعد كده.
  ///
  /// ملحوظة: نفس الفلتر ده (sync_remote_id IS NOT NULL) ميتستخدمش على
  /// جهاز المدرس (owner) — بياناته هو نفسها بتاخد remote_id بعد ما
  /// يفعّل وضع الفريق، فمسحها هنا كانت هتمسح بياناته الحقيقية بالغلط.
  Future<void> clearTeamSyncedData() async {
    final db = await database;
    await db.transaction((txn) async {
      const where = '$COL_SYNC_REMOTE_ID IS NOT NULL';
      await txn.delete(TABLE_ATTENDANCE, where: where);
      await txn.delete(TABLE_PAYMENTS, where: where);
      await txn.delete(TABLE_STUDENTS, where: where);
      await txn.delete(TABLE_GROUPS, where: where);
      for (final table in [
        TABLE_GROUPS,
        TABLE_STUDENTS,
        TABLE_ATTENDANCE,
        TABLE_PAYMENTS,
      ]) {
        await txn.delete(TABLE_SYNC_OUTBOX,
            where: '$COL_OUTBOX_TABLE = ?', whereArgs: [table]);
      }
    });
  }

  // ========== APP SETTINGS (key/value) ==========
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      TABLE_APP_SETTINGS,
      where: '$COL_SETTING_KEY = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first[COL_SETTING_VALUE] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      TABLE_APP_SETTINGS,
      {COL_SETTING_KEY: key, COL_SETTING_VALUE: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getTotalPaymentsByStudent(int studentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM($COL_PAYMENT_AMOUNT) as total FROM $TABLE_PAYMENTS WHERE $COL_PAYMENT_STUDENT_ID = ?',
      [studentId],
    );
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  Future<DateTime?> getReportSentAt(int studentId, DateTime monthStart) async {
    final db = await database;
    final m = DateTime(monthStart.year, monthStart.month, 1);
    final res = await db.query(
      TABLE_REPORT_LOGS,
      where: '$COL_REPORT_STUDENT_ID = ? AND $COL_REPORT_MONTH_START = ?',
      whereArgs: [studentId, m.toIso8601String()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return DateTime.parse(res.first[COL_REPORT_SENT_AT] as String);
  }

  Future<Map<int, DateTime>> getReportSentMap(
      List<int> studentIds, DateTime monthStart) async {
    if (studentIds.isEmpty) return {};
    final db = await database;
    final m = DateTime(monthStart.year, monthStart.month, 1).toIso8601String();
    final placeholders = List.filled(studentIds.length, '?').join(',');
    final res = await db.query(
      TABLE_REPORT_LOGS,
      where:
          '$COL_REPORT_MONTH_START = ? AND $COL_REPORT_STUDENT_ID IN ($placeholders)',
      whereArgs: [m, ...studentIds],
    );
    final map = <int, DateTime>{};
    for (final row in res) {
      map[row[COL_REPORT_STUDENT_ID] as int] =
          DateTime.parse(row[COL_REPORT_SENT_AT] as String);
    }
    return map;
  }

  Future<void> upsertReportLog(
      int studentId, DateTime monthStart, DateTime sentAt) async {
    final db = await database;
    final m = DateTime(monthStart.year, monthStart.month, 1).toIso8601String();
    await db.insert(
      TABLE_REPORT_LOGS,
      {
        COL_REPORT_STUDENT_ID: studentId,
        COL_REPORT_MONTH_START: m,
        COL_REPORT_SENT_AT: sentAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged();
  }

  Future<void> _createIndexes(Database db) async {
    // Indexes for Students table
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_group_id '
      'ON $TABLE_STUDENTS($COL_STUDENT_GROUP_ID)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_name '
      'ON $TABLE_STUDENTS($COL_STUDENT_NAME)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_code '
      'ON $TABLE_STUDENTS($COL_STUDENT_CODE)',
    );

    // Indexes for Attendance table
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_student_id '
      'ON $TABLE_ATTENDANCE($COL_ATTENDANCE_STUDENT_ID)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_date '
      'ON $TABLE_ATTENDANCE($COL_ATTENDANCE_DATE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attendance_status '
      'ON $TABLE_ATTENDANCE($COL_ATTENDANCE_STATUS)',
    );

    // Indexes for Payments table
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_student_id '
      'ON $TABLE_PAYMENTS($COL_PAYMENT_STUDENT_ID)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_date '
      'ON $TABLE_PAYMENTS($COL_PAYMENT_DATE)',
    );

    // Indexes for Report Logs table
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_logs_student_id '
      'ON $TABLE_REPORT_LOGS($COL_REPORT_STUDENT_ID)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_report_logs_month_start '
      'ON $TABLE_REPORT_LOGS($COL_REPORT_MONTH_START)',
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ========== EXAMS ==========

  /// إنشاء امتحان جديد وربطه بالمجموعات المختارة
  Future<int> insertExam(Exam exam, List<int> groupIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final egRows = <Map<String, int>>[]; // {egId, groupId}

    final examId = await db.transaction((txn) async {
      final examId = await txn.insert(TABLE_EXAMS, {
        COL_EXAM_NAME: exam.name,
        COL_EXAM_DATE: exam.date.toIso8601String(),
        COL_EXAM_MAX_GRADE: exam.maxGrade,
        COL_EXAM_PASSING_GRADE: exam.passingGrade,
        COL_SYNC_UPDATED_AT: now,
      });

      for (final gId in groupIds) {
        final egId = await txn.insert(TABLE_EXAM_GROUPS, {
          COL_EG_EXAM_ID: examId,
          COL_EG_GROUP_ID: gId,
          COL_SYNC_UPDATED_AT: now,
        });
        egRows.add({'egId': egId, 'groupId': gId});
      }
      _notifyChanged();
      return examId;
    });

    await _queueSync(TABLE_EXAMS, examId, 'insert', payload: {
      ...exam.copyWith(id: examId).toMap(),
      COL_SYNC_UPDATED_AT: now,
    });
    for (final eg in egRows) {
      await _queueSync(TABLE_EXAM_GROUPS, eg['egId']!, 'insert', payload: {
        COL_EG_EXAM_ID: examId,
        COL_EG_GROUP_ID: eg['groupId'],
        COL_SYNC_UPDATED_AT: now,
      });
    }
    return examId;
  }

  /// جلب كل الامتحانات مع قوائم مجموعاتها
  Future<List<Exam>> getAllExams() async {
    final db = await database;
    final rows = await db.query(TABLE_EXAMS, orderBy: '$COL_EXAM_DATE DESC');
    final exams = <Exam>[];
    for (final row in rows) {
      final id = row[COL_EXAM_ID] as int;
      final gRows = await db.query(TABLE_EXAM_GROUPS,
          columns: [COL_EG_GROUP_ID],
          where: '$COL_EG_EXAM_ID = ?',
          whereArgs: [id]);
      final groupIds = gRows.map((r) => r[COL_EG_GROUP_ID] as int).toList();
      exams.add(Exam.fromMap(row).copyWith(groupIds: groupIds));
    }
    return exams;
  }

  /// جلب امتحانات مجموعة معينة
  Future<List<Exam>> getExamsForGroup(int groupId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT e.* FROM $TABLE_EXAMS e
      INNER JOIN $TABLE_EXAM_GROUPS eg ON e.$COL_EXAM_ID = eg.$COL_EG_EXAM_ID
      WHERE eg.$COL_EG_GROUP_ID = ?
      ORDER BY e.$COL_EXAM_DATE DESC
    ''', [groupId]);
    return rows.map(Exam.fromMap).toList();
  }

  /// أسماء المجموعات المرتبطة حالياً بامتحان معين واللي هتتشال (مش
  /// موجودة في [keepGroupIds]) لكن عندها درجات مُدخلة بالفعل لهذا
  /// الامتحان — بنستخدمها عشان نمنع التعديل من إخفاء درجات بصمت.
  Future<List<String>> groupsWithGradesNotIn(
      int examId, List<int> keepGroupIds) async {
    final db = await database;
    final notInClause = keepGroupIds.isEmpty
        ? ''
        : 'AND eg.$COL_EG_GROUP_ID NOT IN (${keepGroupIds.map((_) => '?').join(',')})';
    final rows = await db.rawQuery('''
      SELECT DISTINCT g.$COL_GROUP_NAME AS name
      FROM $TABLE_EXAM_GROUPS eg
      INNER JOIN $TABLE_GROUPS g ON g.$COL_GROUP_ID = eg.$COL_EG_GROUP_ID
      WHERE eg.$COL_EG_EXAM_ID = ? $notInClause
        AND EXISTS (
          SELECT 1 FROM $TABLE_EXAM_GRADES eg2
          INNER JOIN $TABLE_STUDENTS s ON s.$COL_STUDENT_ID = eg2.$COL_GRADE_STUDENT_ID
          WHERE eg2.$COL_GRADE_EXAM_ID = ? AND s.$COL_STUDENT_GROUP_ID = eg.$COL_EG_GROUP_ID
            AND (eg2.$COL_GRADE_VALUE IS NOT NULL OR eg2.$COL_GRADE_IS_ABSENT = 1)
        )
    ''', [examId, ...keepGroupIds, examId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<int> updateExam(Exam exam, List<int> groupIds) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // لازم نلقط remote_id بتاع صفوف exam_groups القديمة قبل ما نحذفها —
    // وإلا محرك المزامنة مش هيعرف يستهدف الصف الصح عند الطرف التاني
    // (راجع _queueDelete).
    final oldEg = await db.query(TABLE_EXAM_GROUPS,
        columns: [COL_EG_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_EG_EXAM_ID = ?', whereArgs: [exam.id]);
    final egRows = <Map<String, int>>[]; // {egId, groupId}

    await db.transaction((txn) async {
      await txn.update(
          TABLE_EXAMS,
          {
            COL_EXAM_NAME: exam.name,
            COL_EXAM_DATE: exam.date.toIso8601String(),
            COL_EXAM_MAX_GRADE: exam.maxGrade,
            COL_EXAM_PASSING_GRADE: exam.passingGrade,
            COL_SYNC_UPDATED_AT: now,
          },
          where: '$COL_EXAM_ID = ?',
          whereArgs: [exam.id]);

      await txn.delete(TABLE_EXAM_GROUPS,
          where: '$COL_EG_EXAM_ID = ?', whereArgs: [exam.id]);
      for (final gId in groupIds) {
        final egId = await txn.insert(TABLE_EXAM_GROUPS, {
          COL_EG_EXAM_ID: exam.id,
          COL_EG_GROUP_ID: gId,
          COL_SYNC_UPDATED_AT: now,
        });
        egRows.add({'egId': egId, 'groupId': gId});
      }
      _notifyChanged();
    });

    await _queueSync(TABLE_EXAMS, exam.id!, 'update', payload: {
      ...exam.toMap(),
      COL_SYNC_UPDATED_AT: now,
    });
    for (final old in oldEg) {
      await _queueDelete(TABLE_EXAM_GROUPS, old[COL_EG_ID] as int,
          old[COL_SYNC_REMOTE_ID] as String?);
    }
    for (final eg in egRows) {
      await _queueSync(TABLE_EXAM_GROUPS, eg['egId']!, 'insert', payload: {
        COL_EG_EXAM_ID: exam.id,
        COL_EG_GROUP_ID: eg['groupId'],
        COL_SYNC_UPDATED_AT: now,
      });
    }
    return exam.id!;
  }

  Future<void> deleteExam(int examId) async {
    final db = await database;

    // لازم نلقط remote_id بتاع الامتحان نفسه وكل صفوف exam_groups/
    // exam_grades التابعة له قبل الحذف — الحذف المحلي هيمسحهم كلهم
    // بالـcascade، وبعدين مش هنقدر نعرف remote_id بتوعهم عشان نبلّغ
    // الطرف التاني يحذفهم هو كمان.
    final examRow = await db.query(TABLE_EXAMS,
        columns: [COL_SYNC_REMOTE_ID],
        where: '$COL_EXAM_ID = ?', whereArgs: [examId], limit: 1);
    final examRemoteId =
        examRow.isNotEmpty ? examRow.first[COL_SYNC_REMOTE_ID] as String? : null;
    final egRows = await db.query(TABLE_EXAM_GROUPS,
        columns: [COL_EG_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_EG_EXAM_ID = ?', whereArgs: [examId]);
    final gradeRows = await db.query(TABLE_EXAM_GRADES,
        columns: [COL_GRADE_ID, COL_SYNC_REMOTE_ID],
        where: '$COL_GRADE_EXAM_ID = ?', whereArgs: [examId]);

    await db
        .delete(TABLE_EXAMS, where: '$COL_EXAM_ID = ?', whereArgs: [examId]);
    _notifyChanged();

    for (final row in gradeRows) {
      await _queueDelete(TABLE_EXAM_GRADES, row[COL_GRADE_ID] as int,
          row[COL_SYNC_REMOTE_ID] as String?);
    }
    for (final row in egRows) {
      await _queueDelete(TABLE_EXAM_GROUPS, row[COL_EG_ID] as int,
          row[COL_SYNC_REMOTE_ID] as String?);
    }
    await _queueDelete(TABLE_EXAMS, examId, examRemoteId);
  }

  // ========== EXAM GRADES ==========

  /// جلب درجات طلاب مجموعة في امتحان معين
  Future<List<ExamGrade>> getGradesForExamGroup(int examId, int groupId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        s.$COL_STUDENT_ID   AS student_id,
        s.$COL_STUDENT_NAME AS student_name,
        eg.$COL_GRADE_ID    AS id,
        eg.$COL_GRADE_EXAM_ID,
        eg.$COL_GRADE_VALUE       AS grade,
        eg.$COL_GRADE_NOTES       AS notes,
        eg.$COL_GRADE_IS_ABSENT   AS is_absent,
        eg.$COL_GRADE_CREATED_AT  AS created_at,
        e.$COL_EXAM_MAX_GRADE     AS max_grade,
        e.$COL_EXAM_PASSING_GRADE AS passing_grade
      FROM $TABLE_STUDENTS s
      LEFT JOIN $TABLE_EXAM_GRADES eg
        ON eg.$COL_GRADE_STUDENT_ID = s.$COL_STUDENT_ID
        AND eg.$COL_GRADE_EXAM_ID   = ?
      INNER JOIN $TABLE_EXAMS e ON e.$COL_EXAM_ID = ?
      WHERE s.$COL_STUDENT_GROUP_ID = ?
      ORDER BY s.$COL_STUDENT_NAME ASC
    ''', [examId, examId, groupId]);

    return rows
        .map((r) => ExamGrade.fromMap({
              'id': r['id'],
              'exam_id': examId,
              'student_id': r['student_id'],
              'grade': r['grade'],
              'notes': r['notes'],
              'is_absent': r['is_absent'] ?? 0,
              'created_at': r['created_at'],
              'student_name': r['student_name'],
              'max_grade': r['max_grade'],
              'passing_grade': r['passing_grade'],
            }))
        .toList();
  }

  /// حفظ أو تحديث درجة طالب (مع دعم الغياب)
  Future<void> upsertGrade({
    required int examId,
    required int studentId,
    required double? grade,
    String? notes,
    bool isAbsent = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert('''
      INSERT INTO $TABLE_EXAM_GRADES
        ($COL_GRADE_EXAM_ID, $COL_GRADE_STUDENT_ID, $COL_GRADE_VALUE,
         $COL_GRADE_NOTES, $COL_GRADE_IS_ABSENT, $COL_SYNC_UPDATED_AT)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT($COL_GRADE_EXAM_ID, $COL_GRADE_STUDENT_ID)
      DO UPDATE SET
        $COL_GRADE_VALUE     = excluded.$COL_GRADE_VALUE,
        $COL_GRADE_NOTES     = excluded.$COL_GRADE_NOTES,
        $COL_GRADE_IS_ABSENT = excluded.$COL_GRADE_IS_ABSENT,
        $COL_SYNC_UPDATED_AT = excluded.$COL_SYNC_UPDATED_AT
    ''', [examId, studentId, isAbsent ? null : grade, notes, isAbsent ? 1 : 0, now]);
    _notifyChanged();

    // last_insert_rowid() مش موثوق فيه هنا لو الصف كان موجود بالفعل
    // ودخل مسار DO UPDATE بدل INSERT — بنجيب الـid بالاستعلام المباشر
    // بمفتاح (examId, studentId) بدل ما نعتمد عليه.
    final row = await db.query(TABLE_EXAM_GRADES,
        columns: [COL_GRADE_ID],
        where: '$COL_GRADE_EXAM_ID = ? AND $COL_GRADE_STUDENT_ID = ?',
        whereArgs: [examId, studentId],
        limit: 1);
    if (row.isEmpty) return;
    final gradeId = row.first[COL_GRADE_ID] as int;
    await _queueSync(TABLE_EXAM_GRADES, gradeId, 'insert', payload: {
      COL_GRADE_EXAM_ID: examId,
      COL_GRADE_STUDENT_ID: studentId,
      COL_GRADE_VALUE: isAbsent ? null : grade,
      COL_GRADE_NOTES: notes,
      COL_GRADE_IS_ABSENT: isAbsent ? 1 : 0,
      COL_SYNC_UPDATED_AT: now,
    });
  }

  /// إحصائيات امتحان لمجموعة معينة (مع التوزيع)
  Future<ExamGroupStats> getExamGroupStats(
      int examId, int groupId, String groupName) async {
    final grades = await getGradesForExamGroup(examId, groupId);
    final absentList = grades.where((g) => g.isAbsent).toList();
    final entered = grades.where((g) => g.grade != null).toList();
    final maxGrade = grades.isNotEmpty ? (grades.first.maxGrade ?? 100) : 100;
    final passingGrade = grades.isNotEmpty
        ? (grades.first.passingGrade ?? maxGrade * 0.5)
        : maxGrade * 0.5;

    final passed = entered.where((g) => g.grade! >= passingGrade).length;
    final values = entered.map((g) => g.grade!).toList();

    // توزيع الدرجات — استخدام درجة النجاح الفعلية للامتحان بدل نسبة ثابتة 60%
    final passingPct = maxGrade > 0 ? (passingGrade / maxGrade) * 100 : 60;
    int excellent = 0, veryGood = 0, good = 0, pass = 0, fail = 0;
    for (final g in entered) {
      final pct = maxGrade > 0 ? (g.grade! / maxGrade) * 100 : 0;
      if (pct >= 90)
        excellent++;
      else if (pct >= 80)
        veryGood++;
      else if (pct >= 70)
        good++;
      else if (pct >= passingPct)
        pass++;
      else
        fail++;
    }

    return ExamGroupStats(
      examId: examId,
      groupId: groupId,
      groupName: groupName,
      total: grades.length,
      entered: entered.length,
      passed: passed,
      failed: entered.length - passed,
      absent: absentList.length,
      average:
          values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length,
      highest: values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b),
      lowest: values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b),
      distribution: GradeDistribution(
        excellent: excellent,
        veryGood: veryGood,
        good: good,
        pass: pass,
        fail: fail,
        absent: absentList.length,
      ),
    );
  }

  /// تقدم إدخال الدرجات لامتحان (لبطاقة الامتحان)
  Future<ExamProgress> getExamProgress(int examId) async {
    final db = await database;
    // عدد الطلاب الكلي في كل مجموعات الامتحان
    final totalRes = await db.rawQuery('''
      SELECT COUNT(DISTINCT s.$COL_STUDENT_ID) AS total
      FROM $TABLE_STUDENTS s
      INNER JOIN $TABLE_EXAM_GROUPS eg ON eg.$COL_EG_GROUP_ID = s.$COL_STUDENT_GROUP_ID
      WHERE eg.$COL_EG_EXAM_ID = ?
    ''', [examId]);
    final total = (totalRes.first['total'] as int?) ?? 0;

    // عدد الدرجات المدخلة (سواء رقم أو غياب)
    final enteredRes = await db.rawQuery('''
      SELECT
        COUNT(CASE WHEN $COL_GRADE_VALUE IS NOT NULL THEN 1 END) AS entered,
        COUNT(CASE WHEN $COL_GRADE_IS_ABSENT = 1 THEN 1 END)     AS absent
      FROM $TABLE_EXAM_GRADES
      WHERE $COL_GRADE_EXAM_ID = ?
    ''', [examId]);

    final entered = (enteredRes.first['entered'] as int?) ?? 0;
    final absent = (enteredRes.first['absent'] as int?) ?? 0;

    return ExamProgress(
      examId: examId,
      totalStudents: total,
      enteredGrades: entered,
      absentStudents: absent,
    );
  }

  /// نفس [getExamProgress] لكن لكل الامتحانات مرة واحدة (استعلامين
  /// مجمَّعين GROUP BY بدل استعلامين لكل امتحان على حدة) — صفحة قائمة
  /// الامتحانات كانت بتلف على كل امتحان وتستنى استعلامه لحاله، فمع مدرّس
  /// متراكم عنده امتحانات كتير كان بياخد وقت محسوس (شبه تعليق) كل ما
  /// الصفحة تفتح أو امتحان يتضاف/يتعدّل/يتحذف.
  Future<Map<int, ExamProgress>> getAllExamsProgress() async {
    final db = await database;

    final totalRows = await db.rawQuery('''
      SELECT eg.$COL_EG_EXAM_ID AS exam_id,
             COUNT(DISTINCT s.$COL_STUDENT_ID) AS total
      FROM $TABLE_EXAM_GROUPS eg
      INNER JOIN $TABLE_STUDENTS s ON s.$COL_STUDENT_GROUP_ID = eg.$COL_EG_GROUP_ID
      GROUP BY eg.$COL_EG_EXAM_ID
    ''');

    final gradeRows = await db.rawQuery('''
      SELECT $COL_GRADE_EXAM_ID AS exam_id,
             COUNT(CASE WHEN $COL_GRADE_VALUE IS NOT NULL THEN 1 END) AS entered,
             COUNT(CASE WHEN $COL_GRADE_IS_ABSENT = 1 THEN 1 END)     AS absent
      FROM $TABLE_EXAM_GRADES
      GROUP BY $COL_GRADE_EXAM_ID
    ''');

    final totalByExam = <int, int>{
      for (final r in totalRows) r['exam_id'] as int: (r['total'] as int?) ?? 0
    };
    final gradesByExam = <int, (int, int)>{
      for (final r in gradeRows)
        r['exam_id'] as int: (
          (r['entered'] as int?) ?? 0,
          (r['absent'] as int?) ?? 0
        )
    };

    final examIds = {...totalByExam.keys, ...gradesByExam.keys};
    return {
      for (final examId in examIds)
        examId: ExamProgress(
          examId: examId,
          totalStudents: totalByExam[examId] ?? 0,
          enteredGrades: gradesByExam[examId]?.$1 ?? 0,
          absentStudents: gradesByExam[examId]?.$2 ?? 0,
        )
    };
  }

  /// سجل أداء طالب في جميع الامتحانات
  Future<List<StudentExamRecord>> getStudentExamHistory(int studentId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        e.$COL_EXAM_ID            AS exam_id,
        e.$COL_EXAM_NAME          AS exam_name,
        e.$COL_EXAM_DATE          AS exam_date,
        e.$COL_EXAM_MAX_GRADE     AS max_grade,
        e.$COL_EXAM_PASSING_GRADE AS passing_grade,
        eg.$COL_GRADE_VALUE       AS grade,
        eg.$COL_GRADE_IS_ABSENT   AS is_absent,
        g.$COL_GROUP_NAME         AS group_name
      FROM $TABLE_EXAMS e
      INNER JOIN $TABLE_EXAM_GROUPS  exg ON exg.$COL_EG_EXAM_ID  = e.$COL_EXAM_ID
      INNER JOIN $TABLE_STUDENTS     s   ON s.$COL_STUDENT_ID     = ?
                                        AND s.$COL_STUDENT_GROUP_ID = exg.$COL_EG_GROUP_ID
      INNER JOIN $TABLE_GROUPS       g   ON g.$COL_GROUP_ID        = s.$COL_STUDENT_GROUP_ID
      LEFT JOIN  $TABLE_EXAM_GRADES  eg  ON eg.$COL_GRADE_EXAM_ID  = e.$COL_EXAM_ID
                                        AND eg.$COL_GRADE_STUDENT_ID = ?
      ORDER BY e.$COL_EXAM_DATE ASC
    ''', [studentId, studentId]);

    return rows
        .map((r) => StudentExamRecord(
              examId: r['exam_id'] as int,
              examName: r['exam_name'] as String,
              examDate: DateTime.parse(r['exam_date'] as String),
              maxGrade: (r['max_grade'] as num).toDouble(),
              passingGrade: (r['passing_grade'] as num).toDouble(),
              grade: r['grade'] != null ? (r['grade'] as num).toDouble() : null,
              isAbsent: (r['is_absent'] as int? ?? 0) == 1,
              groupName: r['group_name'] as String,
            ))
        .toList();
  }

  /// قائمة الأوائل لامتحان معين (كل المجموعات أو مجموعة محددة)
  Future<List<LeaderboardEntry>> getLeaderboard({
    int? examId,
    int? groupId,
  }) async {
    final db = await database;

    String where = 'eg.$COL_GRADE_VALUE IS NOT NULL';
    final args = <dynamic>[];

    if (examId != null) {
      where += ' AND eg.$COL_GRADE_EXAM_ID = ?';
      args.add(examId);
    }
    if (groupId != null) {
      where += ' AND s.$COL_STUDENT_GROUP_ID = ?';
      args.add(groupId);
    }

    final rows = await db.rawQuery('''
      SELECT
        s.$COL_STUDENT_ID   AS student_id,
        s.$COL_STUDENT_NAME AS student_name,
        s.$COL_STUDENT_GROUP_ID AS group_id,
        g.$COL_GROUP_NAME   AS group_name,
        SUM(eg.$COL_GRADE_VALUE)    AS total_grade,
        SUM(e.$COL_EXAM_MAX_GRADE)  AS total_max,
        COUNT(eg.$COL_GRADE_ID)     AS exam_count
      FROM $TABLE_EXAM_GRADES eg
      INNER JOIN $TABLE_STUDENTS s ON s.$COL_STUDENT_ID = eg.$COL_GRADE_STUDENT_ID
      INNER JOIN $TABLE_GROUPS   g ON g.$COL_GROUP_ID   = s.$COL_STUDENT_GROUP_ID
      INNER JOIN $TABLE_EXAMS    e ON e.$COL_EXAM_ID    = eg.$COL_GRADE_EXAM_ID
      WHERE $where
      GROUP BY s.$COL_STUDENT_ID
      ORDER BY (SUM(eg.$COL_GRADE_VALUE) * 1.0 / SUM(e.$COL_EXAM_MAX_GRADE)) DESC
    ''', args);

    final list = rows.asMap().entries.map((entry) {
      final r = entry.value;
      return LeaderboardEntry(
        studentId: r['student_id'] as int,
        studentName: r['student_name'] as String,
        groupId: r['group_id'] as int,
        groupName: r['group_name'] as String,
        totalGrade: (r['total_grade'] as num).toDouble(),
        totalMax: (r['total_max'] as num).toDouble(),
        examCount: r['exam_count'] as int,
        rank: entry.key + 1,
      );
    }).toList();
    return list;
  }
}

class _GroupCascadeIds {
  // ID → remote_id (لو الصف كان متزامن قبل الحذف) — لازم نلقط
  // remote_id قبل ما الصف يتمسح محليًا، وإلا مفيش طريقة نعرفه بيها
  // تاني وقت الـ push (راجع _pushOne في sync_engine.dart).
  final Map<int, String?> studentIds;
  final Map<int, String?> attendanceIds;
  final Map<int, String?> paymentIds;
  _GroupCascadeIds({
    required this.studentIds,
    required this.attendanceIds,
    required this.paymentIds,
  });
}
