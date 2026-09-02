# Contract — صفحة الطالب `booking_site/exam/index.html`

صفحة ثابتة على `active-class.online/exam/{slug}` — نمط `booking_site/track/index.html` بالكامل (Firebase JS SDK 10.12.0 عبر gstatic CDN، `signInAnonymously`, RTL عربي، خط Cairo، بلا خادم).

## الإدخالات

| مصدر | قيمة |
|---|---|
| المسار | `/exam/{slug}` — `getSlug()` نفس دالة `track` |
| حقل "كود الطالب" | نص، uppercase، مثال `A05` |
| حقل "آخر 4 أرقام من تليفون ولي الأمر" | 4 أرقام، `inputmode=numeric`, `maxlength=4` |

## آلة الحالات (شاشات)

```
loading
  → غير متاح            [slug مش موجود، أو parent_portal/{slug}.active !== true]
  → identity            [نموذج كود + آخر 4 أرقام]
      → خطأ الهوية       [parent_portal/{slug}/students/{code}_{last4} مش موجود] → يرجع identity برسالة عامة
      → قائمة الامتحانات [> 1 امتحان متاح للطالب] → اختيار
      → قبل الفتح        [now < opensAt] "الامتحان يبدأ الساعة …"
      → انتهى            [now > closesAt أو status=stopped] "انتهى وقت هذا الامتحان"
      → سلّم بالفعل      [submissions/{code}_{last4} موجود] "لقد سلّمت هذا الامتحان بالفعل"
      → الامتحان         [نافذة مفتوحة + الطالب في allowedCodes]
          → استئناف       [attempts موجود، الوقت المتبقّي > 0]
          → بدء جديد      [attempts مش موجود → create attempts]
      → غير مسموح لمجموعتك [code مش في allowedCodes]
  → تم الإرسال          [بعد create submissions ناجح] — نهائي، بلا درجة
```

## سلوك شاشة الامتحان

1. عند الدخول لأول مرة: `create` على `attempts/{code}_{last4}` بـ `{code, startedAt: serverTimestamp()}`. لو موجود (استئناف): اقرأه، احسب `remaining = startedAt + durationMinutes*60 - now`.
2. عرض: عدد الأسئلة، الدرجة الكلية، مؤقّت تنازلي `min(remaining, closesAt - now)`.
3. **خلط**: ترتيب الأسئلة وترتيب اختيارات كل سؤال يُخلطان بـ seed ثابت مشتق من `{code}` — بحيث الاستئناف يحافظ على نفس الترتيب. تُخزَّن خريطة `shuffledIndex → originalIndex` لبناء `answers` بالفهرس الأصلي عند التسليم.
4. الإجابات المدخلة → `localStorage["exam_{slug}_{examId}_{code}"]` بعد كل اختيار (FR-020). تُقرأ عند إعادة التحميل/الاستئناف.
5. **تسليم** (زر "تسليم" أو انتهاء المؤقّت):
   - بناء `answers = { "q<id>": originalIndex }` للأسئلة المُجابة فقط.
   - `create` على `submissions/{code}_{last4}` بـ `{code, answers, submittedAt: serverTimestamp(), autoSubmitted, startedAtClient}`.
   - نجاح → مسح `localStorage`، شاشة "تم الإرسال".
   - فشل شبكة → "لم يُرسَل بعد — لا تغلق الصفحة"، إعادة محاولة تلقائية كل 5ث + عند `online` event (FR: SC-007).
   - فشل بسبب "موجود بالفعل" (permission-denied على create متكرر) → شاشة "لقد سلّمت هذا الامتحان بالفعل".
6. **ممنوع**: عرض أي درجة، أي مؤشر صح/غلط، أي مراجعة بعد التسليم (FR-019).

## قراءات Firestore التي تقوم بها الصفحة

| متى | قراءة |
|---|---|
| init | `online_exams/{slug}` (وجود + `active`)؛ أو `parent_portal/{slug}` لفحص `active` |
| بعد الهوية | `parent_portal/{slug}/students/{code}_{last4}` (وجود + `groupName`) |
| بعد الهوية | `online_exams/{slug}/exams` (collection) — تصفية بـ `allowedCodes[code] == true` و`status == 'published'` والنافذة |
| فتح امتحان | `attempts/{code}_{last4}` (get ثم create لو مفقود) |
| قبل العرض | `submissions/{code}_{last4}` (get — لو موجود: شاشة "سلّمت بالفعل") |

## أمان الصفحة

- لا تقرأ ولا تعرض الإجابات الصحيحة (مش موجودة في السحابة أصلًا).
- لا تقرأ تسليمات طلاب آخرين (القاعدة تمنع؛ الصفحة تقرأ مستند `{code}_{last4}` الخاص بها فقط).
- رسالة خطأ الهوية عامة: "الكود أو الأرقام غير صحيحة" — بلا كشف أيّهما.
- `escapeHtml` على كل نص من Firestore قبل الإدراج (نمط `track`/`book`).
- honeypot غير مطلوب (لا إرسال مجهول مفتوح — `create` مقيّد بالشكل + معرّف حتمي).

## التوقيت

كل المقارنات بـ `Date.now()` (ms since epoch, UTC). `opensAt`/`closesAt` من المستند تُحوَّل بـ `new Date(iso)`. `startedAt` من `attempts` = Firestore Timestamp → `.toDate().getTime()`. لا اعتماد على ساعة العرض المحلية للمنطقة الزمنية.

## النشر اليدوي

الملف الوحيد المتغيّر: `booking_site/exam/index.html` جديد. يُرفع للـVPS تحت `/exam/index.html` (توجيه `/exam/*` → نفس الملف، زي `/track` و`/book`). موثّق في quickstart كـ "شغل يدوي على المستخدم".
