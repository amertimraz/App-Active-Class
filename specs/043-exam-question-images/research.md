# Phase 0 Research: صور أسئلة الامتحان

## 1. مكتبة القص
- **Decision**: `image_cropper` (قص تفاعلي أصلي على Android/iOS، شاشة UI جاهزة بتكبير/تصغير/سحب وحرية النسبة).
- **Rationale**: المشروع عنده `image_picker` بالفعل لاختيار الصورة؛ `image_cropper` هو الامتداد القياسي للقص بعد الاختيار في Flutter، وبيدعم "أي نسبة" (FR الأساسي) بدل ما نبني UI قص يدوي.
- **إعداد مطلوب**: Android يحتاج تسجيل `UCropActivity` في `android/app/src/main/AndroidManifest.xml` (نمط قياسي للمكتبة)؛ iOS خارج نطاق هذا المشروع (Android-only حاليًا حسب `release_assets`).
- **Alternatives**: قص يدوي بـ`CustomPainter` — رُفض (تعقيد ومخاطرة أعلى بلا داعٍ لمكتبة ناضجة موجودة).

## 2. تدفّق الاختيار + القص (مشترك)
- **Decision**: ودجت/دالة واحدة `pickAndCropImage(BuildContext) → Future<Uint8List?>` في `lib/widgets/image_crop_picker.dart`: `ImagePicker.pickImage` (نفس إعدادات `requestFullMetadata: false` ومعالجة MIUI lost-data الموجودة في الكود الحالي) ثم `ImageCropper.cropImage` ثم قراءة bytes. ترجع null لو المستخدم ألغى أي خطوة (FR-002).
- **Rationale**: نفس الكود مكرر 3 مرات دلوقتي بالظبط (بس لصورة السؤال) في شاشتين؛ هيتكرر 6 مرات لو ضفنا شرح+اختيارات بدون توحيد.

## 3. تخزين صور الاختيارات
- **Decision**: عمود جديد `option_image_urls` (TEXT، JSON لقائمة `String?` بنفس طول وترتيب `options`، نفس نمط تخزين `options` نفسها بـ`jsonEncode`/`jsonDecode`). عنصر `null` = الاختيار ده بلا صورة.
- **Rationale**: يحافظ على المحاذاة بالـindex مع `options` الموجودة، وأبسط من جدول فرعي منفصل لعلاقة 1-إلى-N بسيطة بحجم ثابت (≤6).
- **تزامن الحذف/الإضافة**: أي عملية على `options` (حذف اختيار، إضافة اختيار) في المحرّر لازم تطبّق نفس العملية بالـindex على `optionImageUrls` في نفس اللحظة (دالة صرفة مختبرة).

## 4. صورة الشرح — نفس قاعدة سرّية النص
- **Decision**: عمود `explanation_image_url` يُعامَل تمامًا زي `explanation` الحالي: محلي + متزامن بين أجهزة الفريق (`exam_questions`/`bank_questions`)، لكن **غير موجود في `toCloudMap`** (مسار السؤال العام اللي بيوصل صفحة الامتحان وقت الأداء). يوصل الطالب فقط عبر `publishReview` → مستند `results/{attemptKey}` بعد الاعتماد (نفس مسار `explanation` بالظبط).
- **Rationale**: ده نفس الالتزام الموجود فعليًا لـ`explanation` (راجع تعليق `ExamQuestion.explanation` في الكود) — الميزة الجديدة بتتبع نفس القاعدة الأمنية حرفيًا بدل ما تخترع قاعدة جديدة.

## 5. صور الاختيارات — لازم في `toCloudMap`
- **Decision**: `toCloudMap()` تضيف `optionImageUrls` (مفلترة لو كل العناصر null → ما تتضافش خالص، توفيرًا لحجم المستند) لأن الطالب لازم يشوفها وهو بيجاوب (FR-006)، على عكس الشرح.

## 6. صفحة أداء الامتحان (`booking_site/exam/index.html`)
- **Decision**: `optMaps` الحالية بتحافظ على الـindex الأصلي لكل اختيار بعد الخلط (`{v: text, i: originalIndex}`) — فصورة الاختيار تتجاب بـ`q.v.optionImageUrls?.[op.i]` مباشرة بدون أي منطق خلط إضافي. نفس الفكرة في `renderReview` (`q.options[oi]` ↔ `q.optionImageUrls?.[oi]`، بلا خلط أصلاً في المراجعة).
- صورة الشرح تُضاف داخل `renderReview` بس، جنب نص `q.explanation` الموجود، خلف نفس الشرط `q.explanation` (أو شرط مستقل لو فيه صورة بلا نص — نادر لكن ممكن حسب FR-008 العكسي: حذف النص بدون الصورة مش مطلوب دعمه، لكن حذف الصورة بدون النص مطلوب).
- فشل تحميل أي `<img>` (سؤال/اختيار/شرح): `onerror` بسيط يستبدل الصورة بنص "تعذّر تحميل الصورة" بدل ما يكسر تخطيط الصفحة (FR-011/SC-005) — الصفحة أصلًا ما فيهاش أي معالجة onerror للصور حاليًا، فده تحسين لصورة السؤال القديمة كمان مش بس الجديد.

## 7. بنك الأسئلة (FR-012)
- **Decision**: `BankQuestion` ياخد نفس الحقلين، و`_QDraft.fromBankQuestion` (محرّر الامتحان) ينسخهم زي `imageUrl`/`explanation` تمامًا. `toExamQuestion`/أي تحويل مماثل في `question_bank_controller.dart` يُحدَّث بالمثل.

## 8. الضغط/التصغير
- **Decision**: نفس قيم `imageQuality: 70, maxWidth: 1600` الحالية تُطبَّق على **الصورة المقصوصة** قبل الرفع (مش قبل القص) — القص أولًا (المدرّس شايف جودة كاملة وهو بيحدّد المنطقة)، والضغط يحصل عند التصدير النهائي من شاشة القص (إعداد `compressQuality` في `image_cropper`).
