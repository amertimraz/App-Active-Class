# Implementation Plan: إرسال واتساب تلقائي من داخل التطبيق

**Branch**: `056-whatsapp-auto-send` (بدون branch فعلي) | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/056-whatsapp-auto-send/spec.md`

## Summary

التطبيق يكتب "طلبات إرسال" (outbox) على Supabase بعد أحداث الغياب/الدفع/التأخر. خدمة صغيرة جديدة على الـ VPS (worker) بتسحب الطلبات، تتحقق من الموافقة والحصة وساعات الإرسال، وتبعت عبر Meta WhatsApp Cloud API مباشرة (من غير وسيط) من رقم واحد مصري، وتستقبل webhook لحالة التسليم وردود "إيقاف". التطبيق يعرض الإعدادات والسجل والحصة. مفاتيح Meta تفضل على السيرفر فقط. الأزرار اليدوية الحالية ما تتغيرش.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.38 (التطبيق)؛ Node.js 20 (الـ worker الجديد — اختيار مقترح، يتأكد في spike)

**Primary Dependencies**: GetX، sqflite، supabase_flutter (موجودين)؛ للـ worker: `pg` + `fastify` (أو http مدمج) — بدون إطار ثقيل

**Storage**: Supabase Postgres (جداول جديدة `wa_*`)، وSQLite محلي للإعدادات فقط (مفيش جدول محلي للرسايل — السجل يُقرأ من السيرفر)

**Testing**: `flutter test` (منطق الأهلية + بناء الطلبات + شاشات)؛ اختبارات worker بـ `node --test` على Postgres مؤقت؛ اختبار إرسال حقيقي يدوي لرقم المدرس في quickstart

**Target Platform**: Android (تطبيق)، VPS Linux (docker compose بجانب حاويات Supabase الحالية)

**Project Type**: mobile-app + خدمة backend صغيرة

**Performance Goals**: 95% من الرسايل خلال دقيقتين؛ معدل 30 رسالة/دقيقة (قابل للضبط)

**Constraints**: مفاتيح سرية على السيرفر فقط؛ لا تكرار؛ يعمل مع الفريق (مساعدين) بدون إرسال مزدوج؛ لا تغيير في سلوك الأزرار اليدوية

**Scale/Scope**: عشرات المدرسين في التجربة، مئات الرسايل يوميًا؛ ~3 شاشات (إعدادات، سجل، موافقة) + 3 جداول + 1 خدمة

## Constitution Check

ملف constitution في المشروع قالب فاضي (غير مفعّل)، فمفيش بوابات رسمية. بدلها، قواعد المشروع من `CLAUDE.md` والذاكرة:

- **مركز المساعدة**: لازم موضوع جديد في `kHelpTopics` + تغطية المسارات الجديدة في `help_coverage.dart` + اختبارات help الثلاثة. ✅ مخطط (المرحلة 5).
- **تصميم السبورة والطباشير** عبر `AppTokens`/`AppPanel`، RTL، خط Cairo. ✅
- **Migrations على السيرفر** تتطبق يدويًا بموافقة (SSH + psql بـ `supabase_admin`). ✅ مخطط، مع طلب موافقة قبل التنفيذ.
- **لا transactions متداخلة في sqflite** (حادثة التعليق). ✅ مفيش جدول محلي جديد.
- **لا تغيير في الفلوس/الترخيص بدون سؤال**: الحصة والرصيد تمس الفلوس → قراراتها بيد صاحب النظام (الأرقام افتراضات في spec).

*Post-design*: لا مخالفات.

## Project Structure

### Documentation (this feature)

```text
specs/056-whatsapp-auto-send/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── outbox-and-quota.md     # عقد التطبيق ↔ Supabase
│   └── worker-and-webhook.md   # عقد الـ worker ↔ Meta Cloud API
├── checklists/requirements.md
└── tasks.md                    # /speckit-tasks (لم يُنشأ)
```

### Source Code (repository root)

```text
lib/
├── models/whatsapp_message_model.dart        # سجل + حالة
├── services/whatsapp_auto_service.dart       # enqueue + قراءة السجل/الحصة
├── services/whatsapp_auto_rules.dart         # أهلية صرفة: موافقة، ساعات، تكرار، نوع
├── controllers/whatsapp_auto_controller.dart
├── views/settings/categories/whatsapp_auto_category.dart
├── views/whatsapp/whatsapp_log_page.dart
├── views/whatsapp/consent_sheet.dart
└── help/help_content.dart                    # موضوع جديد + help_coverage.dart
supabase/
├── migration_whatsapp_auto.sql               # wa_outbox, wa_consents, wa_quota, wa_settings + RLS
└── wa-worker/                                # خدمة الإرسال (Dockerfile, src/, test/)
test/
├── whatsapp_auto_rules_test.dart
├── whatsapp_log_page_test.dart
└── (help tests تتحدّث)
```

**Structure Decision**: الإرسال الفعلي في خدمة منفصلة (`supabase/wa-worker`) لأن السيرفر الحالي مفيهوش runtime للـ functions، ولأن المفاتيح السرية ما تدخلش التطبيق. التطبيق يحط طلبات فقط.

## Phases

1. **Spike (قبل أي كود إنتاج)**: رقم Meta التجريبي المجاني ثم رقمك المصري؛ إرسال قالب واحد، قراءة webhook التسليم، تسجيل الرقم، التحقق من توقيع الـ webhook، تجديد الـ token، والتسعير الفعلي. نتيجته تحدّث `research.md` وعقد الـ worker.
2. **السيرفر**: migration + RLS + worker + webhook (عبر Caddy) + اختبارات.
3. **التطبيق (P1)**: إعدادات، موافقة، enqueue للغياب → ثم الدفع/الإيصال/التأخر.
4. **التطبيق (P2)**: سجل، حصة/رصيد، رسالة اختبار، تنبيه "اتبعتت تلقائيًا" في الأزرار اليدوية.
5. **المساعدة والجولة**: موضوع help + اختبارات؛ لوحة الأدمن (repo منفصل): ضبط حصة/رصيد/إيقاف.
6. **تجريبي مغلق** لمدرسين محددين قبل الفتح.

## Complexity Tracking

| الإضافة | ليه لازمة | البديل المرفوض |
|---|---|---|
| خدمة worker جديدة | إرسال من السيرفر + مفاتيح سرية + webhook | Edge Functions: غير موجودة في الستاك الحالي؛ الإرسال من التطبيق: يكسر شرط "من غير موبايل المدرس" ويكشف المفاتيح |
