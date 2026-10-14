// lib/views/settings/settings_registry.dart
//
// spec 051 — سجل بيانات صرف لفئات الإعدادات وعناصرها: بيغذّي الشاشة
// الرئيسية والبحث، واختبار الجرد (test/settings_registry_test.dart) بيحرس إن
// ولا إعداد ضاع في إعادة التنظيم. مفيش أي منطق تخزين هنا ولا GetX.
import 'package:flutter/material.dart';

/// نوع عنصر الإعداد.
enum SettingsItemKind { switchTile, dropdown, nav, field, info }

/// شرط الظهور/التنفيذ الحالي في الكود.
enum SettingsVisibility {
  /// بتظهر دايمًا.
  always,

  /// للمساعد في وضع الفريق: قراءة فقط (بيانات المعلم).
  readOnlyForAssistant,

  /// التنفيذ يتطلب مالك الفريق (`requireTeamOwnerIfTeamMode`).
  ownerOnlyAction,

  /// بتظهر لو إضافة البوابة مفعّلة على الترخيص.
  portalAddonOnly,
}

class SettingsCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int order;
  const SettingsCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.order,
  });
}

class SettingsItem {
  final String id;
  final String categoryId;
  final String? section;
  final String title;
  final List<String> keywords;
  final SettingsItemKind kind;
  final SettingsVisibility visibility;

  /// لو العنصر بيظهر بس لما عنصر تاني يتفعّل (مدة التأخير تحت متأخر تلقائي).
  final String? parentId;
  const SettingsItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.kind,
    this.section,
    this.keywords = const [],
    this.visibility = SettingsVisibility.always,
    this.parentId,
  });
}

const List<SettingsCategory> kSettingsCategories = [
  SettingsCategory(
    id: 'account',
    title: 'الحساب والفريق',
    subtitle: 'بيانات المعلم، المساعدين والحسابات، متابعة أولياء الأمور',
    icon: Icons.account_circle_rounded,
    color: Color(0xFF4F46E5),
    order: 1,
  ),
  SettingsCategory(
    id: 'attendance',
    title: 'الحضور والحصص',
    subtitle: 'الواجب والتسميع والتفاعل، الغياب التلقائي، ماسح QR',
    icon: Icons.fact_check_rounded,
    color: Color(0xFF3B82F6),
    order: 2,
  ),
  SettingsCategory(
    id: 'billing',
    title: 'الفلوس والتحصيل',
    subtitle: 'العملة، مهلة السماح، يوم نزول المديونية، تأخّر الدفع',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF10B981),
    order: 3,
  ),
  SettingsCategory(
    id: 'whatsapp',
    title: 'الواتساب والتقارير',
    subtitle: 'رمز الدولة، تقارير الشهر، زر الواتساب في المجموعات',
    icon: Icons.chat_rounded,
    color: Color(0xFF25D366),
    order: 4,
  ),
  SettingsCategory(
    id: 'followup',
    title: 'المتابعة والتنبيهات',
    subtitle: 'طلاب محتاجين متابعة، مركز الإشعارات',
    icon: Icons.notifications_active_rounded,
    color: Color(0xFFEF4444),
    order: 5,
  ),
  SettingsCategory(
    id: 'appearance',
    title: 'المظهر والعرض',
    subtitle: 'الوضع الليلي، نظام الساعة',
    icon: Icons.palette_rounded,
    color: Color(0xFF8B5CF6),
    order: 6,
  ),
  SettingsCategory(
    id: 'data',
    title: 'البيانات والنسخ الاحتياطي',
    subtitle: 'الحفظ التلقائي، النسخ والاستعادة، حذف البيانات',
    icon: Icons.storage_rounded,
    color: Color(0xFF0EA5E9),
    order: 7,
  ),
  SettingsCategory(
    id: 'about',
    title: 'حول التطبيق والدعم',
    subtitle: 'الإصدار، التحديثات، الدعم، الخصوصية',
    icon: Icons.info_rounded,
    color: Color(0xFF64748B),
    order: 8,
  ),
];

const _sheet = 'ورقة الحضور';
const _qr = 'ماسح QR';
const _danger = 'منطقة الخطر';

/// الجرد الكامل للعناصر (راجع specs/051-settings-reorganize/contracts).
const List<SettingsItem> kSettingsItems = [
  // ── الحساب والفريق ──
  SettingsItem(
      id: 'account.teacher_name',
      categoryId: 'account',
      title: 'اسم المعلم',
      kind: SettingsItemKind.field,
      visibility: SettingsVisibility.readOnlyForAssistant,
      keywords: ['بيانات المعلم', 'اسم']),
  SettingsItem(
      id: 'account.teacher_gender',
      categoryId: 'account',
      title: 'مستر / مس',
      kind: SettingsItemKind.field,
      visibility: SettingsVisibility.readOnlyForAssistant,
      keywords: ['لقب', 'جنس']),
  SettingsItem(
      id: 'account.teacher_specialty',
      categoryId: 'account',
      title: 'التخصص',
      kind: SettingsItemKind.field,
      visibility: SettingsVisibility.readOnlyForAssistant,
      keywords: ['مادة']),
  SettingsItem(
      id: 'account.team_accounts',
      categoryId: 'account',
      title: 'المساعدين والحسابات',
      kind: SettingsItemKind.nav,
      keywords: ['وضع الفريق', 'مساعد', 'تسجيل الدخول', 'حساب']),
  SettingsItem(
      id: 'account.parent_portal',
      categoryId: 'account',
      title: 'متابعة أولياء الأمور',
      kind: SettingsItemKind.info,
      visibility: SettingsVisibility.portalAddonOnly,
      keywords: ['بوابة', 'رابط', 'كود', 'الدخول بالكود']),

  // ── الحضور والحصص ──
  SettingsItem(
      id: 'attendance.overdue_warning',
      categoryId: 'attendance',
      section: _sheet,
      title: 'تنبيه المتأخر في شاشة الحضور',
      kind: SettingsItemKind.switchTile,
      keywords: ['متأخر في الدفع', 'تحذير']),
  SettingsItem(
      id: 'attendance.show_homework',
      categoryId: 'attendance',
      section: _sheet,
      title: 'الواجب في حضور اليوم',
      kind: SettingsItemKind.switchTile,
      keywords: ['واجب']),
  SettingsItem(
      id: 'attendance.show_recitation',
      categoryId: 'attendance',
      section: _sheet,
      title: 'درجة التسميع',
      kind: SettingsItemKind.switchTile,
      keywords: ['تسميع', 'حفظ', 'درجة']),
  SettingsItem(
      id: 'attendance.recitation_max',
      categoryId: 'attendance',
      section: _sheet,
      title: 'الدرجة العظمى للتسميع',
      kind: SettingsItemKind.dropdown,
      parentId: 'attendance.show_recitation',
      keywords: ['تسميع', 'درجة', 'من كام']),
  SettingsItem(
      id: 'attendance.show_interaction',
      categoryId: 'attendance',
      section: _sheet,
      title: 'تفاعل الطالب',
      kind: SettingsItemKind.switchTile,
      keywords: ['تفاعل', 'ايموجي']),
  SettingsItem(
      id: 'attendance.auto_absent',
      categoryId: 'attendance',
      section: _sheet,
      title: 'تسجيل الغياب تلقائيًا بعد انتهاء الحصة',
      kind: SettingsItemKind.switchTile,
      keywords: ['غياب تلقائي', 'غائب']),
  SettingsItem(
      id: 'attendance.auto_absent_grace',
      categoryId: 'attendance',
      section: _sheet,
      title: 'مهلة بعد نهاية الحصة',
      kind: SettingsItemKind.dropdown,
      parentId: 'attendance.auto_absent',
      keywords: ['غياب تلقائي', 'مهلة']),
  SettingsItem(
      id: 'attendance.hide_qr_attendance',
      categoryId: 'attendance',
      section: _qr,
      title: 'إخفاء ماسح QR في الحضور',
      kind: SettingsItemKind.switchTile,
      keywords: ['qr', 'كيو ار', 'ماسح']),
  SettingsItem(
      id: 'attendance.hide_qr_payment',
      categoryId: 'attendance',
      section: _qr,
      title: 'إخفاء ماسح QR في الدفع',
      kind: SettingsItemKind.switchTile,
      keywords: ['qr', 'كيو ار', 'ماسح']),
  SettingsItem(
      id: 'attendance.hardware_scanner',
      categoryId: 'attendance',
      section: _qr,
      title: 'قارئ باركود خارجي',
      kind: SettingsItemKind.switchTile,
      keywords: ['باركود', 'سكانر', 'قارئ']),
  SettingsItem(
      id: 'attendance.qr_auto_late',
      categoryId: 'attendance',
      section: _qr,
      title: 'تسجيل "متأخر" تلقائيًا عبر QR',
      kind: SettingsItemKind.switchTile,
      keywords: ['متأخر', 'qr']),
  SettingsItem(
      id: 'attendance.late_grace',
      categoryId: 'attendance',
      section: _qr,
      title: 'مهلة التأخير (دقائق)',
      kind: SettingsItemKind.dropdown,
      parentId: 'attendance.qr_auto_late',
      keywords: ['متأخر', 'مهلة']),

  // ── الفلوس والتحصيل ──
  SettingsItem(
      id: 'billing.currency',
      categoryId: 'billing',
      title: 'العملة',
      kind: SettingsItemKind.dropdown,
      keywords: ['جنيه', 'ريال', 'دولار']),
  SettingsItem(
      id: 'billing.grace_days',
      categoryId: 'billing',
      title: 'مهلة السماح قبل "متأخر"',
      kind: SettingsItemKind.dropdown,
      keywords: ['متأخر', 'سماح', 'مديونية']),
  SettingsItem(
      id: 'billing.arrears',
      categoryId: 'billing',
      title: 'تحصيل مؤخّر (بالمنقضي)',
      kind: SettingsItemKind.switchTile,
      keywords: ['مؤخر', 'مقدم', 'نظام التحصيل']),
  SettingsItem(
      id: 'billing.billing_day',
      categoryId: 'billing',
      title: 'يوم نزول المديونية',
      kind: SettingsItemKind.dropdown,
      keywords: ['يوم النزول', 'مديونية', 'اشتراك']),
  SettingsItem(
      id: 'billing.prorate',
      categoryId: 'billing',
      title: 'حساب نسبي للشهر الأول',
      kind: SettingsItemKind.switchTile,
      keywords: ['نسبي', 'الشهر الأول']),
  SettingsItem(
      id: 'billing.at_risk_payment',
      categoryId: 'billing',
      title: 'تأخّر الدفع',
      kind: SettingsItemKind.switchTile,
      keywords: ['متأخر', 'محتاجين متابعة', 'دفع']),

  // ── الواتساب والتقارير ──
  SettingsItem(
      id: 'whatsapp.country_dial',
      categoryId: 'whatsapp',
      title: 'رمز دولة الواتساب',
      kind: SettingsItemKind.dropdown,
      keywords: ['رمز الدولة', 'كود الدولة', '+20']),
  SettingsItem(
      id: 'whatsapp.send_monthly',
      categoryId: 'whatsapp',
      title: 'إرسال تقارير الشهر',
      kind: SettingsItemKind.nav,
      keywords: ['تقرير', 'ولي الأمر', 'جماعي']),
  SettingsItem(
      id: 'whatsapp.group_button',
      categoryId: 'whatsapp',
      title: 'زر الواتساب في المجموعات',
      kind: SettingsItemKind.switchTile,
      keywords: ['زر', 'مجموعات']),
  SettingsItem(
      id: 'whatsapp.send_day',
      categoryId: 'whatsapp',
      title: 'يوم ظهور الزر',
      kind: SettingsItemKind.dropdown,
      parentId: 'whatsapp.group_button',
      keywords: ['يوم', 'زر']),
  SettingsItem(
      id: 'whatsapp.report_on_completion',
      categoryId: 'whatsapp',
      title: 'تقرير واتساب بعد اكتمال الحضور',
      kind: SettingsItemKind.switchTile,
      keywords: ['تقرير', 'بعد الحضور']),

  // ── المتابعة والتنبيهات ──
  SettingsItem(
      id: 'followup.absence',
      categoryId: 'followup',
      title: 'غياب متتالي',
      kind: SettingsItemKind.switchTile,
      keywords: ['غياب', 'محتاجين متابعة', 'إنذار']),
  SettingsItem(
      id: 'followup.absence_threshold',
      categoryId: 'followup',
      title: 'عدد حصص الغياب المتتالي',
      kind: SettingsItemKind.dropdown,
      keywords: ['غياب', 'حصص']),
  SettingsItem(
      id: 'followup.homework',
      categoryId: 'followup',
      title: 'واجب ناقص متكرر',
      kind: SettingsItemKind.switchTile,
      keywords: ['واجب', 'محتاجين متابعة']),
  SettingsItem(
      id: 'followup.homework_m',
      categoryId: 'followup',
      title: 'عدد مرات الواجب الناقص',
      kind: SettingsItemKind.dropdown,
      keywords: ['واجب']),
  SettingsItem(
      id: 'followup.homework_w',
      categoryId: 'followup',
      title: 'من آخر كام حصة',
      kind: SettingsItemKind.dropdown,
      keywords: ['واجب', 'حصص']),
  SettingsItem(
      id: 'followup.grade',
      categoryId: 'followup',
      title: 'هبوط الدرجات',
      kind: SettingsItemKind.switchTile,
      keywords: ['درجات', 'امتحان', 'محتاجين متابعة']),
  SettingsItem(
      id: 'followup.grade_drop',
      categoryId: 'followup',
      title: 'مقدار هبوط الدرجة',
      kind: SettingsItemKind.dropdown,
      keywords: ['درجات']),
  SettingsItem(
      id: 'followup.cooldown',
      categoryId: 'followup',
      title: 'مدة التهدئة بعد "تمّت المتابعة"',
      kind: SettingsItemKind.dropdown,
      keywords: ['تهدئة', 'متابعة']),
  SettingsItem(
      id: 'followup.notifications',
      categoryId: 'followup',
      title: 'مركز الإشعارات',
      kind: SettingsItemKind.nav,
      keywords: ['إشعارات', 'تنبيهات', 'ميلاد']),

  // ── المظهر والعرض ──
  SettingsItem(
      id: 'appearance.dark_mode',
      categoryId: 'appearance',
      title: 'الوضع الليلي',
      kind: SettingsItemKind.switchTile,
      keywords: ['dark', 'ليلي', 'مظهر']),
  SettingsItem(
      id: 'appearance.use_24h',
      categoryId: 'appearance',
      title: 'نظام الساعة 24',
      kind: SettingsItemKind.switchTile,
      keywords: ['ساعة', 'وقت', 'توقيت']),

  // ── البيانات والنسخ الاحتياطي ──
  SettingsItem(
      id: 'data.auto_backup',
      categoryId: 'data',
      title: 'الحفظ التلقائي',
      kind: SettingsItemKind.switchTile,
      keywords: ['نسخة', 'باك اب', 'نسخ احتياطي']),
  SettingsItem(
      id: 'data.create_backup',
      categoryId: 'data',
      title: 'إنشاء نسخة احتياطية',
      kind: SettingsItemKind.nav,
      keywords: ['نسخة', 'باك اب']),
  SettingsItem(
      id: 'data.restore_backup',
      categoryId: 'data',
      title: 'استعادة نسخة احتياطية',
      kind: SettingsItemKind.nav,
      visibility: SettingsVisibility.ownerOnlyAction,
      keywords: ['استعادة', 'رجوع']),
  SettingsItem(
      id: 'data.manage_backups',
      categoryId: 'data',
      title: 'إدارة النسخ الاحتياطية',
      kind: SettingsItemKind.nav,
      keywords: ['حذف نسخ', 'قديمة']),
  SettingsItem(
      id: 'data.cloud_backup',
      categoryId: 'data',
      title: 'النسخ السحابي (Google Drive)',
      kind: SettingsItemKind.nav,
      keywords: ['درايف', 'جوجل', 'سحابي']),
  SettingsItem(
      id: 'data.delete_range',
      categoryId: 'data',
      section: _danger,
      title: 'حذف سجلّات بمدى تواريخ',
      kind: SettingsItemKind.nav,
      keywords: ['حذف', 'مسح', 'سجلات']),
  SettingsItem(
      id: 'data.delete_all',
      categoryId: 'data',
      section: _danger,
      title: 'حذف جميع البيانات',
      kind: SettingsItemKind.nav,
      visibility: SettingsVisibility.ownerOnlyAction,
      keywords: ['حذف', 'مسح', 'تصفير']),

  // ── حول التطبيق والدعم ──
  SettingsItem(
      id: 'about.version',
      categoryId: 'about',
      title: 'الإصدار',
      kind: SettingsItemKind.info,
      keywords: ['نسخة التطبيق']),
  SettingsItem(
      id: 'about.check_update',
      categoryId: 'about',
      title: 'تحقق من التحديثات',
      kind: SettingsItemKind.nav,
      keywords: ['تحديث']),
  SettingsItem(
      id: 'about.support',
      categoryId: 'about',
      title: 'تواصل معنا',
      kind: SettingsItemKind.nav,
      keywords: ['دعم', 'مساعدة', 'واتساب']),
  SettingsItem(
      id: 'about.privacy',
      categoryId: 'about',
      title: 'سياسة الخصوصية',
      kind: SettingsItemKind.nav,
      keywords: ['خصوصية', 'بيانات']),
  SettingsItem(
      id: 'about.community',
      categoryId: 'about',
      title: 'انضم لقناة التحديثات والدعم',
      kind: SettingsItemKind.nav,
      keywords: ['قناة', 'مجتمع', 'تيليجرام']),
];

/// عناصر فئة بعينها بترتيب السجل.
List<SettingsItem> itemsOfCategory(String categoryId) =>
    kSettingsItems.where((i) => i.categoryId == categoryId).toList();

/// تطبيع عربي للبحث: يشيل التشكيل والتطويل، يوحّد الألف والياء والتاء
/// المربوطة، ويحوّل الأرقام الهندية للاتينية.
String normalizeArabic(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    switch (r) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        b.writeCharCode(0x0627);
        break;
      case 0x0649: // ى
        b.writeCharCode(0x064A);
        break;
      case 0x0629: // ة
        b.writeCharCode(0x0647);
        break;
      default:
        if (r >= 0x0660 && r <= 0x0669) {
          b.writeCharCode(0x30 + (r - 0x0660));
        } else {
          b.writeCharCode(r);
        }
    }
  }
  return b.toString().toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// بحث في الإعدادات: كل كلمة في الاستعلام لازم تتلاقى في العنوان أو الكلمات
/// المفتاحية أو اسم الفئة. الحد الأدنى حرفين. النتايج مرتّبة (مطابقة العنوان
/// الأول). عناصر "إضافة البوابة" بتتخفّى لو الإضافة مش مفعّلة.
List<SettingsItem> searchSettings(
  String query, {
  required bool isAssistant,
  required bool portalEnabled,
}) {
  final q = normalizeArabic(query);
  if (q.length < 2) return const [];
  final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();
  final catTitle = {
    for (final c in kSettingsCategories) c.id: normalizeArabic(c.title)
  };
  final scored = <MapEntry<SettingsItem, int>>[];
  for (final i in kSettingsItems) {
    if (i.visibility == SettingsVisibility.portalAddonOnly && !portalEnabled) {
      continue;
    }
    final title = normalizeArabic(i.title);
    final kws = i.keywords.map(normalizeArabic).toList();
    final hay = [title, catTitle[i.categoryId] ?? '', ...kws];
    final ok = tokens.every((t) => hay.any((h) => h.contains(t)));
    if (!ok) continue;
    var score = 3;
    if (title.startsWith(q)) {
      score = 0;
    } else if (title.contains(q)) {
      score = 1;
    } else if (kws.any((k) => k.contains(q))) {
      score = 2;
    }
    scored.add(MapEntry(i, score));
  }
  scored.sort((a, b) => a.value.compareTo(b.value));
  return scored.map((e) => e.key).toList();
}
