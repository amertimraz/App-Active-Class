-- عمود report_month كان موجود محليًا (sqflite) من قديم لكن الـmigration
-- المقابلة على السيرفر عمرها ما اتطبّقت — كل push لأي امتحان كان بيفشل
-- بشكل دائم بـ PGRST204 "Could not find the 'report_month' column"،
-- وكل درجات/أسئلة/تسليمات الامتحان كانت بتفضل عالقة وراه للأبد.
alter table public.exams add column if not exists report_month text;

-- إعادة تحميل schema cache بتاع PostgREST فورًا بدل ما ننتظر إعادة تشغيل
-- الحاوية أو دورة التحديث التلقائية.
notify pgrst, 'reload schema';
