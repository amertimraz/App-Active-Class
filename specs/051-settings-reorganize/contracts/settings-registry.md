# Contract: جرد الإعدادات وخريطة النقل

الجرد من `settings_page.dart` (2026-10-13). **العمود "المصدر"** = السطر الحالي. الشرط = قاعدة ظهور/قفل موجودة فعلًا ولازم تتنقل مع العنصر. أسماء الحقول من `SettingsController` (مفاتيح التخزين ما بتتغيرش).

## الشاشة الرئيسية (Home)

| العنصر | المصدر | ملاحظة |
|---|---|---|
| بطاقة الترخيص `LicenseStatusTile` | 86 | تفضل مضغوطة في أول القائمة |
| صف بحث | جديد (P3) | يظهر فوق الفئات |
| قائمة 8 فئات (أدناه) | جديد | كل فئة: أيقونة + اسم + وصف |

## 1) الحساب والفريق — `account`

| العنصر | النوع | المصدر | الشرط |
|---|---|---|---|
| اسم المعلم | field | 1328 | للمساعد: قراءة فقط (رسالة قفل 1229) |
| الجنس (مستر/مس) | field | 1343/1357 | نفس القفل |
| التخصص | field | 1379 | نفس القفل |
| صورة المعلم | field | 1275 | نفس القفل |
| المساعدين والحسابات | nav | 104 | بيتغيّر subtitle حسب `auth.isLoggedIn` |
| متابعة أولياء الأمور (`_ParentPortalTile`) | info/نشر | 140–153 | يظهر لو `lic.parentPortalEnabled`؛ لونه أحمر لو `!parentPortalActiveNow` |

## 2) الحضور والحصص — `attendance`

القسم الفرعي **ورقة الحضور**:

| العنصر | النوع | الحقل | المصدر | الشرط |
|---|---|---|---|---|
| تنبيه المتأخر في شاشة الحضور | switch | `attendanceOverdueWarning` | 730 | — |
| الواجب في حضور اليوم | switch | `showHomework` | 788 | — |
| درجة التسميع | switch | `showRecitation` | 802 | — |
| الدرجة العظمى للتسميع | dropdown | `recitationMax` | 819 | يظهر لو `showRecitation` |
| تفاعل الطالب | switch | `showInteraction` | 846 | — |
| تسجيل الغياب تلقائيًا بعد انتهاء الحصة | switch | `autoAbsentEnabled` | 861 | — |
| مهلة بعد نهاية الحصة | dropdown | `autoAbsentGraceMinutes` | 877 | يظهر لو `autoAbsentEnabled` |

القسم الفرعي **ماسح QR**:

| العنصر | النوع | الحقل | المصدر | الشرط |
|---|---|---|---|---|
| إخفاء ماسح QR في الحضور | switch | `hideQrInAttendance` | 697 | — |
| إخفاء ماسح QR في الدفع | switch | `hideQrInPayment` | 683 | — |
| قارئ باركود خارجي | switch | `hardwareScannerEnabled` | 712 | — |
| تسجيل "متأخر" تلقائيًا عبر QR | switch | `qrAutoLateEnabled` | 745 | — |
| مهلة التأخير (دقائق) | dropdown | `lateGraceMinutes` | 761 | يظهر لو `qrAutoLateEnabled` |

## 3) الفلوس والتحصيل — `billing`

| العنصر | النوع | الحقل | المصدر | الشرط |
|---|---|---|---|---|
| العملة | dropdown | `currencyCode` | 167 | — |
| مهلة السماح قبل "متأخر" | dropdown | `paymentGraceDays` | 234 | — |
| تحصيل مؤخّر (بالمنقضي) | switch | `billingArrears` | 263 | — |
| يوم نزول المديونية | dropdown | `billingDay` | 296 | معطّل مع المؤخّر؛ وضع الفريق (329) |
| حساب نسبي للشهر الأول | switch | `prorateFirstMonth` | 346 | — |
| تأخّر الدفع (قائمة المتابعة) | switch | `atRiskPaymentEnabled` | 487 | **منقول** من "طلاب محتاجين متابعة" |

## 4) الواتساب والتقارير — `whatsapp`

| العنصر | النوع | الحقل | المصدر | الشرط |
|---|---|---|---|---|
| رمز دولة الواتساب | dropdown | `countryDial` | 195 | **منقول** من قسم العملة |
| إرسال تقارير الشهر | nav | — | 587 | يستخدم `sendMonthlyReportsViaWhatsAppAuto` |
| زر الواتساب في المجموعات | switch | `whatsappEnabled` | 607 | — |
| يوم ظهور الزر | dropdown | `whatsappSendDay` | 629 | يظهر لو `whatsappEnabled` |
| تقرير واتساب بعد اكتمال الحضور | switch | `reportOnCompletionEnabled` | 656 | — |

## 5) المتابعة والتنبيهات — `followup`

| العنصر | النوع | الحقل | المصدر | الشرط |
|---|---|---|---|---|
| غياب متتالي | switch | `atRiskAbsenceEnabled` | 380 | — |
| عدد حصص الغياب المتتالي | dropdown | `atRiskAbsenceThreshold` | 392 | — |
| واجب ناقص متكرر | switch | `atRiskHomeworkEnabled` | 410 | — |
| عدد مرات الواجب الناقص | dropdown | `atRiskHomeworkM` | 422 | — |
| من آخر كام حصة | dropdown | `atRiskHomeworkW` | 439 | — |
| هبوط الدرجات | switch | `atRiskGradeEnabled` | 457 | — |
| مقدار هبوط الدرجة | dropdown | `atRiskGradeDropPoints` | 469 | — |
| مدة التهدئة بعد "تمّت المتابعة" | dropdown | `atRiskCooldownDays` | 498 | — |
| مركز الإشعارات | nav | — | 563 | يفتح `NotificationSettingsPage` |
| سطر "تأخّر الدفع من الفلوس والتحصيل" | nav (جديد) | — | — | يفتح فئة الفلوس مع تمييز |

## 6) المظهر والعرض — `appearance`

| العنصر | النوع | الحقل | المصدر |
|---|---|---|---|
| الوضع الليلي | switch | `themeController` | 527 |
| نظام الساعة 24 | switch | `use24hFormat` | 538 |

## 7) البيانات والنسخ الاحتياطي — `data`

| العنصر | النوع | المصدر | الشرط |
|---|---|---|---|
| الحفظ التلقائي | switch | 920 | — |
| إنشاء نسخة احتياطية | nav | 938 | — |
| استعادة نسخة احتياطية | nav | 957 | `requireTeamOwnerIfTeamMode` |
| إدارة النسخ الاحتياطية | nav | 976 | — |
| النسخ السحابي (Google Drive) | nav | 987 | — |
| **منطقة الخطر**: حذف سجلّات بمدى تواريخ | nav | 999 | يفتح `DeleteRecordsPage` |
| **منطقة الخطر**: حذف جميع البيانات | nav | 1011 | `requireTeamOwnerIfTeamMode` |

## 8) حول التطبيق والدعم — `about`

| العنصر | النوع | المصدر |
|---|---|---|
| الإصدار | info | 1415 |
| تحقق من التحديثات | nav | 1426 |
| تواصل معنا (دعم واتساب) | nav | 1437 |
| سياسة الخصوصية | nav | 1446 |
| انضم لقناة التحديثات والدعم | nav | 1502 |

## الجرد المطلوب حراسته

| النوع | العدد | المصدر |
|---|---|---|
| switch | 20 | 9 حضور/QR + 3 فلوس + 3 متابعة + 2 واتساب + 2 مظهر + 1 بيانات |
| dropdown | 13 | 3 حضور + 3 فلوس + 5 متابعة + 2 واتساب |
| nav | 9 | المساعدين + مركز الإشعارات + تقارير الشهر + 6 بيانات |

## الواجهات الخارجية اللي لازم تفضل (Compatibility)

- `ROUTE_SETTINGS` + `const SettingsPage()` (من `main.dart` والـdrawer والـappbar في `home_page.dart`).
- `sendMonthlyReportsViaWhatsAppAuto(BuildContext)` (من `main.dart:107`).
- `NotificationSettingsPage`، `DeleteRecordsPage`، `BookingSettingsPage`، `AccountTeamScreen`: بتفضل مستقلة وبتتفتح من الفئة المناسبة.
