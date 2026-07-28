# google_mlkit_text_recognition يشاور اختيارياً على متعرفات لغات (صيني/ياباني/كوري/هندي)
# مش موجودة كـ dependency فعلي (التطبيق بيستخدم التعرف اللاتيني بس) — R8 بيبلّغ عنها
# كـ "missing classes" لأنها غير موجودة أصلاً في classpath. مش مشكلة حقيقية.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
