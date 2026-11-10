# Research: إرسال واتساب تلقائي

## R1 — أين ينفَّذ الإرسال؟
- **Decision**: worker صغير على الـ VPS يسحب من جدول `wa_outbox`.
- **Rationale**: الستاك الحالي (db, auth, rest, realtime, kong) مفيهوش functions؛ المفاتيح لازم تبقى بعيد عن التطبيق؛ الـ webhook محتاج endpoint عام.
- **Alternatives**: الإرسال من التطبيق (يكشف المفتاح ومش شغال والموبايل مقفول) ✗؛ Supabase Edge Runtime (إضافة ثقيلة للستاك) ✗؛ Cloud Functions على Firebase (فاتورة وتشتت بنية) ✗.

## R2 — من أين تأتي الأحداث؟
- **Decision**: التطبيق (جهاز المالك فقط، زي الغياب التلقائي spec 046) يكتب صف في `wa_outbox` بمفتاح منع تكرار `dedupe_key` فريد (teacher + student + type + مرجع الحدث).
- **Rationale**: المنطق (غياب/دفع/تأخر، حصص ملغاة spec 032) موجود محليًا؛ إعادته على السيرفر ازدواج. المالك فقط يمنع تكرار الفريق، والمفتاح الفريد يحمي لو جهازين.
- **Alternatives**: triggers على الجداول المتزامنة (تحتاج إعادة منطق الحصص والأقساط) ✗.

## R3 — المزوّد: Meta WhatsApp Cloud API مباشرة
- **Decision**: Cloud API الرسمي بدون وسيط، معزول خلف `Provider.send(template, to, vars)` في الـ worker (`src/meta.js`).
- **Rationale**: قرار صاحب النظام (2026-11-09): تجنب رسوم/زيادات الوسيط (Kapso كان $25/شهر لـ Pro)؛ رقم واحد للتطبيق فمش محتاجين Embedded Signup؛ الـ worker بتاعنا أصلًا. تغيير المزوّد لاحقًا يكلف ملف واحد.
- **Alternatives**: Kapso (اشتراك + قيمة Embedded Signup غير مستخدمة الآن) ✗؛ Twilio (زيادة على الرسالة) ✗.
- **Open (يتحسم في spike)**: تسجيل الرقم المصري على Cloud API، توقيع الـ webhook (`X-Hub-Signature-256`)، تجديد الـ token (System User دائم)، سعر الرسالة الفعلي، هل الرسالة الخدمية داخل نافذة 24 ساعة مجانية.
- **رقم تجريبي**: Meta تعطي رقمًا تجريبيًا مجانيًا في لوحة المطورين للـ spike الأول.
- **ملاحظة**: أرقام الأسعار في المصادر متعارضة، فالحصة الافتراضية (100) افتراض يتعدّل بعد spike.

## R4 — الموافقة والإيقاف
- **Decision**: جدول `wa_consents` (طالب+رقم) بحالة `granted/stopped`؛ ردّ "إيقاف/STOP" عبر webhook يحوّل كل صفوف الرقم لـ `stopped` عند كل المدرسين.
- **Rationale**: متطلب واتساب وحماية الرقم من الحظر.

## R5 — القوالب
- **Decision**: 3 قوالب utility بالعربي (غياب، تأخر دفع، إيصال) بمتغيرات ثابتة؛ التخصيص بالقيم فقط.
- **Rationale**: واتساب يعتمد القالب مسبقًا. نص `SystemMessages` المخصص يستخدم لليدوي فقط.
- **Risk**: رفض Meta لقالب → نبدأ بصياغة مباشرة بدون ترويج.

## R6 — الحصة والرصيد
- **Decision**: `wa_quota(teacher_id, month, free_limit, used, extra_balance)`؛ الخصم ذري داخل الـ worker (`update ... where used < free_limit or extra_balance > 0 returning`) قبل الإرسال، ويُرد عند الفشل غير المحاسَب.
- **Rationale**: يمنع تجاوز الحصة تحت التزامن.

## R7 — معدل الإرسال والتأجيل
- **Decision**: token bucket في الـ worker (30/دقيقة افتراضي)، وساعات 8–22 بتوقيت `Africa/Cairo` (أو توقيت المدرس لو مخزن).
- **Rationale**: الغياب التلقائي بيولّد دفعات كبيرة.

## R8 — الهوية والأمان
- **Decision**: RLS: المدرس (واعضاء فريقه) يقرأوا ويكتبوا `wa_outbox` الخاصة بـ team/owner بس؛ الـ worker يتصل بـ service role مباشرة على Postgres؛ الـ webhook يتحقق من توقيع الوسيط.
- **Rationale**: نفس نموذج الفرق الحالي (`team_id`).
