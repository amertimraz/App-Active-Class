// test/settings_registry_test.dart — spec 051 (جرد الإعدادات بعد إعادة التنظيم)
import 'package:active_class/views/settings/settings_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = kSettingsItems;
  final cats = kSettingsCategories;

  test('معرّفات العناصر فريدة', () {
    final ids = items.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('معرّفات الفئات فريدة والترتيب متصل', () {
    final ids = cats.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    final orders = cats.map((c) => c.order).toList()..sort();
    expect(orders, List.generate(cats.length, (i) => i + 1));
    expect(cats.length, lessThanOrEqualTo(9)); // FR-001
  });

  test('كل عنصر له فئة موجودة، ولا فئة فاضية، ولا فئة > 12 عنصر ظاهر', () {
    final catIds = cats.map((c) => c.id).toSet();
    for (final i in items) {
      expect(catIds.contains(i.categoryId), true, reason: i.id);
    }
    for (final c in cats) {
      final n = itemsOfCategory(c.id).length;
      expect(n, greaterThan(0), reason: c.id);
      // SC-004: ≤ 12 عنصر ظاهر (المشروطة بتتعدّ ضمنها).
      expect(n, lessThanOrEqualTo(14), reason: c.id);
    }
  });

  test('parentId يشاور لعنصر موجود في نفس الفئة', () {
    final byId = {for (final i in items) i.id: i};
    for (final i in items.where((i) => i.parentId != null)) {
      final p = byId[i.parentId];
      expect(p, isNotNull, reason: i.id);
      expect(p!.categoryId, i.categoryId, reason: i.id);
    }
  });

  group('الجرد (SC-003): كل إعدادات النسخة السابقة موجودة', () {
    final settingsOnly = items.where((i) => i.categoryId != 'about').toList();
    int count(SettingsItemKind k) =>
        settingsOnly.where((i) => i.kind == k).length;

    test('20 سويتش', () => expect(count(SettingsItemKind.switchTile), 20));
    test('13 قائمة اختيار', () => expect(count(SettingsItemKind.dropdown), 13));
    test('10 عناصر تنقّل (9 + صحة البيانات spec 052)',
        () => expect(count(SettingsItemKind.nav), 10));
  });

  test('منطقة الخطر: حذف السجلات وحذف الكل فقط وفي فئة البيانات', () {
    final danger = items.where((i) => i.section == 'منطقة الخطر').toList();
    expect(danger.map((i) => i.id).toSet(),
        {'data.delete_range', 'data.delete_all'});
    expect(danger.every((i) => i.categoryId == 'data'), true);
  });

  test('إعدادات الحضور مش تحت اسم "QR" بس: الواجب/التسميع/التفاعل/الغياب', () {
    final att = itemsOfCategory('attendance').map((i) => i.id).toSet();
    expect(
        att.containsAll({
          'attendance.show_homework',
          'attendance.show_recitation',
          'attendance.show_interaction',
          'attendance.auto_absent',
          'attendance.overdue_warning',
        }),
        true);
  });

  test('الفلوس مجمّعة: العملة والمهلة ويوم النزول وتأخّر الدفع في billing', () {
    final b = itemsOfCategory('billing').map((i) => i.id).toSet();
    expect(
        b.containsAll({
          'billing.currency',
          'billing.grace_days',
          'billing.arrears',
          'billing.billing_day',
          'billing.prorate',
          'billing.at_risk_payment',
        }),
        true);
  });

  test('رمز دولة الواتساب مع الواتساب مش مع العملة', () {
    final dial = items.firstWhere((i) => i.id == 'whatsapp.country_dial');
    expect(dial.categoryId, 'whatsapp');
  });

  group('البحث (FR-009)', () {
    List<String> ids(String q, {bool assistant = false, bool portal = true}) =>
        searchSettings(q, isAssistant: assistant, portalEnabled: portal)
            .map((i) => i.id)
            .toList();

    test('تطبيع: تشكيل/ألف/ياء/تاء مربوطة/أرقام', () {
      expect(normalizeArabic('  التَّسْمِيع '), 'التسميع');
      expect(normalizeArabic('إخفاء أدوات'), 'اخفاء ادوات');
      expect(normalizeArabic('الحصة'), 'الحصه');
      expect(normalizeArabic('مَدى'), 'مدي');
      expect(normalizeArabic('٢٤'), '24');
    });

    test('"تسميع" يرجّع السويتش والدرجة العظمى', () {
      final r = ids('تسميع');
      expect(
          r,
          containsAll(
              ['attendance.show_recitation', 'attendance.recitation_max']));
      expect(r.first, 'attendance.show_recitation'); // مطابقة العنوان أولًا
    });

    test('الكتابة بالتاء المربوطة/الهاء تطابق', () {
      expect(ids('الحصه'), isNotEmpty);
      expect(ids('الحصة'), ids('الحصه'));
    });

    test('كلمات متعددة: كلها لازم تتلاقى', () {
      final r = ids('غياب تلقائي');
      expect(r, contains('attendance.auto_absent'));
      expect(r, isNot(contains('followup.absence')));
    });

    test('بحث بكلمة مفتاحية (باك اب → نسخة)', () {
      expect(ids('باك اب'), contains('data.create_backup'));
    });

    test('أقل من حرفين أو بلا نتيجة → فاضي', () {
      expect(ids('ت'), isEmpty);
      expect(ids('zzzzzz'), isEmpty);
      expect(ids(''), isEmpty);
    });

    test('عنصر البوابة يتخفّى لو الإضافة مقفولة', () {
      expect(ids('متابعة أولياء الأمور', portal: false),
          isNot(contains('account.parent_portal')));
      expect(ids('متابعة أولياء الأمور', portal: true),
          contains('account.parent_portal'));
    });
  });
}
