# mobile_scanner (ML Kit barcode scanning) بيشاور اختيارياً على متعرفات
# لغات/موديلات مش موجودة كـ dependency فعلي — R8 بيبلّغ عنها كـ
# "missing classes" لأنها مش موجودة أصلاً في classpath. مش مشكلة حقيقية.
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.barcode.**
