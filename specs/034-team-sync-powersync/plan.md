# Implementation Plan: مزامنة موثوقة لوضع الفريق (PowerSync)

**Branch**: `034-team-sync-powersync` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/034-team-sync-powersync/spec.md`

## Summary

استبدال `SyncEngine` اليدوي الحالي (outbox + full-pull بالصفحات + Realtime channels + LWW يدوي) بـ **PowerSync Open Edition self-hosted** — خدمة مزامنة مفتوحة المصدر (مجانية، Functional Source License) بتشتغل كـ Docker container إضافي على نفس الـVPS، بتتصل بنفس قاعدة Postgres الحالية (self-hosted Supabase) عبر Logical Replication، وبتستخدم Postgres نفسه لتخزين الـsync buckets الداخلية (مفيش حاجة لـMongoDB). على العميل، حزمة `powersync` الرسمية لـFlutter بتستبدل قراءة/كتابة `sqflite` المباشرة في `database_service.dart` بقاعدة SQLite محلية بتتزامن أوتوماتيك — القراءة/الكتابة المحلية تفضل فورية زي دلوقتي (offline-first)، وPowerSync بيتكفّل بطابور الرفع، التحميل التدريجي، إعادة المحاولة، واستئناف الاتصال.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1 (عميل) — بلا تغيير. الخادم: صورة Docker جاهزة `journeyapps/powersync-service` (TypeScript/Node.js داخليًا، مفيش كود سيرفر لازم نكتبه إحنا).

**Primary Dependencies**: حزمة `powersync` (Dart/Flutter SDK)، إضافة إلى `supabase_flutter` الحالية (تفضل مستخدمة للمصادقة/الترخيص وأي عمليات لا تحتاج مزامنة مباشرة). على الخادم: `journeyapps/powersync-service` Docker image.

**Storage**: نفس Postgres الحالي (self-hosted Supabase على الـVPS) — PowerSync بيستخدمه كمصدر أساسي (عبر Logical Replication) **وكمخزن داخلي لبيانات الـsync buckets** (وضع `--storage postgres`، متاح من v1.3.8+ — يلغي الحاجة لـMongoDB). العميل: SQLite محلي مُدار بواسطة `powersync` SDK (يستبدل استخدام `sqflite` المباشر لنفس الجداول المتزامنة؛ الجداول غير المتزامنة — إعدادات محلية بحتة زي `app_settings`/الإشعارات — تفضل على `sqflite` عادي بلا تغيير).

**Testing**: `flutter test` (نفس الحالي) للمنطق الصرف (resolvers، حسم تعارضات، تحويل الصفوف) + سيناريوهات `quickstart.md` اليدوية للتحقق من المزامنة الفعلية (لا يوجد إطار اختبار آلي لـPowerSync نفسه ضمن هذا المشروع).

**Target Platform**: Android (نفس الحالي) للعميل؛ Linux/Docker على الـVPS الحالي للخادم.

**Project Type**: تطبيق موبايل + خدمة خلفية ذاتية الاستضافة (mobile-app + self-hosted backend service) — إضافة حاوية جديدة لبنية VPS قائمة بالفعل (Postgres/PostgREST/GoTrue/Realtime/Kong).

**Performance Goals**: نفس أهداف SC في الـspec — تحميل ١٥٠٠+ سجل حضور لجهاز جديد خلال <١٠ دقايق، وصفر بيانات مفقودة بصمت.

**Constraints**: يجب الحفاظ على offline-first الكامل للمستخدم بدون وضع الفريق (بلا أي اعتماد جديد على PowerSync أو الشبكة لهذا المسار). يجب عدم كسر نظام ترخيص Firebase الحالي (مستقل تمامًا). البنية التحتية الحالية (Kong/PostgREST/RLS) تبقى كما هي — PowerSync بيقرا نفس جداول Postgres ونفس صلاحيات RLS، مش بديل عنها.

**Scale/Scope**: ٩ فرق حاليًا (أكبرها ٥٣١ طالب / ٣٧٤٩ سجل حضور)، نمو متوقع تدريجي خلال السنة الجاية — حجم صغير نسبيًا بالنسبة لحدود PowerSync (بيدعم آلاف المستخدمين المتزامنين في التصميم العام)، فمفيش قلق أداء متوقع عند هذا الحجم.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

المشروع مفيش عنده `constitution.md` مُفعّل فعليًا (الملف لسه على شكل القالب الافتراضي بدون مبادئ مكتوبة) — فمفيش بوابات (gates) رسمية تتفحص. الاعتبارات العملية المكافئة (من نمط المشروع الفعلي عبر السبيكات 028-033 السابقة) اتفحصت يدويًا:
- ✅ لا تغيير في منطق العمل (حضور/مدفوعات/امتحانات) — الميزة دي بنية تحتية بحتة.
- ✅ لا تغيير في نظام الترخيص (Firebase) — مستقل تمامًا عن وضع الفريق.
- ✅ الحفاظ على offline-first للمستخدم العادي — قسم Assumptions في الـspec يوثّق ده كخط أحمر.
- ⚠️ إضافة اعتماد جديد (PowerSync Service كحاوية Docker إضافية) — مُبرَّر في research.md (البديل: الاستمرار في صيانة محرك مزامنة يدوي مُثبَت تاريخيًا إنه عرضة لباگات متكررة).

## Project Structure

### Documentation (this feature)

```text
specs/034-team-sync-powersync/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات تقنية + بدائل
├── data-model.md         # Phase 1 — الكيانات وsync rules
├── contracts/            # Phase 1 — عقود sync rules + عقد الرفع
│   ├── sync-rules.md
│   └── upload-queue.md
├── quickstart.md         # Phase 1 — سيناريوهات تحقق قابلة للتشغيل
└── tasks.md              # Phase 2 (/speckit-tasks — لسه مش منشأ)
```

### Source Code (repository root)

```text
active_class/                          # مشروع Flutter واحد (بلا تغيير في البنية العامة)
├── lib/
│   ├── services/
│   │   ├── database_service.dart      # يتقسّم: PowerSyncDatabaseService (جداول الفريق) + المتبقي لـsqflite (إعدادات محلية بحتة)
│   │   ├── sync_engine.dart           # يُحذف بالكامل (يستبدله PowerSync SDK)
│   │   ├── powersync_service.dart     # [جديد] تهيئة/اتصال/schema لـPowerSync
│   │   └── team_mode_service.dart     # يتعدّل: تفعيل/تعطيل وضع الفريق يشغّل/يوقف اتصال PowerSync بدل SyncEngine
│   ├── controllers/                    # بلا تغيير بنيوي — بتقرا من نفس الجداول (PowerSync SQLite بدل sqflite للجداول المتزامنة)
│   └── ...
├── supabase/
│   └── migrations/                     # migrations الحالية تبقى — sync rules PowerSync طبقة إضافية فوقها، مش بديل
└── vps/ (خارج المستودع — إعداد يدوي على الخادم)
    └── docker-compose.yml (+powersync-service) + sync-rules.yaml
```

**Structure Decision**: تطبيق Flutter واحد (بلا تغيير في البنية العامة) + إضافة خدمة PowerSync كحاوية على نفس الـVPS القائم بالفعل. لا مشروع "backend" منفصل داخل هذا المستودع — إعداد الخادم (docker-compose + sync rules) يُدار على الـVPS مباشرة، بنفس نمط `supabase/migration_*.sql` الحالي (ملفات إعداد تُطبَّق يدويًا/عبر SSH، موثّقة في المستودع).

## Complexity Tracking

> لا توجد انتهاكات دستورية تحتاج تبرير — لا يوجد `constitution.md` مُفعّل. الاعتبار الوحيد المسجَّل أعلاه (اعتماد جديد) مُبرَّر داخل الجدول أعلاه نفسه بدل تكراره هنا.
