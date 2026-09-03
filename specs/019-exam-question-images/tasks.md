# Tasks: صور الأسئلة في الامتحان الإلكتروني

**Tests**: تحقّق يدوي + `flutter analyze` صفر تحذيرات. لا مهام اختبار.

## Phase 1: Data

- [x] T001 `lib/config/constants.dart`: `const String COL_EQ_IMAGE_URL = 'image_url';` + `DATABASE_VERSION` 23 → 24.
- [x] T002 `lib/models/exam_question_model.dart`: حقل `final String? imageUrl`؛ في `toMap` (`COL_EQ_IMAGE_URL: imageUrl`)، `fromMap`، `copyWith` (بـ sentinel أو nullable عادي)، و`toCloudMap` (`if (imageUrl != null) 'imageUrl': imageUrl`).
- [x] T003 `lib/services/database_service.dart`: أضف `$COL_EQ_IMAGE_URL TEXT` لـ`_examQuestionsTableSql`؛ migration `if (oldVersion < 24) { ALTER TABLE exam_questions ADD COLUMN image_url TEXT }` (داخل try/catch زي البقية).

## Phase 2: Upload (عبر خدمة الـVPS — مش Firebase Storage)

- [x] T004 VPS `/opt/booking-upload/server.js`: endpoint `POST /api/upload/exam-image` (requireAuth + multer) — اسم ملف عشوائي (اختياريًا مسبوق بالـslug)، يتخزن تحت `/var/www/active-class.online/exam-photos/`، يرجّع `{ url }`. + `EXAM_DIR` + `mkdirSync`. **+ systemd unit `booking-upload.service`** (الخدمة كانت واقعة، مفيش auto-start).
- [x] T005 `lib/services/booking_service.dart`: `Future<String?> uploadExamImage(List<int> bytes, {String slug})` — `dio` multipart لـ`/api/upload/exam-image` بهيدر `x-upload-secret`. `storage.rules`: شيل بلوك `exam_images/` (مش محتاجينه).
- [x] T006 `lib/controllers/exam_controller.dart`: `uploadQuestionImage(int examId, List<int> bytes)` wrapper — يجيب slug، ينده `BookingService().uploadExamImage`. `online_exam_service.dart`: شيل كود Firebase Storage.

## Phase 3: Editor UI

- [x] T007 `online_exam_editor_page.dart` `_QDraft`: `String? imageUrl` + `bool uploadingImage`؛ `toModel` يمرّر `imageUrl`؛ `_loadQuestions` يقرأه.
- [x] T008 `online_exam_editor_page.dart` `_questionCard`: تحت نص السؤال — لو `imageUrl == null`: زر "إضافة صورة" (`ImagePicker().pickImage(source: gallery, imageQuality: 70, maxWidth: 1600)` → `_ec.uploadQuestionImage` → `setState`)؛ لو موجود: `Image.network` مصغّرة (ارتفاع ~120) + زر حذف (`setState(() => q.imageUrl = null)`). أثناء الرفع: مؤشّر.

## Phase 4: Student page

- [x] T009 `booking_site/exam/index.html`: في حلقة عرض الأسئلة (~526)، بعد `.q-head` لو `q.v.imageUrl` → `<img class="q-img" src="${q.v.imageUrl}" alt="" loading="lazy">`. + CSS `.q-img{display:block;max-width:100%;height:auto;border-radius:10px;margin:8px 0;border:1px solid var(...)}`.

## Phase 5: Polish

- [x] T010 `flutter analyze` صفر أخطاء/تحذيرات.
- [ ] T011 تحقّق يدوي: نشر امتحان بسؤال له صورة، فتحه من موبايل، تأكد الصورة تظهر responsive وامتحان قديم ما اتأثرش.
- [x] T012 تحديث ملاحظات الجلسة. نشر `booking_site/exam/index.html` على VPS (اتعمل). **يدوي من المستخدم**: رفع `server.js` + `booking-upload.service`، `systemctl enable --now booking-upload`.
- [x] T013 `plan.md` + `spec.md` FR-008/009: تعديل من Firebase Storage لخدمة الـVPS.
