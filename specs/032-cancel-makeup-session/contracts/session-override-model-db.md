# Contract: نموذج SessionOverride + طبقة قاعدة البيانات

## `lib/models/session_override_model.dart`

```dart
enum SessionOverrideType { cancelled, makeup, extra }

class SessionOverride {
  final int? id;
  final int groupId;
  final DateTime date;               // منزوع الوقت
  final SessionOverrideType type;
  final DateTime? compensatesDate;
  final String? note;
  final DateTime? createdAt;

  const SessionOverride({ this.id, required this.groupId, required this.date,
    required this.type, this.compensatesDate, this.note, this.createdAt });

  static String _ymd(DateTime d) => // 'YYYY-MM-DD'
  Map<String, dynamic> toMap();      // {id?, group_id, date, type: type.name,
                                     //  compensates_date, note, created_at, }
  factory SessionOverride.fromMap(Map<String, dynamic> m);
  SessionOverride copyWith({...});
}
```

- `toMap`/`fromMap` **لا** يشملان أعمدة المزامنة (`sync_updated_at`/`sync_remote_id`) — يتولّاها `DatabaseService` مثل باقي النماذج.
- `type` غير معروف في `fromMap` → `cancelled` (دفاعي) + `debugPrint`.

## `lib/config/constants.dart`

```dart
const String TABLE_SESSION_OVERRIDES = 'session_overrides';
const int DATABASE_VERSION = 29; // كان 28
```

(أعمدة المزامنة تعيد استخدام `COL_SYNC_REMOTE_ID` / `COL_SYNC_UPDATED_AT` القائمة.)

## `lib/services/database_service.dart`

### SQL

```sql
CREATE TABLE IF NOT EXISTS session_overrides (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  type TEXT NOT NULL,
  compensates_date TEXT,
  note TEXT,
  created_at TEXT,
  sync_updated_at TEXT,
  sync_remote_id TEXT,
  FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_session_overrides_group_date
  ON session_overrides (group_id, date);
```

- في `_createTables` (تثبيت جديد) + في `_onUpgrade`: `if (oldVersion < 29) { try { await db.execute(...table...); await db.execute(...index...); } catch (_) {} }`.

### الدوال

| التوقيع | السلوك |
|---|---|
| `Future<List<SessionOverride>> getAllSessionOverrides()` | `db.query` كل الصفوف، `fromMap` |
| `Future<SessionOverride?> getSessionOverride(int groupId, DateTime day)` | `where: 'group_id=? AND date=?'` |
| `Future<int> insertSessionOverride(SessionOverride o)` | `insert` (`created_at = now` لو null) ثم `_queueSync(TABLE_SESSION_OVERRIDES, id)` |
| `Future<int> deleteSessionOverride(int id)` | اجلب `remote_id` قبل الحذف → `db.delete` → `_queueDelete(TABLE_SESSION_OVERRIDES, id, remoteId)` |
| `Future<int> countAttendanceForGroupOnDay(int groupId, DateTime day)` | `SELECT COUNT(*)` من `attendance` `where group_id=? AND date LIKE 'YYYY-MM-DD%'` |
| `Future<List<Attendance>> attendanceForGroupOnDay(int groupId, DateTime day)` | نفس الشرط — لتجميع `remote_id`ات قبل الحذف |
| `Future<int> deleteAttendanceForGroupOnDay(int groupId, DateTime day)` | داخل `transaction`: احذف الصفوف؛ بعد الـcommit `_queueDelete` لكل `(id, remoteId)` |

- `date LIKE` يعامل قيم `attendance.date` التي قد تكون ISO كاملة أو تاريخ فقط.
