# عقد: الـ worker ↔ Meta WhatsApp Cloud API (مباشرة، بدون وسيط)

> التفاصيل الدقيقة للـ API تتأكد في spike المرحلة 1؛ العقد هنا على مستوى السلوك.

## حلقة الإرسال (كل ثانيتين)
1. اختار صفوف `pending` و`not_before <= now()` بـ `for update skip locked`، بحد معدل token bucket.
2. لكل صف: kill_switch؟ مدرس موقوف؟ خارج ساعات الإرسال → `not_before` للصباح.
3. موافقة `granted` للرقم؟ وإلا `blocked(no_consent|stopped)`.
4. خصم ذري من الحصة المجانية ثم الرصيد؛ لو صفر → `blocked(no_quota)`.
5. استدعاء `Provider.send(template(kind), to, vars)` → `sent` + `provider_msg_id`.
6. فشل مؤقت (شبكة/5xx/معدل): `attempts+1` وتأجيل 30ث/2د/10د ثم `failed(provider_error)`.
7. فشل دائم (رقم غير موجود/غير صالح): `failed(not_on_whatsapp|invalid_number)` + رد الخصم لو الوسيط لم يحاسب.

## Webhook (HTTPS عام عبر Caddy)
- `POST /wa/webhook` — يتحقق من توقيع الوسيط (HMAC) ويرفض غير الموقّع بـ 401.
- أحداث الحالة: `sent/delivered/read/failed` → يحدّث `wa_outbox` بالـ `provider_msg_id` (idempotent، لا يرجّع حالة للخلف).
- رسالة واردة: لو نصها (بعد تنظيف) ∈ {إيقاف، ايقاف، stop} → `wa_consents.status='stopped'` لكل صفوف الرقم، ويُرد برسالة تأكيد واحدة.
- غير كده: تُتجاهل (خارج النطاق).

## تنبيهات لصاحب النظام
- نسبة فشل > 20% خلال ساعة، أو كود حظر/تقييد من الوسيط → kill_switch تلقائي + إشعار (قناة يحددها المالك: FCM/إيميل).

## التشغيل
- حاوية `wa-worker` في docker compose بجانب Supabase، متغيرات بيئة: DB_URL, PROVIDER_KEY, WEBHOOK_SECRET, الرقم.
- صحة: `GET /wa/health` (داخلي).
- السجلات بدون نصوص رسايل كاملة أو أرقام كاملة.
