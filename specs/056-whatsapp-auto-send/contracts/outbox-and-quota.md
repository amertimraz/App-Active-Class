# عقد: التطبيق ↔ Supabase

## كتابة (من جهاز المالك فقط)
`insert into wa_outbox (team_id, student_local_id, student_name, to_phone, kind, vars, dedupe_key, not_before)` مع `on conflict (dedupe_key) do nothing`.
- التطبيق يتحقق محليًا قبل الإدراج: الميزة والنوع مفعّلين، الطالب نشط، الرقم صالح، الحصة ليست ملغاة (spec 032).
- لا يتحقق من الموافقة/الحصة نهائيًا — ده شغل السيرفر (المرجع الوحيد).

## قراءة
- السجل: `select ... from wa_outbox where team_id = :t order by created_at desc` + فلاتر (student, kind, status, من/إلى) + ترقيم صفحات.
- الحصة: `select free_limit, used, extra_balance from wa_quota where team_id=:t and month=:m`.
- الموافقات: `select ... from wa_consents where team_id=:t`.
- Realtime اختياري لحالة الرسالة؛ الأساس polling عند فتح السجل.

## موافقة
upsert على `wa_consents` (granted) من التطبيق، فردي أو بالجملة لمجموعة (batch).

## رسالة اختبار
`kind = 'test'` لرقم المدرس نفسه؛ بتتحسب من الحصة؛ dedupe_key فيه timestamp.

## RLS
- كل الجداول: `team_id` ضمن فرق المستخدم.
- `wa_quota`/`wa_settings(global)`: قراءة للمدرس، كتابة للأدمن/الـ service فقط.
- المدرس لا يكتب `status` خارج الإلغاء اليدوي (`pending → blocked: cancelled`).
