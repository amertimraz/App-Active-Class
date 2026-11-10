# Data Model: إرسال واتساب تلقائي

(كلها على Supabase؛ مفيش جداول محلية جديدة.)

> **تعديل أثناء التنفيذ**: المفتاح بقى `owner_id` (= `auth.uid()` للمدرس) بدل `team_id` في كل الجداول، لأن مش كل مدرس عنده فريق. الدفعات بتتبعت من جهاز المالك فقط. التنفيذ الفعلي: `supabase/migration_whatsapp_auto.sql`. جدول الإعدادات العامة بقى `wa_config(key,value)`، وإعدادات المدرس `wa_teacher_settings`. صيغة الأرقام المخزّنة: digits فقط بدون `+` (زي `2010…`).

## wa_outbox — طلبات/سجل الرسايل
| العمود | النوع | ملاحظة |
|---|---|---|
| id | uuid pk | |
| team_id | uuid | المالك/الفريق |
| student_local_id | int | مرجع الطالب عند المالك |
| student_name | text | لقطة للسجل |
| to_phone | text | E.164 بعد PhoneHelper |
| kind | text | `absence` / `late_payment` / `receipt` / `test` |
| vars | jsonb | متغيرات القالب (اسم، تاريخ، مبلغ، باقي، مجموعة، معلم) |
| dedupe_key | text unique | `team|student|kind|ref` (حصة/دفعة/أسبوع) |
| status | text | `pending` → `sending` → `sent` → `delivered` → `read` أو `failed` / `blocked` |
| fail_reason | text | كود + نص عربي (no_consent, stopped, no_quota, invalid_number, not_on_whatsapp, provider_error…) |
| attempts | int | حد أقصى 3 |
| not_before | timestamptz | تأجيل (ساعات/معدل/إعادة محاولة) |
| provider_msg_id | text | لربط الـ webhook |
| charged | boolean | احتُسبت من الحصة/الرصيد |
| created_at / sent_at / delivered_at / read_at | timestamptz | |

حالات: `pending → sending → sent → delivered → read`؛ فشل: `pending/sending → pending` (إعادة حتى 3) ثم `failed`؛ `blocked` لو لا موافقة/موقوف/نفاد حصة (بدون إعادة).

## wa_consents — موافقة ولي الأمر
team_id، student_local_id، phone، status (`granted`/`stopped`)، granted_at، granted_by، stopped_at. unique(team_id, student_local_id, phone).
الإيقاف بالرد يحدّث كل الصفوف بنفس `phone` عبر الفرق.

## wa_quota — الحصة والرصيد
team_id، month (date أول الشهر)، free_limit، used، extra_balance (يضيفه الأدمن). unique(team_id, month). الصف الجديد يتولد عند أول رسالة في الشهر بـ free_limit من `wa_settings`.

## wa_settings — إعدادات عامة وللمدرس
- عام (صف `global`): default_free_limit، rate_per_min، send_from_hour، send_to_hour، kill_switch.
- للمدرس: team_id، enabled، kinds (jsonb: absence/late_payment/receipt)، paused_by_admin.

## قواعد
- منع التكرار: `dedupe_key` فريد؛ الإدراج المكرر يتجاهل (`on conflict do nothing`).
- الغياب: ref = `date|group_id`؛ الإيصال: ref = `payment_id`؛ التأخر: ref = `ISO week`.
- الاحتفاظ: السجل 90 يوم ثم يُحذف تلقائيًا.
- حذف الطالب/الأرشفة: لا يغيّر السجل، لكن الطلبات `pending` للطالب تُلغى (`blocked: archived`).
