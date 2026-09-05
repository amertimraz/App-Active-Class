# Contract: مزامنة exam_submissions

## SQLite

- أعمدة جديدة على `exam_submissions`: `sync_updated_at TEXT`, `sync_remote_id TEXT` (نفس ترقية [sync-exam-questions.md](sync-exam-questions.md)).

## دوال الكتابة (`database_service.dart`) — تضيف queue

كل دالة بتكتب في `exam_submissions` لازم تحدّث `COL_SYNC_UPDATED_AT` وتنادي `_queueSync`/`_queueDelete`:

| الدالة | الإضافة |
|---|---|
| كتابة التسليمات في `pullAndGradeOnlineExam` (insert/upsert لكل تسليم مسحوب) | `_queueSync(TABLE_EXAM_SUBMISSIONS, id, 'insert'\|'update', payload: map)` |
| `updateSubmissionApproval(examId, studentId, grade, status)` | `_queueSync(..., 'update', payload: <صف التسليم المحدَّث>)` |
| `voidSubmissionLocally(examId, studentId)` (spec 022) | `_queueSync(..., 'update', payload: {... COL_ES_STATUS: 'voided'})` |
| أي مسار تاني بيغيّر `status`/`final_grade`/`auto_score` | نفس الشيء |
| حذف تسليمات الامتحان ضمن `deleteExam` | `_queueDelete` لكل صف (نمط cascade) |

## `sync_engine.dart`

### `_tables`
`TABLE_EXAM_SUBMISSIONS` في آخر القائمة (بعد `exams` و`students` و`exam_grades`).

### `_pkCol`
`TABLE_EXAM_SUBMISSIONS => COL_ES_ID`

### `_buildRemoteRow(TABLE_EXAM_SUBMISSIONS, localId, payload)`
```
final examLocalId = payload[COL_ES_EXAM_ID] as int?;
final studentLocalId = payload[COL_ES_STUDENT_ID] as int?;
String? examRemoteId, studentRemoteId;
if (examLocalId != null) {
  examRemoteId = await _localRemoteId(TABLE_EXAMS, COL_EXAM_ID, examLocalId);
  if (examRemoteId == null) return null;
}
if (studentLocalId != null) {
  studentRemoteId = await _localRemoteId(TABLE_STUDENTS, COL_STUDENT_ID, studentLocalId);
  if (studentRemoteId == null) return null;
}
return {
  ...base,
  'exam_remote_id': examRemoteId,
  'student_remote_id': studentRemoteId,
  'started_at': payload[COL_ES_STARTED_AT],
  'submitted_at': payload[COL_ES_SUBMITTED_AT],
  'answers_json': payload[COL_ES_ANSWERS_JSON],
  'auto_score': payload[COL_ES_AUTO_SCORE],
  'final_grade': payload[COL_ES_FINAL_GRADE],
  'status': payload[COL_ES_STATUS],
  'auto_submitted': (payload[COL_ES_AUTO_SUBMITTED] as int? ?? 0) == 1,
  // pulled_at — مستبعد عمدًا (محلي لكل جهاز)
};
```

### `_toLocalMap(TABLE_EXAM_SUBMISSIONS, remote)`
```
// حلّ exam + student (كلاهما return null لو الأب مفقود — نمط exam_grades)
return {
  COL_ES_EXAM_ID: localExamId,
  COL_ES_STUDENT_ID: localStudentId,
  COL_ES_STARTED_AT: remote['started_at'],
  COL_ES_SUBMITTED_AT: remote['submitted_at'],
  COL_ES_ANSWERS_JSON: remote['answers_json'],
  COL_ES_AUTO_SCORE: remote['auto_score'],
  COL_ES_FINAL_GRADE: remote['final_grade'],
  COL_ES_STATUS: remote['status'],
  COL_ES_AUTO_SUBMITTED: (remote['auto_submitted'] as bool? ?? false) ? 1 : 0,
  COL_SYNC_UPDATED_AT: updatedAt,
  COL_SYNC_REMOTE_ID: remote['id'],
  // COL_ES_PULLED_AT مستبعد — يفضل NULL على الجهاز المستقبِل
};
```

### dedup وارد (`_applyRemoteRow`، قبل `_insertWithCodeRetry`)
```
if (table == TABLE_EXAM_SUBMISSIONS) {
  final examId = localMap[COL_ES_EXAM_ID];
  final studentId = localMap[COL_ES_STUDENT_ID];
  if (examId != null && studentId != null) {
    final dup = await db.query(table,
        where: '$COL_ES_EXAM_ID = ? AND $COL_ES_STUDENT_ID = ?',
        whereArgs: [examId, studentId], limit: 1);
    if (dup.isNotEmpty) {
      debugPrint('SyncEngine: تجاهل تسليم مكرر (امتحان $examId، طالب $studentId) وارد من جهاز تاني');
      return;
    }
  }
}
```

### `_refreshUiForTable`
`case TABLE_EXAM_SUBMISSIONS:` → `ExamController.loadExams()`.

## تعارض التصحيح (آخر تعديل يفوز)

`_applyRemoteRow` المسار الموجود: لو `existing by remote_id` و`!remoteUpdatedAt.isAfter(localUpdatedAt)` → تجاهل. يعني:
- المدرس اعتمد الساعة 3:00، المساعد اعتمد 3:01 → نسخة المساعد (`updated_at` أحدث) تفوز على الجهازين.
- `voided` (spec 022) بـ`updated_at` أحدث من اعتماد أقدم → `voided` يفوز (FR-009). لو الاعتماد أحدث من الإبطال، الاعتماد يفوز — وده صح (المدرس قرر يرجّعه).

## معايير القبول

- FR-006..FR-011، SC-002، SC-003، SC-004.
- المساعد يعتمد → المدرس يشوف "معتمَد" بنفس الدرجة، الباقي "بانتظار".
- إبطال على جهاز → مُبطَل على الكل، صفر إعادة فتح.
- جهاز واحد يسحب من Firestore → الجهاز التاني ياخد التسليمات عبر الفريq.
- الدرجة المعتمَدة تدخل `exam_grades` (متزامن أصلاً) عند الكل.
