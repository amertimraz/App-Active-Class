# Contract — ترتيب شاشة الإعدادات + قسم المجتمع

الملف: `lib/views/settings/settings_page.dart` → `build()` → `ListView(children: [...])`.

## الترتيب النهائي (FR-001)

| # | القسم | المصدر | طي |
|---|---|---|---|
| 0 | `LicenseStatusTile` | كما هو | — |
| 1 | **بيانات المدرس والتخصص** | `_buildTeacherSection(...)` كما هو | مفتوح |
| 2 | **العملة ورمز دولة الواتساب** | القسم الحالي (~184) كما هو | مفتوح |
| 3 | **الفوترة والتحصيل** ← جديد | 3 بنود منقولة من "الواتساب": `paymentGraceDays` (مهلة "متأخر")، `billingArrears` (تحصيل مؤخّر)، `prorateFirstMonth` (حساب نسبي) — حرفيًا بالـ`Obx` والـcallbacks | مفتوح |
| 4 | **الواتساب والتقارير** | القسم الحالي "الواتساب" **بعد شيل الـ3 بنود** — يفضل: إرسال تقارير الشهر، زر الواتساب في المجموعات + يوم ظهوره، تقرير بعد اكتمال الحضور | مطويّ |
| 5 | **الإشعارات** | القسم الحالي (~252) كما هو | مطويّ |
| 6 | **ماسح QR** | القسم الحالي (~443) كما هو | مطويّ |
| 7 | **الإضافات المدفوعة** ← موسّع | `Obx` بوابة الأهالي (~107، بتاريخ الانتهاء من سبيك 016) + nav tile جديد "إعدادات الحجوزات" → `BookingSettingsPage` (يظهر لو `canBooking`) | مفتوح |
| 8 | **المظهر والتوقيت** | القسم الحالي (~148) كما هو | مطويّ |
| 9 | **المساعدين والحسابات** | القسم الحالي (~78، حساب + وضع الفريق) كما هو | مطويّ |
| 10 | **النسخ الاحتياطي** | القسم الحالي (~527) كما هو | مطويّ |
| 11 | **المجتمع والدعم** ← جديد | كارت + زر → `_openCommunityChannel()` | مفتوح |
| 12 | **عن التطبيق** | `_buildAboutSection` (~975): الإصدار، تحقّق من التحديثات، المساعدة والدعم، سياسة الخصوصية | مطويّ |

**فاصل موحّد بين الأقسام**: `const SizedBox(height: 14)`.

## قسم "المجتمع والدعم" (FR-008..012)

```
_buildSection(
  context, isDark,
  title: 'المجتمع والدعم',
  icon: Icons.forum_rounded،        // أو groups
  color: const Color(0xFF25D366),   // أخضر واتساب
  children: [
    Padding(  // شرح + زر
      padding: EdgeInsets.all(16),
      child: Column(
        نص: 'قناة التحديثات والدعم — تابع الجديد، وشارك مشاكلك واقتراحاتك مع مجتمع المدرسين.'
        SizedBox(height: 12)
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _openCommunityChannel,
          style: backgroundColor 0xFF25D366,
          icon: Icon(Icons.chat_rounded / whatsapp),
          label: 'انضم لقناة التحديثات والدعم',
        ))
      ),
    ),
  ],
)
```

## `_openCommunityChannel()`

```dart
static const _kCommunityChannelUrl =
    'https://whatsapp.com/channel/0029VbDFTCsEquiR7nSaO52X';

Future<void> _openCommunityChannel() async {
  try {
    await launchUrl(Uri.parse(_kCommunityChannelUrl),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذّر فتح القناة، حاول تاني');
  }
}
```

## ثوابت القبول

- كل `Obx`/شرط إظهار (`if (!settings.whatsappEnabled.value) return SizedBox.shrink()` إلخ) يُنقل **كما هو** مع البند.
- عدد الإعدادات القابلة للتفاعل قبل = بعد (+ زر القناة الجديد).
- `flutter analyze` صفر تحذيرات.
- الوضع الليلي: كل قسم يمرّ `isDark` للـ`_buildSection` (بيتكفّل بالألوان).
