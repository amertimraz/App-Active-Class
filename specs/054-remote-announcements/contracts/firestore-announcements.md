# Contract: Firestore `announcements`

## قاعدة الأمان (تُضاف في `firestore.rules` للمشروعين وتُنشر مرة واحدة)

```
// إعلانات التسويق (خصومات/عروض) — يقرأها أي تطبيق، ويكتبها الأدمن فقط
match /announcements/{id} {
  allow read: if true;
  allow write: if isAdmin();
}
```

## قراءة التطبيق (المقدمة)

`collection('announcements').where('status', isEqualTo: 'published').limit(20)` ثم تصفية وترتيب على العميل.

## قراءة REST (الخلفية، بلا مصادقة)

```
GET https://firestore.googleapis.com/v1/projects/active-class-72e0f/databases/(default)/documents/announcements?pageSize=20
```

الرد: `{documents:[{name:".../announcements/<id>", fields:{...}, updateTime:"..."}], nextPageToken?}`. أنواع القيم المطبوعة: `stringValue`, `integerValue`(نص), `doubleValue`, `booleanValue`, `timestampValue`, `nullValue`, `arrayValue.values[]`, `mapValue.fields{}`. المعرّف = آخر جزء من `name`. التصفية بـ`status` تتم على العميل (لا استعلام structured هنا).

## كتابة الأدمن

`set(merge)` على `announcements/{id}` مع `updatedAt: FieldValue.serverTimestamp()`؛ أول نشر يضبط `publishedAt` (ولا يتغيّر بعد ذلك إلا بإعادة نشر صريحة). الحذف نهائي (`delete`).

## توافق الإصدارات

حقول جديدة لاحقًا يجب أن تكون اختيارية؛ التطبيق يتجاهل أي حقل/قيمة غير معروفة ويستخدم الافتراضيات (انظر data-model).
