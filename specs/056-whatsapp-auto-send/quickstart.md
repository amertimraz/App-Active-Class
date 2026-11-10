# Quickstart: التحقق من الإرسال التلقائي

## شروط مسبقة
- شريحة مصرية جديدة + حساب Meta Business موثّق + رقمك مسجّل على WhatsApp Cloud API (أو رقم Meta التجريبي للـ spike).
- 3 قوالب (غياب، تأخر دفع، إيصال) معتمدة.
- `migration_whatsapp_auto.sql` متطبق على السيرفر (بموافقة) و`wa-worker` شغال.
- مدرس تجريبي بطالب رقم ولي أمره = رقمك الشخصي.

## السيناريوهات
1. **Spike**: من الـ worker ابعت قالب غياب لرقمك → يوصل، والـ webhook يحدّث `delivered/read`.
2. **بدون موافقة**: فعّل الميزة وسجّل غياب → السجل يعرض `blocked: no_consent`، ومفيش رسالة.
3. **موافقة**: سجّل الموافقة → غياب جديد → رسالة خلال دقيقتين، السجل `delivered`.
4. **منع التكرار**: سجّل الغياب نفسه من جهازين/مرتين → رسالة واحدة.
5. **إيقاف**: رد "إيقاف" من رقمك → غياب جديد = `blocked: stopped`.
6. **الحصة**: اضبط الحصة 3 → ابعت 4 → الرابعة `blocked: no_quota` + إشعار واحد للمدرس؛ العداد بيطابق السجل.
7. **غير واتساب/رقم غلط**: `failed` بسبب عربي وزر "ابعتها يدوي".
8. **اليدوي**: أطفئ الميزة → كل أزرار واتساب القديمة تشتغل زي قبل.
9. **ساعات الإرسال**: غياب الساعة 11م → يتأجل لـ 8ص.

## أوامر
```bash
flutter test test/whatsapp_auto_rules_test.dart test/whatsapp_log_page_test.dart
flutter test test/help_sync_test.dart test/help_content_test.dart test/help_pages_test.dart
cd supabase/wa-worker && node --test
```

تفاصيل الجداول: [data-model.md](data-model.md) — العقود: [contracts/](contracts/).
