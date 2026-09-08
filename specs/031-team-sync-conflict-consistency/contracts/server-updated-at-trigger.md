# Contract: migration `supabase/migration_server_updated_at.sql`

## الملف

```sql
-- spec 031 — وقت خادم موحّد لـ updated_at على كل الجداول المتزامنة.
-- يمنع فقدان تعديلات بسبب انحراف ساعات أجهزة الفريق (LWW في SyncEngine).

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'groups','students','attendance','payments','homework',
    'exams','exam_groups','exam_grades','exam_questions',
    'exam_submissions','bank_questions'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_set_updated_at ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t);
  END LOOP;
END $$;
```

## التطبيق

```bash
ssh -i ~/.ssh/ovh_key root@active-class.online \
  "docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1" \
  < supabase/migration_server_updated_at.sql
```

## التحقّق

```sql
SELECT event_object_table, trigger_name
FROM information_schema.triggers
WHERE trigger_schema='public' AND trigger_name='trg_set_updated_at'
ORDER BY event_object_table;   -- لازم 11 صف

-- سلوكي: عدّل صفًا بقيمة updated_at قديمة صراحةً، تأكد أن القيمة المخزّنة = now()
UPDATE public.attendance SET updated_at = '2000-01-01' WHERE id = '<any>';
SELECT updated_at FROM public.attendance WHERE id = '<any>';  -- ≈ now()
```

## ثوابت لا تُكسر

- الـtrigger يضبط `updated_at` **فقط** — لا يمسّ أي عمود آخر.
- لا يتعارض مع `check_delete_*` (trigger منفصل، نفس التوقيت `BEFORE UPDATE` لكن أغراض مختلفة — بلا تصادم).
- `deleted_at` يظل من الـclient (soft-delete).
- idempotent: `DROP TRIGGER IF EXISTS` قبل `CREATE` — إعادة التطبيق آمنة.
- الجداول غير المتزامنة (`team_members`, `teams`, `sync_outbox` المحلي...) غير مشمولة.
