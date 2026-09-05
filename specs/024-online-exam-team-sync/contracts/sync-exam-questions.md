# Contract: مزامنة exam_questions + حقول الأونلاين

## SQLite

| البند | القيمة |
|---|---|
| ترقية | `DATABASE_VERSION` الحالي + 1 |
| أعمدة جديدة على `exam_questions` | `sync_updated_at TEXT`, `sync_remote_id TEXT` |
| أعمدة جديدة (منطقيًا) على payload `exams` | `is_online`, `online_status`, `opens_at`, `closes_at`, `duration_minutes` (الأعمدة المحلية موجودة — بس تدخل المزامنة) |

## دوال الكتابة (`database_service.dart`) — تضيف queue

| الدالة | الإضافة |
|---|---|
| `insertQuestion(q)` | `_queueSync(TABLE_EXAM_QUESTIONS, id, 'insert', payload: {...map, COL_EQ_ID: id})` + كتابة `COL_SYNC_UPDATED_AT` |
| `updateQuestion(q)` | `_queueSync(TABLE_EXAM_QUESTIONS, q.id!, 'update', payload: map)` + تحديث `COL_SYNC_UPDATED_AT` |
| `deleteQuestion(id)` | جلب `sync_remote_id` قبل الحذف ثم `_queueDelete(TABLE_EXAM_QUESTIONS, id, remoteId)` |
| حذف أسئلة الامتحان ضمن `deleteExam` | `_queueDelete` لكل صف سؤال (نمط `exam_grades` cascade في `deleteExam`) |
| `setExamOnlineFields(...)` / `setExamOnlineStatus(...)` | بعد `db.update(TABLE_EXAMS, ...)` → `_queueSync(TABLE_EXAMS, examId, 'update', payload: <صف exams كامل محدَّث>)` + `COL_SYNC_UPDATED_AT` |

**ملاحظة**: كل الدوال دي دلوقتي تحت تعليق "كله محلي — لا _queueSync" (سطر ~2101). التعليق يتحدّث. `_queueSync` فيها `if (!teamModeEnabled) return;` فآمنة للنداء دايمًا.

## `sync_engine.dart`

### `_tables`
`TABLE_EXAM_QUESTIONS` بعد `TABLE_EXAMS` مباشرة، قبل `TABLE_EXAM_GROUPS`.

### `_pkCol`
`TABLE_EXAM_QUESTIONS => COL_EQ_ID`

### `_buildRemoteRow(TABLE_EXAM_QUESTIONS, localId, payload)`
```
final examLocalId = payload[COL_EQ_EXAM_ID] as int?;
String? examRemoteId;
if (examLocalId != null) {
  examRemoteId = await _localRemoteId(TABLE_EXAMS, COL_EXAM_ID, examLocalId);
  if (examRemoteId == null) return null;   // الامتحان الأب لسه ما اتزامنش
}
return {
  ...base,
  'exam_remote_id': examRemoteId,
  'position': payload[COL_EQ_POSITION],
  'type': payload[COL_EQ_TYPE],
  'text': payload[COL_EQ_TEXT],
  'options': payload[COL_EQ_OPTIONS],
  'correct_index': payload[COL_EQ_CORRECT_INDEX],
  'points': payload[COL_EQ_POINTS],
  'image_url': payload[COL_EQ_IMAGE_URL],
  'explanation': payload[COL_EQ_EXPLANATION],   // مفتاح قد لا يوجد لو spec 023 لسه → null
};
```

### `_toLocalMap(TABLE_EXAM_QUESTIONS, remote)`
```
final examRemoteId = remote['exam_remote_id'] as String?;
final localExamId = examRemoteId != null
    ? await _localIdForRemote(TABLE_EXAMS, COL_EXAM_ID, examRemoteId, executor: executor)
    : null;
if (examRemoteId != null && localExamId == null) return null;
return {
  COL_EQ_EXAM_ID: localExamId,
  COL_EQ_POSITION: remote['position'],
  COL_EQ_TYPE: remote['type'],
  COL_EQ_TEXT: remote['text'],
  COL_EQ_OPTIONS: remote['options'],
  COL_EQ_CORRECT_INDEX: remote['correct_index'],
  COL_EQ_POINTS: remote['points'],
  COL_EQ_IMAGE_URL: remote['image_url'],
  COL_EQ_EXPLANATION: remote['explanation'],   // لو عمود explanation المحلي مش موجود (spec 023 لسه) → sqflite هيرمي؛ راجع ملاحظة
  COL_SYNC_UPDATED_AT: updatedAt,
  COL_SYNC_REMOTE_ID: remote['id'],
};
```
**ملاحظة تنسيق spec 023**: لو `explanation` مش عمود محلي بعد، شيل مفتاح `COL_EQ_EXPLANATION` من الخريطتين (الـmapping) — يتضاف لما 023 ينزل. التاسكات تتحقق من وجود العمود.

### `_buildRemoteRow(TABLE_EXAMS)` / `_toLocalMap(TABLE_EXAMS)` — إضافة حقول الأونلاين
`_buildRemoteRow`: `'is_online': (payload[COL_EXAM_IS_ONLINE] as int? ?? 0) == 1, 'online_status': payload[COL_EXAM_ONLINE_STATUS], 'opens_at': payload[COL_EXAM_OPENS_AT], 'closes_at': payload[COL_EXAM_CLOSES_AT], 'duration_minutes': payload[COL_EXAM_DURATION_MIN]`

`_toLocalMap`: `COL_EXAM_IS_ONLINE: (remote['is_online'] as bool? ?? false) ? 1 : 0, COL_EXAM_ONLINE_STATUS: remote['online_status'], COL_EXAM_OPENS_AT: remote['opens_at'], COL_EXAM_CLOSES_AT: remote['closes_at'], COL_EXAM_DURATION_MIN: remote['duration_minutes']`

### `_refreshUiForTable`
`case TABLE_EXAM_QUESTIONS:` → `if (Get.isRegistered<ExamController>()) Get.find<ExamController>().loadExams();`

## معايير القبول

- FR-001..FR-005، SC-001، SC-007.
- امتحان بـ٣ أسئلة على جهاز المدرس → يظهر بأسئلته على المساعد خلال دورة واحدة.
- تعديل/حذف سؤال → ينعكس بلا تكرار.
- المساعد يفتح "معاينة" (spec 023) → يشوف نفس الأسئلة.
- `toCloudMap` اختبار → لا `correct_index`/`points`/`explanation`.
