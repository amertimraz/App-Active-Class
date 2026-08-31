# mobile_scanner (ML Kit barcode scanning) بيشاور اختيارياً على متعرفات
# لغات/موديلات مش موجودة كـ dependency فعلي — R8 بيبلّغ عنها كـ
# "missing classes" لأنها مش موجودة أصلاً في classpath. مش مشكلة حقيقية.
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.barcode.**

# media_store_plus بيسرّح SaveInfo/DocumentTreeInfo لـ JSON بمكتبة Gson
# (بتعتمد على reflection لقراءة أسماء الحقول)، وبيبعت الـ JSON ده لجانب
# دارت اللي بيقرأ نفس أسماء الحقول حرفيًا (uri، name، saveStatus...).
# من غير القاعدة دي، R8 بيغيّر أسماء الحقول في نسخة الـ release،
# فيتشوّه الـ JSON وتفشل عملية القراءة على جانب دارت بصمت — وده كان
# سبب فشل "الحفظ في التنزيلات + المشاركة" في الـ release بس، مع إنها
# شغالة تمام في نسخة الـ debug.
-keep class com.snnafi.media_store_plus.** { *; }

# flutter_local_notifications بيخزّن/يقرأ الإشعارات المجدولة كـ JSON عن
# طريق Gson TypeToken<ArrayList<...>>. R8 بيمسح التواقيع العامة (generic
# signatures) فيرمي "TypeToken must be created with a type argument"
# وقت loadScheduledNotifications (داخل cancelAll/syncAll) — في الـrelease
# بس. القواعد دي من README الخاص بالمكتبة + Gson.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
