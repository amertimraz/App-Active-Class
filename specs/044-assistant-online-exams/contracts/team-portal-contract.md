# Contract: توافر الامتحانات الإلكترونية في الفريق

## 1. دالة صرفة — `lib/utils/online_exam_access.dart` (بلا GetX/DB، تُختبر)
```dart
class OnlineExamAccess {
  final bool locked;    // التبويب مقفول (رسالة إضافة البوابة)
  final bool readOnly;  // يشوف بس بدون أي إجراء كتابي/نشر
  final bool canCreate; // زر "امتحان إلكتروني جديد" + النشر
}

OnlineExamAccess onlineExamAccess({
  required bool inTeam,          // وضع الفريق مفعّل
  required bool isOwner,
  required bool canManage,       // can_manage_online_exams للمساعد
  required bool ownPortalActive, // LicenseController.parentPortalActiveNow (للمالك/خارج الفريق)
  required bool teamPortalActive,// enabled && (expires==null || expires>now) من صف الفريق (للمساعد)
  required bool hasTeamSlug,     // portal_slug موجود
});
```
| الحالة | locked | readOnly | canCreate |
|---|---|---|---|
| خارج الفريق أو مالك، بوابة شغّالة | false | false | true |
| خارج الفريق أو مالك، بوابة مش شغّالة | true | — | false |
| مساعد، اشتراك المدرس مش شغّال | true | — | false |
| مساعد، اشتراك شغّال، بلا صلاحية | false | true | false |
| مساعد، اشتراك شغّال، صلاحية، بلا slug | false | true | false |
| مساعد، اشتراك شغّال، صلاحية + slug | false | false | true |

## 2. RPCs
```sql
set_team_portal(_team_id uuid, _slug text, _enabled boolean, _expires_at timestamptz) returns void
set_my_firebase_uid(_team_id uuid, _uid text) returns void
```

## 3. عقد Firestore Rules
```
function _oeOwner(slug) {
  let root = get(/databases/$(database)/documents/online_exams/$(slug)).data;
  return request.auth != null
    && (root.ownerUid == request.auth.uid
        || ('coOwnerUids' in root && request.auth.uid in root.coOwnerUids));
}
```
- المستند الجذر `online_exams/{slug}` والقواعد الأخرى: بدون تغيير.
- المساعد يكتب فقط تحت `exams/**` (نشر/إيقاف/إعادة جدولة/نتائج/حذف).

## 4. مدة التحديث
- المساعد: تحديث الصلاحية وحالة البوابة كل 30 ثانية + عند الرجوع للتطبيق.
- المدرس: مزامنة `coOwnerUids` عند الإقلاع + عند تغيير صلاحية + كل دقيقتين.
