# Implementation Plan: صور الأسئلة في الامتحان الإلكتروني

**Branch**: `019-exam-question-images` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

## Summary

حقل `imageUrl` واحد على `ExamQuestion` بيمشي من شاشة التأليف (رفع للـVPS) → DB (عمود جديد + migration v24) → payload النشر (`toCloudMap`) → صفحة الطالب (`<img>` فوق النص). صفر حزم جديدة، صفر قراءات Firestore زيادة، **صفر Firebase Storage** (خطة Spark) — نفس خدمة رفع صور المعلّم على الـVPS.

## Technical Context

- **Language**: Dart 3.5.4 / Flutter 3.38.1 + JS (صفحة الطالب).
- **Deps**: `image_picker: ^1.0.7`، `dio` (موجودان). لا جديد. مفيش `firebase_storage`.
- **رفع**: خدمة `/opt/booking-upload` على الـVPS (Node/Express/multer، بورت 8091 خلف Caddy `/api/upload/*`) — نضيف endpoint `exam-image` + systemd unit. التخزين `/var/www/active-class.online/exam-photos/`، القراءة عامة عبر Caddy.
- **DB**: `exam_questions` + `image_url TEXT`. `DATABASE_VERSION` 23 → **24**.
- **Testing**: `flutter analyze` صفر تحذيرات + تحقّق يدوي (نشر امتحان بصورة + فتحه من موبايل).

## Constitution Check

PASS — نفس نمط spec 016 (`OnlineExamService` + `toCloudMap` بدون مفاتيح إجابة) + نمط رفع `receipts/` الموجود في `LicenseController`.

## Source Changes

```text
lib/config/constants.dart              # + COL_EQ_IMAGE_URL = 'image_url'؛ DATABASE_VERSION 24
lib/models/exam_question_model.dart    # + imageUrl؛ toMap/fromMap/copyWith/toCloudMap
lib/services/database_service.dart     # migration oldVersion < 24 (ALTER TABLE) + _examQuestionsTableSql
lib/services/booking_service.dart      # + uploadExamImage(List<int> bytes, {slug}) → dio multipart للـVPS
lib/services/online_exam_service.dart  # (شيل كود Firebase Storage — تعليق فقط)
lib/controllers/exam_controller.dart   # + uploadQuestionImage wrapper → BookingService
lib/views/exams/online_exam_editor_page.dart  # _QDraft.imageUrl + زر/مصغّرة/حذف في _questionCard
storage.rules                          # (شيل بلوك exam_images — تعليق فقط)
booking_site/exam/index.html           # عرض <img class="q-img"> + CSS
/opt/booking-upload/server.js (VPS)    # + POST /api/upload/exam-image + EXAM_DIR
/etc/systemd/system/booking-upload.service (VPS)  # unit جديدة (auto-start)
```

**صفر migration جدول جديد** — عمود واحد فقط. `_examQuestionsTableSql` (لتثبيتات جديدة) يكسب العمود كمان.
