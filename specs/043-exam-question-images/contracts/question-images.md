# Contract: منطق صرف لصور الأسئلة (`lib/widgets/image_crop_picker.dart` + مواءمة الاختيارات)

بلا DB ولا GetX — قابل للاختبار المباشر (`test/exam_question_images_test.dart`) فيما عدا دالة القص نفسها (UI، تتحقّق يدويًا).

## اختيار + قص (UI، لا اختبار وحدة)
```dart
/// null لو المستخدم ألغى أي خطوة (اختيار أو قص). لا يرفع الصورة —
/// الاستدعاء مسؤول عن الرفع بعد الاستلام (زي uploadQuestionImage الحالية).
Future<Uint8List?> pickAndCropImage(BuildContext context);
```

## مواءمة قائمة صور الاختيارات (صرفة، تُختبر)
```dart
/// تضمن طول [imageUrls] = طول [options] بالظبط — لسؤال قديم بلا عمود
/// محفوظ، أو بعد أي خلل تزامن. العناصر الزيادة تُقص، الناقصة تُكمَّل null.
List<String?> alignOptionImages(List<String?> imageUrls, int optionCount);

/// إضافة اختيار جديد — ترجّع قائمة جديدة بعنصر null في الآخر.
List<String?> addOptionImageSlot(List<String?> imageUrls);

/// حذف اختيار بالـindex k — ترجّع قائمة جديدة بدون العنصر رقم k.
List<String?> removeOptionImageSlot(List<String?> imageUrls, int k);
```

## قواعد
- `alignOptionImages`/`addOptionImageSlot`/`removeOptionImageSlot` لا تعدّل المدخل (immutable، ترجع قائمة جديدة).
- `pickAndCropImage` لا تضغط إضافي بعد القص غير إعداد الجودة المضمَّن في خطوة القص نفسها (راجع research.md §8).
