# Data Model: إعلانات وبنر الخصومات عن بعد

> Firestore فقط (مجموعة `announcements`). لا تغيير في SQLite ولا في مزامنة الفريق.

## Announcement (مستند Firestore `announcements/{id}`)

| الحقل | النوع | ملاحظات |
|---|---|---|
| `title` | string | مطلوب، ≤ 60 حرف |
| `body` | string | مطلوب، ≤ 240 حرف، نص عادي |
| `kind` | string | `deal` \| `warn` \| `news` — مجهول → `news` |
| `badge` | string? | شارة قصيرة ≤ 12 حرف (مثل `-30%`) |
| `design` | string | `classic` \| `poster` \| `glass` \| `strip` \| `coupon` \| `minimal` — مجهول → `classic` |
| `color` | string | `purple` \| `teal` \| `coral` \| `pink` \| `blue` \| `green` \| `amber` \| `red` — مجهول → `purple` |
| `couponCode` | string? | لتصميم `coupon` فقط، ≤ 16 حرف |
| `showCountdown` | bool | يُهمل لو لا `endsAt` |
| `status` | string | `draft` \| `published` — لا يقرأ التطبيق إلا `published` |
| `startsAt` | timestamp? | null = من الآن |
| `endsAt` | timestamp? | null = بلا نهاية |
| `placements` | map | `{home, plans, popup, notify}` أعلام bool (الافتراضي false) |
| `audience` | array<string> | قيم من `trial/basic/pro/lifetime`؛ فاضية = الكل |
| `cta` | map? | `{type: whatsapp\|link\|plans\|none, label, phone?, message?, url?}` |
| `publishedAt` | timestamp | وقت أول نشر (الترتيب: الأحدث أولًا) |
| `updatedAt` | timestamp | server timestamp مع كل حفظ → يُشتق منه `version` |
| `createdAt` | timestamp | |

**الإصدار (version)** = `updatedAt` بالمللي ثانية. مفتاح العرض لمرة واحدة = `"$id:$version"`.

**قواعد التحقق (الأدمن + العميل دفاعيًا):**
- `title`, `body` غير فاضيين؛ طولان ضمن الحدود.
- `endsAt > startsAt` لو الاتنين موجودين.
- `cta.type == whatsapp` → `phone` (أرقام فقط 8–15)، `label` مطلوب؛ `message` اختياري.
- `cta.type == link` → `url` يبدأ بـ`http://` أو `https://`.
- `showCountdown` بدون `endsAt` → تحذير في الأدمن، ويُهمَل في التطبيق.
- `placements` كلها false → مسموح كمسودة، تحذير عند النشر.

## الحالة المشتقة (لا تُخزَّن؛ تُحسب في القائمة)

| الحالة | الشرط |
|---|---|
| مسودة | `status == draft` |
| مجدول | `published` و`startsAt > now` |
| فعّال | `published` و`startsAt <= now < endsAt` (أو بلا نهاية) |
| منتهٍ | `published` و`endsAt <= now` |

## الاختيار في التطبيق (دالة صرفة)

`pickAnnouncement(items, now, planKey, placement)`:
1. تصفية: `status=published`، فعّال الآن، `placement` مفعّل، `audience` فاضية أو تحوي `planKey`.
2. الترتيب بـ`publishedAt` تنازليًا؛ الأول يُعرض.
3. لا نتيجة → لا شيء.

## حالة محلية (SharedPreferences، لكل جهاز)

| المفتاح | المحتوى |
|---|---|
| `ann_cache` | JSON لآخر قائمة إعلانات (للأوفلاين والخلفية) |
| `ann_dismiss_home` / `ann_dismiss_plans` | مفتاح العرض (`id:version`) الأخير المُغلَق |
| `ann_popup_seen` | مفتاح آخر نافذة عُرضت |
| `ann_notified` | مفتاح آخر إشعار أُرسل |
| `ann_plan` | مفتاح باقة العميل الحالية (يكتبه `LicenseController`، تقرؤه المهمة الخلفية) |

## رسالة واتساب

`message` (من الأدمن) + سطر فارغ + `الاسم: <teacherFullName>` + `الكود: <licenseCode>` + `الباقة: <nameAr>`؛ الأسطر الفارغة تُحذف.
