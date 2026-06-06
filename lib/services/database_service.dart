// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/payment_model.dart';

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
        $COL_GROUP_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP
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
        UNIQUE($COL_ATTENDANCE_STUDENT_ID, $COL_ATTENDANCE_DATE),
        FOREIGN KEY($COL_ATTENDANCE_STUDENT_ID) REFERENCES $TABLE_STUDENTS($COL_STUDENT_ID) ON DELETE CASCADE
      )
    ''');

    // Payments
    await db.execute('''
      CREATE TABLE $TABLE_PAYMENTS (
        $COL_PAYMENT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $COL_PAYMENT_STUDENT_ID INTEGER NOT NULL,
        $COL_PAYMENT_DATE TEXT NOT NULL,
        $COL_PAYMENT_AMOUNT REAL NOT NULL CHECK($COL_PAYMENT_AMOUNT > 0),
        $COL_PAYMENT_NOTE TEXT,
        $COL_PAYMENT_CREATED_AT TEXT DEFAULT CURRENT_TIMESTAMP,
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

    // Create indexes for performance optimization
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_CODE TEXT');
      await db.execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_PRICE REAL');
      await db.execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_COLOR INTEGER');
      await db.execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_ICON TEXT');
      await db.execute('ALTER TABLE $TABLE_GROUPS ADD COLUMN $COL_GROUP_SCHEDULE TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_${TABLE_GROUPS}_$COL_GROUP_CODE '
        'ON $TABLE_GROUPS($COL_GROUP_CODE) '
        'WHERE $COL_GROUP_CODE IS NOT NULL',
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_SIBLING_ID INTEGER');
      await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_SIBLINGS_TOTAL REAL');
      await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_ATTENDANCE_START TEXT');
      await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_GUARDIAN_PHONE TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE $TABLE_STUDENTS ADD COLUMN $COL_STUDENT_BIRTH_DATE TEXT');
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
  }

  // ========== GROUPS ==========
  Future<int> insertGroup(Group group) async {
    final db = await database;
    return await db.insert(TABLE_GROUPS, group.toMap());
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
    return await db.update(
      TABLE_GROUPS,
      group.toMap(),
      where: '$COL_GROUP_ID = ?',
      whereArgs: [group.id],
    );
  }

  Future<int> deleteGroup(int id) async {
    final db = await database;
    return await db.delete(
      TABLE_GROUPS,
      where: '$COL_GROUP_ID = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteStudentsByGroup(int groupId) async {
    final db = await database;
    await db.transaction((txn) async {
      final students = await txn.query(
        TABLE_STUDENTS,
        columns: [COL_STUDENT_ID],
        where: '$COL_STUDENT_GROUP_ID = ?',
        whereArgs: [groupId],
      );
      final ids = students.map((e) => e[COL_STUDENT_ID] as int).toList();
      if (ids.isEmpty) return;
      final placeholders = List.filled(ids.length, '?').join(',');
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
  }

  // ========== STUDENTS ==========
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert(TABLE_STUDENTS, student.toMap());
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
    return await db.update(
      TABLE_STUDENTS,
      student.toMap(),
      where: '$COL_STUDENT_ID = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete(
      TABLE_STUDENTS,
      where: '$COL_STUDENT_ID = ?',
      whereArgs: [id],
    );
  }

  Future<int> getGroupStudentCount(int groupId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $TABLE_STUDENTS WHERE $COL_STUDENT_GROUP_ID = ?',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== ATTENDANCE ==========
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert(TABLE_ATTENDANCE, attendance.toMap());
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
    return await db.update(
      TABLE_ATTENDANCE,
      attendance.toMap(),
      where: '$COL_ATTENDANCE_ID = ?',
      whereArgs: [attendance.id],
    );
  }

  Future<int> deleteAttendance(int id) async {
    final db = await database;
    return await db.delete(
      TABLE_ATTENDANCE,
      where: '$COL_ATTENDANCE_ID = ?',
      whereArgs: [id],
    );
  }

  // ========== PAYMENTS ==========
  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert(TABLE_PAYMENTS, payment.toMap());
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

  Future<Set<int>> getPaidStudentIdsForMonth(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();
    
    final result = await db.query(
      TABLE_PAYMENTS,
      columns: [COL_PAYMENT_STUDENT_ID],
      where: '$COL_PAYMENT_DATE >= ? AND $COL_PAYMENT_DATE <= ?',
      whereArgs: [start, end],
    );
    
    return result.map((row) => row[COL_PAYMENT_STUDENT_ID] as int).toSet();
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
    return await db.update(
      TABLE_PAYMENTS,
      payment.toMap(),
      where: '$COL_PAYMENT_ID = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete(
      TABLE_PAYMENTS,
      where: '$COL_PAYMENT_ID = ?',
      whereArgs: [id],
    );
  }

  /// Delete all app data from the database in a safe order
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete children first to avoid FK issues (even if FKs are disabled)
      await txn.delete(TABLE_ATTENDANCE);
      await txn.delete(TABLE_PAYMENTS);
      await txn.delete(TABLE_STUDENTS);
      await txn.delete(TABLE_GROUPS);
    });
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

  Future<Map<int, DateTime>> getReportSentMap(List<int> studentIds, DateTime monthStart) async {
    if (studentIds.isEmpty) return {};
    final db = await database;
    final m = DateTime(monthStart.year, monthStart.month, 1).toIso8601String();
    final placeholders = List.filled(studentIds.length, '?').join(',');
    final res = await db.query(
      TABLE_REPORT_LOGS,
      where: '$COL_REPORT_MONTH_START = ? AND $COL_REPORT_STUDENT_ID IN ($placeholders)',
      whereArgs: [m, ...studentIds],
    );
    final map = <int, DateTime>{};
    for (final row in res) {
      map[row[COL_REPORT_STUDENT_ID] as int] = DateTime.parse(row[COL_REPORT_SENT_AT] as String);
    }
    return map;
  }

  Future<void> upsertReportLog(int studentId, DateTime monthStart, DateTime sentAt) async {
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
}
