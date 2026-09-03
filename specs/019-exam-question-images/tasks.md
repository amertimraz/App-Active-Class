# Tasks: صور الأسئلة في الامتحان الإلكتروني

**Tests**: تحقّق يدوي + `flutter analyze` صفر تحذيرات. لا مهام اختبار.

## Phase 1: Data

- [x] T001 `lib/config/constants.dart`: `const String COL_EQ_IMAGE_URL = 'image_url';` + `DATABASE_VERSION` 23 → 24.
- [x] T002 `lib/models/exam_question_model.dart`: حقل `final String? imageUrl`؛ في `toMap` (`COL_EQ_IMAGE_URL: imageUrl`)، `fromMap`، `copyWith` (بـ sentinel أو nullable عادي)، و`toCloudMap` (`if (imageUrl != null) 'imageUrl': imageUrl`).
- [x] T003 `lib/services/database_service.dart`: أضف `$COL_EQ_IMAGE_URL TEXT` لـ`_examQuestionsTableSql`؛ migration `if (oldVersion < 24) { ALTER TABLE exam_questions ADD COLUMN image_url TEXT }` (داخل try/catch زي البقية).

## Phase 2: Upload

- [x] T004 `lib/services/online_exam_service.dart`: `Future<String> uploadQuestionImage(Uint8List bytes)` — `_ensureAuth()` ثم رفع لـ`exam_images/${slug}_${examId}_${ts}.jpg` (contentType image/jpeg) ثم `getDownloadURL()`. (توقيع ياخد bytes عشان يشتغل web/mobile زي `submitUpgradeRequest`.)
- [x] T005 `storage.rules`: `match /exam_images/{fileName} { allow create: if request.auth != null && request.resource.size < 5*1024*1024 && request.resource.contentType.matches('image/.*'); allow read: if true; allow update, delete: if false; }`
- [x] T006 `lib/controllers/exam_controller.dart`: `Future<String?> uploadQuestionImage(int examId, XFile file)` wrapper — يقرأ bytes، ينده الخدمة، يرجّع الرابط أو null عند الفشل.

## Phase 3: Editor UI

- [x] T007 `online_exam_editor_page.dart` `_QDraft`: `String? imageUrl` + `bool uploadingImage`؛ `toModel` يمرّر `imageUrl`؛ `_loadQuestions` يقرأه.
- [x] T008 `online_exam_editor_page.dart` `_questionCard`: تحت نص السؤال — لو `imageUrl == null`: زر "إضافة صورة" (`ImagePicker().pickImage(source: gallery, imageQuality: 70, maxWidth: 1600)` → `_ec.uploadQuestionImage` → `setState`)؛ لو موجود: `Image.network` مصغّرة (ارتفاع ~120) + زر حذف (`setState(() => q.imageUrl = null)`). أثناء الرفع: مؤشّر.

## Phase 4: Student page

- [x] T009 `booking_site/exam/index.html`: في حلقة عرض الأسئلة (~526)، بعد `.q-head` لو `q.v.imageUrl` → `<img class="q-img" src="${q.v.imageUrl}" alt="" loading="lazy">`. + CSS `.q-img{display:block;max-width:100%;height:auto;border-radius:10px;margin:8px 0;border:1px solid var(...)}`.

## Phase 5: Polish

- [x] T010 `flutter analyze` صفر أخطاء/تحذيرات.
- [ ] T011 تحقّق يدوي: نشر امتحان بسؤال له صورة، فتحه من موبايل، تأكد الصورة تظهر responsive وامتحان قديم ما اتأثرش.
- [x] T012 تحديث ملاحظات الجلسة + نشر `storage.rules` و`booking_site/exam/` على VPS (يدوي من المستخدم).
