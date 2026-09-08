# Implementation Plan: تقوية مزامنة وضع الفريق

**Branch**: `030-team-sync-hardening` | **Date**: 2026-09-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/030-team-sync-hardening/spec.md`

## Summary

ثلاثة إصلاحات داخل `lib/services/sync_engine.dart` (+ سطر ربط lifecycle):

1. **طابور الإرسال**: `Map<int outboxId, int> _outboxFails` في الذاكرة. عنصر فشل (`_pushOne` رجع false أو رمى) → `_outboxFails[id]++`. عنصر نجح → يُحذف من DB ومن الخريطة. عنصر تجاوز 5 فشل → متخطّى: يُستبعَد من استعلام `drainOutbox` (`AND id NOT IN (المتخطّاة)`) إلا كل ~20 جولة (retry متباعد)، ولوج واحد عبر `Set<int> _loggedPoison`.
2. **السحب الدوري**: `Timer? _catchUpTimer` في `start()` كل 50 ثانية → `catchUpPull()` (يحترم `_lastCatchUp` guard الموجود). `SyncEngine implements WidgetsBindingObserver` — `didChangeAppLifecycleState(resumed)` → `catchUpPull()`. يُلغى في `stop()`.
3. **التحقق من العضوية**: قبل `onRemovedFromTeam()`/`onDeviceUnbound()` — حارس `_sessionValid()` (`client.auth.currentSession != null && !currentSession!.isExpired`؛ لو لأ → `unawaited(client.auth.refreshSession())` + `return false`). عدّاد `_emptyMembershipStreak` — يزيد على نتيجة فاضية، يُصفَّر على نتيجة صحيحة؛ `onRemovedFromTeam()` فقط عند `>= 3`. نفس النمط لـ`_deviceUnboundStreak`.

صفر تغيير DB schema (v28)، صفر تغيير خادم/RLS، صفر مكتبات جديدة، صفر تغيير في بروتوكول المزامنة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: `supabase_flutter` القائم (`client.auth.currentSession` / `.refreshSession()` / `.onPostgresChanges`)، `flutter/widgets` (`WidgetsBindingObserver`)، `dart:async` (`Timer`). GetX غير مطلوب هنا. لا مكتبات جديدة.

**Storage**: `sync_outbox` المحلي — يُقرأ/يُحذف فقط، **لا عمود جديد**. عدّادات الفشل والـstreaks في الذاكرة (تُصفَّر بإعادة تشغيل التطبيق). DB version يبقى **28**.

**Testing**: `flutter test` — دوال مساعدة نقية: منطق "هل يُتخطّى هذا العنصر في هذه الجولة؟" (عدّاد + عتبة + retry متباعد)، ومنطق "هل نطلق الإزالة؟" (streak + session valid). تُستخرَج كدوال/كلاس صغير قابل للاختبار بلا شبكة.

**Target Platform**: Android (وأي منصة — لا كود منصّي).

**Project Type**: تطبيق موبايل Flutter (هيكل `lib/` مفرد).

**Performance Goals**: `drainOutbox` كما اليوم (كل 3s، 50 صف). سحب دوري كل 50s — طلب شبكة واحد، محمي بـ`_lastCatchUp` و`_pulling`. حارس الجلسة = فحص محلي (بلا شبكة) عدا `refreshSession` النادر.

**Constraints**: صفر تغيير DB/خادم/بروتوكول. جهاز المدرّس (المالك): الكولباكات `onRemovedFromTeam`/`onDeviceUnbound` = `null` له أصلًا، فمنطق الـstreak لا يعمل عنده (الفحوصات مبنية على `if (onRemovedFromTeam != null ...)`). السحب الدوري + تقوية الطابور يعملان للطرفين. أي عنصر طابور فاشل يظل معلّقًا (لا حذف — FR-006).

**Scale/Scope**: ملف واحد رئيسي `sync_engine.dart` (~+80 سطر: 3 حقول حالة، تعديل `drainOutbox`، تعديل `_checkStillAllowed`/`_wasRemovedFromTeam`/`_wasDeviceUnbound`، `WidgetsBindingObserver`، تايمر). دالة/كلاس مساعد صغير للاختبار. ملف اختبار واحد. صفر تعديل UI. `main.dart`/`team_mode_service.dart` غالبًا بلا تغيير (SyncEngine يسجّل observer بنفسه).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

الدستور `.specify/memory/constitution.md` قالب فارغ. أعراف المشروع:

| عرف | الحالة |
|---|---|
| صفر تغيير DB schema | ✅ PASS — حالة في الذاكرة فقط |
| صفر تغيير في بروتوكول المزامنة / الخادم / RLS | ✅ PASS |
| لا مكتبات جديدة | ✅ PASS |
| إعادة استخدام الآليات القائمة (`_lastCatchUp`, `_pulling`, `catchUpPull`, أنماط التايمرات) | ✅ PASS |
| إصلاح باج مبلَّغ من مستخدم فعلي — أولوية | ✅ P1 |
| اختبارات لكل منطق جديد + `flutter analyze` نظيف | ✅ مخطّط |
| git push بإذن؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات، لا Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/030-team-sync-hardening/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 6 قرارات محسومة
├── data-model.md        # Phase 1 — حالة runtime، لا سكيمة
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق (محاكاة + جهازين)
├── contracts/
│   ├── outbox-retry-policy.md      # عقد سياسة إعادة المحاولة/التخطّي
│   └── membership-check-guard.md   # عقد حارس الجلسة + عتبة الـstreak + السحب الدوري
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── services/
│   └── sync_engine.dart        # الإصلاحات الثلاثة + WidgetsBindingObserver + التايمر
└── utils/
    └── sync_retry_policy.dart  # جديد (اختياري) — دوال نقية: shouldAttemptThisRound(fails, round), shouldFireRemoval(streak, sessionValid)

test/
└── sync_retry_policy_test.dart # جديد — وحدة للدوال النقية
```

**Structure Decision**: التغيير الجوهري كله في `sync_engine.dart`. المنطق القابل للاختبار بمعزل (عتبات + عدّادات) يُستخرَج إلى `lib/utils/sync_retry_policy.dart` كدوال ثابتة نقية (بلا شبكة/حالة)، فـ`SyncEngine` يستدعيها ويحتفظ بالخرائط/العدّادات كحقول. `SyncEngine` يصير `WidgetsBindingObserver` ويسجّل/يلغي نفسه في `start()`/`stop()` — لا لمس لـ`main.dart`.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.
