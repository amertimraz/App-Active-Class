# Contract: مزامنة bank_questions عبر الفريق

نمط `exam_questions` (spec 024) بالحرف. `bank_questions` **ملوش أب** → أبسط (لا `*_remote_id`، لا `return null`).

## sync_engine.dart

### `_tables`
`TABLE_BANK_QUESTIONS` بعد `TABLE_EXAMS`.

### `_coreTables` / `_extendedTables`
`_extendedTables = [TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS, TABLE_BANK_QUESTIONS]`.

### `_pkCol`
`TABLE_BANK_QUESTIONS => COL_BQ_ID`

### `_buildRemoteRow(TABLE_BANK_QUESTIONS, localId, payload)`
```
return {
  ...base,
  'type': payload[COL_BQ_TYPE],
  'text': payload[COL_BQ_TEXT],
  'options': payload[COL_BQ_OPTIONS],
  'correct_index': payload[COL_BQ_CORRECT_INDEX],
  'points': payload[COL_BQ_POINTS],
  'image_url': payload[COL_BQ_IMAGE_URL],
  'explanation': payload[COL_BQ_EXPLANATION],
  'subject': payload[COL_BQ_SUBJECT],
  'tags': payload[COL_BQ_TAGS],
};
```

### `_toLocalMap(TABLE_BANK_QUESTIONS, remote)`
```
return {
  COL_BQ_TYPE: remote['type'],
  COL_BQ_TEXT: remote['text'],
  COL_BQ_OPTIONS: remote['options'],
  COL_BQ_CORRECT_INDEX: remote['correct_index'],
  COL_BQ_POINTS: remote['points'],
  COL_BQ_IMAGE_URL: remote['image_url'],
  COL_BQ_EXPLANATION: remote['explanation'],
  COL_BQ_SUBJECT: remote['subject'] ?? '',
  COL_BQ_TAGS: remote['tags'],
  COL_SYNC_UPDATED_AT: updatedAt,
  COL_SYNC_REMOTE_ID: remote['id'],
};
```

### `_refreshUiForTable`
`case TABLE_BANK_QUESTIONS:` → `if (Get.isRegistered<QuestionBankController>()) Get.find<QuestionBankController>().refresh();`

### dedup
**لا شيء** — `bank_questions` ملوش UNIQUE محلي. `_applyRemoteRow` العام (existing by remote_id → update، وإلا insert) يكفي.

## Supabase — `supabase/migration_question_bank.sql` (جديد)

نمط `migration_online_exam_sync.sql`:
- `create table if not exists public.bank_questions (...)` — [data-model.md](../data-model.md) §3
- `enable row level security` + 3 policies (`is_team_member` + `is_team_license_active`)
- `drop trigger if exists trg_check_delete_bank_questions` + `create trigger ... execute function public.check_delete_exams()`
- `do $$ ... alter publication supabase_realtime add table public.bank_questions ... if not exists`
- ترويسة تعليق: idempotent، يُطبَّق عبر SSH:
  ```
  ssh -i ~/.ssh/ovh_key root@active-class.online \
    'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
    < supabase/migration_question_bank.sql
  ```

## معايير القبول

- FR-008، SC-005.
- المدرس يضيف/يعدّل/يحذف سؤال بنك → يظهر على جهاز المساعد خلال دورة، بلا تكرار.
- جهاز مساعد جديد → كل أسئلة البنك ضمن التحميل الأول.
- migration مش مطبّق → القناة الأساسية (واجب/درجات) تفضل شغّالة (القناة الممتدة معزولة).
- تشغيل migration مرتين → صفر أخطاء.
