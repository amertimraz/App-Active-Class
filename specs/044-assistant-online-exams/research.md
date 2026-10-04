# Phase 0 Research: المساعد والامتحانات الإلكترونية

## 1. لماذا المساعد مقفول حاليًا
- كل البوابات (`online_exams_tab.dart`، زر الإنشاء في `exams_page.dart`، `ExamController.publishOnlineExam`) بتفحص `LicenseController.to.parentPortalActiveNow` — قيمة من مستند ترخيص **الجهاز نفسه** على Firestore. `teamModeBypassLimits` بيتخطى حدود الباقة (مجموعات/طلاب/تصدير/واتساب/حجز) بس، مش إضافة البوابة. جهاز المساعد ترخيصه تجريبي بلا بوابة.
- slug الرابط: `ParentPortalService.ensureSlug()` بيشتق من `LicenseController.licenseCode` المحلي؛ المساعد معاه كود `null` فبيتولّد له slug عشوائي مختلف.

## 2. القرار: حالة البوابة + الـslug على صف الفريق
- **Decision**: أعمدة جديدة في `teams`: `portal_slug text`, `portal_enabled boolean`, `portal_expires_at timestamptz`. جهاز المدرس بيدفعها بـRPC `set_team_portal` (owner فقط) كلما تغيّر `parentPortalEnabled`/`parentPortalExpiresAt`/`licenseCode`/`licenseVerifiedTick`. المساعد بيقراها (RLS الحالي للمساعدين بيقرأ `teams` أصلًا، ومنها `license_code`).
- **Rationale**: نفس نمط `owner_license_active` الموجود. الـslug مشتق من الكود بدالة FNV غير قابلة للعكس عمليًا، فنخزّنه جاهز بدل ما نعيد حسابه من الكود عند المساعد → لا كشف جديد.
- **ملاحظة صراحة**: `teams.license_code` بيوصل جهاز المساعد فعلًا اليوم (لربط جهازه بالترخيص) — الميزة لا تضيف ولا تُلغي ده (FR-007 معدّل).
- **Alternatives**: حساب الـslug عند المساعد من `license_code` — رُفض (يعتمد على الكود، ويكرر منطق الاشتقاق).

## 3. الصلاحية
- **Decision**: عمود `team_members.can_manage_online_exams boolean not null default false` + getter `canManageOnlineExamsNow` بنمط `canXxxNow` (المدرس/خارج الفريق دايمًا true). تتحدّث عند المساعد: `_refreshMyPermissions` الحالية + مؤقت تحديث دوري كل 30 ثانية للمساعد فقط (الحالي بيحصل عند إعادة الاتصال بس).
- زي `can_view_*` صلاحية على مستوى العميل لقراءة/كتابة جداول الفريق (امتحانات/أسئلة/تسليمات بتتزامن عبر Supabase بصلاحيات الفريق العامة). **الإنفاذ الحقيقي** للنشر على الطلاب يحصل عبر Firestore (القسم 4)، لأن ده اللي بيأثر على الطلاب.

## 4. تفويض Firestore (الجزء الأخطر)
- القواعد الحالية: الكتابة تحت `online_exams/{slug}/exams/**` مقصورة على `get(online_exams/{slug}).ownerUid == request.auth.uid`، والـuid ده Firebase **Anonymous** لكل جهاز. المساعد uid مختلف → مرفوض.
- **Decision**: المدرس يكتب مصفوفة `coOwnerUids` في مستند `online_exams/{slug}` (حقل يكتبه المالك فقط)، و`_oeOwner(slug)` تقبل: `ownerUid == uid` **أو** `uid in coOwnerUids`. التفويض مقصور على `exams/**` (لا كتابة على المستند الجذر ولا على `parent_portal`).
- **كيف يعرف المدرس uid المساعد**: المساعد يسجّل uid الـFirebase بتاعه عبر RPC `set_my_firebase_uid` → `team_members.firebase_uid`. جهاز المدرس يقرأ أعضاء الفريق (`can_manage_online_exams = true` و`firebase_uid` موجود) ويكتب `coOwnerUids` — عند الإقلاع، وبعد تغيير الصلاحية من شاشة الأعضاء فورًا، ودوريًا كل دقيقتين.
- **Rationale**: Spark plan بلا Cloud Functions، والـrules مش تقدر تكلّم Supabase؛ ده أبسط مسار قابل للتنفيذ داخل القيود الحالية.
- **قيد معروف**: التفويض/السحب يحتاج جهاز المدرس متصل مرة بعد التغيير (موثّق في Assumptions). uid المساعد بيتغيّر بعد إعادة التثبيت → يعيد التسجيل تلقائيًا ويتفوّض تاني عند دورة المدرس الجاية.
- **مشكلة قائمة (خارج النطاق)**: قاعدة `online_exams/{slug}` الحالية تسمح بأي `update` لو `request.resource.data.deviceId == resource.data.deviceId`، و`deviceId` قابل للقراءة عامة (`allow read: if true`) → أي مستخدم مصدّق يقدر يستولي على ملكية الجذر. ده ثغرة موجودة من قبل ومش بتتفاقم بهذه الميزة؛ بنرفعها كمهمة منفصلة (مش جزء من الإصلاح هنا).

## 5. مسار النشر للمساعد
- `OnlineExamService._slug()`: مساعد → `TeamModeService().teamPortalSlug`، غيره → `ensureSlug()` (سلوك المدرس ثابت).
- `publish()` للمساعد: **يتخطى** كتابة `online_exams/{slug}` (الجذر)، و`publishProfile()`، وخطوة "ensure summaries" (كلها كتابات مالك بترفض للمساعد) ويكتب مستند `exams/{id}` مباشرة. المدرس هو اللي حافظ الجذر والملخصات (الوضع الحالي).
- `uploadQuestionImage` يستخدم نفس الـslug الفعّال.

## 6. قفل/وضع القراءة
- دالة صرفة `onlineExamAccess({isTeam, isOwner, canManage, portalActive, hasSlug})` → `{locked, readOnly, canCreate}`:
  - خارج الفريق/مالك: `locked = !portalActive`, `readOnly = false`.
  - مساعد: `locked = !teamPortalActive` (اشتراك المدرس)، `readOnly = !canManage`، `canCreate = canManage && teamPortalActive && hasSlug`.
- الشاشات بتقرأ النتيجة بدل شروط متفرقة. `LicenseController.parentPortalActiveNow` يفضل مرجع المالك/خارج الفريق.

## 7. بانر وإشعارات الانتهاء
- موجودة للمدرس فقط (`PortalExpiryBanner` و`schedulePortalExpiryReminders` بيتحققوا `isOwner`) → المساعد مايشوفش تجديد (FR-009) بدون تغيير.

## 8. تتبع المنشئ (FR-013)
- **Decision**: عمود `created_by_name text` على `exams` (محلي DB v37 + Supabase + مزامنة)، يتعبّى باسم العضو وقت إنشاء الامتحان الإلكتروني، ويظهر في بطاقة الامتحان. أولوية منخفضة (US4) ومنفصلة عن الباقي.

## 9. ما لن نغيّره
- كتابة المساعد في `parent_portal/{slug}/students` (ملخصات أولياء الأمور) — خارج النطاق.
- صفحة الطالب `booking_site/exam/index.html` — بدون تغيير (نفس مستند الامتحان).
