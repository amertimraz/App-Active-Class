# Implementation Plan: اتساق تعارضات مزامنة الفريق

**Branch**: `031-team-sync-conflict-consistency` | **Date**: 2026-09-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/031-team-sync-conflict-consistency/spec.md`

## Summary

إصلاحان:

1. **وقت خادم موحَّد لـ`updated_at`** — migration Supabase يضيف trigger `BEFORE INSERT OR UPDATE` على كل الجداول المتزامنة يضبط `NEW.updated_at = now()`. فمقارنة LWW في `_applyRemoteRow` تعتمد وقت الخادم لا ساعة الجهاز المُرسِل. الجهاز يتبنّى `updated_at` من الخادم عند السحب (يفعل بالفعل عبر `_toLocalMap`).

2. **توفيق الصف المكرّر بدل تجاهله** — في `_applyRemoteRow` عند اكتشاف صف وارد يطابق منطقيًا صفًا محليًا بمعرّف مزامنة مختلف (حضور/واجب/درجة/ربط امتحان-مجموعة/تسليم)، بدل `return` الصامت: نقارن `remote['updated_at']` بـ`sync_updated_at` للصف المحلي المكرّر؛ لو الوارد أحدث → نحدّث **حقول البيانات** للصف المحلي من `_toLocalMap(remote)` **مع الاحتفاظ بـ`remote_id` المحلي** (لا نغيّره). لو الوارد أقدم → لا شيء. تعادل تام → حسم بالمعرّف الأصغر معجميًا.

النتيجة: الجهازان يتّفقان على البيانات (الأحدث يفوز) رغم اختلاف `remote_id` داخليًا. الصفّان على الخادم يبقيان ويعيدان البثّ (يخسران LWW كل مرة — اتساق نهائي؛ التنظيف خارج النطاق).

صفر تغيير في مخطط قاعدة البيانات المحلية (v28)، صفر تغيير في الصلاحيات/RLS، صفر مكتبات جديدة. تغيير الخادم = trigger واحد فقط.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1؛ SQL (Postgres/Supabase) للـmigration.

**Primary Dependencies**: `supabase_flutter` القائم، `sqflite`. لا مكتبات جديدة.

**Storage**: قاعدة SQLite المحلية v28 (لا تغيير). Supabase: **trigger واحد** على 11 جدول متزامن (`groups`, `students`, `attendance`, `payments`, `homework`, `exams`, `exam_groups`, `exam_grades`, `exam_questions`, `exam_submissions`, `bank_questions`). لا عمود جديد.

**Testing**: `flutter test` — وحدة نقية لمنطق "أي صف يفوز؟" (`updated_at` مقارنة + tie-break بالمعرّف) — دالة `resolveDuplicate(...)` قابلة للعزل. اختبار SQL يدوي للـtrigger عبر SSH.

**Target Platform**: Android + خادم Supabase على VPS.

**Project Type**: تطبيق موبايل Flutter + خادم.

**Performance Goals**: `_applyRemoteRow` عند dup — استعلام إضافي واحد (`SELECT` للصف المكرّر بحقوله) بدل صفر؛ نادر (فقط عند تعارض فعلي). trigger الخادم = ضبط عمود واحد لكل كتابة — تكلفة ضئيلة.

**Constraints**: صفر تغيير DB schema محلي/نسخة. صفر تغيير RLS. الـtrigger يضبط `updated_at` فقط — لا يمسّ أي منطق قائم يقرأه (المحرّك يستخدمه للمقارنة النسبية بس). التوفيق **لا يغيّر `remote_id` المحلي** (يتفادى إرباك دفعات الـoutbox اللاحقة).

**Scale/Scope**: `lib/services/sync_engine.dart` (~+40 سطر: استخراج دالة `_reconcileDuplicate`، استبدال 5 كتل `if (dup.isNotEmpty) { return; }`). `lib/utils/sync_conflict.dart` جديد (دالة نقية). 1 ملف اختبار. 1 ملف migration SQL `supabase/migration_server_updated_at.sql`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

الدستور قالب فارغ. أعراف المشروع:

| عرف | الحالة |
|---|---|
| صفر تغيير DB schema محلي إلا بترقية صريحة | ✅ PASS |
| تغيير الخادم مقيّد ومبرَّر (إصلاح فقدان بيانات) | ✅ trigger واحد، لا RLS، لا عمود |
| لا مكتبات جديدة | ✅ PASS |
| إعادة استخدام: `_toLocalMap`, LWW القائم, أنماط dup القائمة | ✅ PASS |
| migration عبر SSH (specs 021/024/025) | ✅ نفس النمط |
| اختبار للمنطق الجديد + `analyze` نظيف | ✅ مخطّط |
| إصلاح باج مبلَّغ من مستخدم — أولوية | ✅ P1 |

**النتيجة: PASS** — لا انتهاكات.

## Project Structure

### Documentation (this feature)

```text
specs/031-team-sync-conflict-consistency/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 5 قرارات
├── data-model.md        # Phase 1 — لا سكيمة؛ trigger + منطق التوفيق
├── quickstart.md        # Phase 1 — سيناريوهات (محاكاة + جهازين + SQL)
├── contracts/
│   ├── server-updated-at-trigger.md   # عقد الـmigration
│   └── duplicate-reconcile.md          # عقد منطق التوفيق في _applyRemoteRow
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── utils/
│   └── sync_conflict.dart      # جديد — دالة نقية: هل الوارد يفوز؟ (updated_at + tie-break)
└── services/
    └── sync_engine.dart        # 5 كتل dup → _reconcileDuplicate؛ + تعليق على LWW = وقت خادم

supabase/
└── migration_server_updated_at.sql   # جديد — trigger على 11 جدول

test/
└── sync_conflict_test.dart     # جديد — وحدة resolveIncomingWins
```

**Structure Decision**: المنطق القابل للعزل (مقارنة `updated_at` + tie-break) في `lib/utils/sync_conflict.dart`. `sync_engine.dart` يستدعيه ويقوم بالـSQL. الـmigration في `supabase/` بجانب migrations السابقة. صفر تغيير UI.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.
