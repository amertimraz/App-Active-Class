-- spec 031 — وقت خادم موحّد لـ updated_at على كل الجداول المتزامنة.
-- يمنع فقدان تعديلات بسبب انحراف ساعات أجهزة الفريق (LWW في SyncEngine
-- كان بيقارن updated_at اللي بيرسله كل client من ساعته المحلية).
-- idempotent — إعادة التطبيق آمنة.

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
