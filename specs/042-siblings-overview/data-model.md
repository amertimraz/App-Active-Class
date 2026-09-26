# Phase 1 Data Model: شاشة الإخوة

**لا تغيير في SQLite ولا Supabase.** كل الكيانات مشتقة في الذاكرة.

## SiblingMember (بطاقة أخ)
| الحقل | المصدر |
|---|---|
| `student` | `Student` (نشط) |
| `group` | `Group?` من `groupId` |
| `totalDue` | `PricingHelper.totalDueThrough` (شهر الآن) |
| `paid` | Σ دفعات الطالب بدون `kDebtWriteOffNote` |
| `remaining` | `PricingHelper.accumulatedDebt` (بكل الدفعات) |
| `monthPresent`, `monthAbsent` | حضور الشهر الجاري |
| `monthRate` | `present/(present+absent)` أو null لو لا سجلات |

## SiblingFamily
| الحقل | التعريف |
|---|---|
| `key` | `siblingGroupId` |
| `members` | 2–3 أعضاء نشطين (مرتّبين بالاسم) |
| `sharedTotal` | `siblingsTotal` (أول عضو غير null) — الإجمالي المشترك الشهري |
| `totalPaid` | Σ `paid` |
| `totalRemaining` | Σ `remaining` |
| `phones` | أرقام مطبَّعة بدون تكرار (من `guardianWhatsapp`/`guardianPhone`) |
| `hasBalance` | `totalRemaining > 0` |

## قواعد
- عيلة بأقل من عضوين نشطين لا تُنشأ.
- المتبقي/المستحق يحترمان الإعفاء/الحصة/الأشهر المؤجلة لأنها من `PricingHelper`.
- إسقاط المديونية: يخفض `remaining` ولا يدخل في `paid`.
