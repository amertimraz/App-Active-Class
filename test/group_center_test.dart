// السنتر على المجموعة (spec 058 — المرحلة أ، تنظيم وفلترة بس).
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';

Group _g(String name, {String? center}) => Group(name: name, center: center);

void main() {
  group('Group.center — الموديل', () {
    test('toMap/fromMap بيحفظوا السنتر', () {
      final g = _g('أ', center: 'سنتر النور');
      expect(g.toMap()['center'], 'سنتر النور');
      expect(Group.fromMap({...g.toMap(), 'id': 1}).center, 'سنتر النور');
    });

    test('مجموعة قديمة من غير عمود center بتتقرا بدون سنتر', () {
      final g = Group.fromMap({'id': 1, 'name': 'قديمة'});
      expect(g.center, isNull);
    });

    test('copyWith: يحافظ على السنتر، ويقدر يمسحه بـclearCenter', () {
      final g = _g('أ', center: 'النور');
      expect(g.copyWith(name: 'ب').center, 'النور');
      expect(g.copyWith(center: 'الأمل').center, 'الأمل');
      expect(g.copyWith(clearCenter: true).center, isNull);
    });
  });

  group('GroupController — السناتر والفلتر', () {
    test('normalizeCenter: مسافات زيادة تتشال والفاضي null', () {
      expect(GroupController.normalizeCenter('  سنتر   النور '), 'سنتر النور');
      expect(GroupController.normalizeCenter('   '), isNull);
      expect(GroupController.normalizeCenter(null), isNull);
    });

    test('centersOf: من غير تكرار ولا فاضي، ومرتّبة', () {
      final list = GroupController.centersOf([
        _g('1', center: 'ب'),
        _g('2', center: ' ب '),
        _g('3', center: 'أ'),
        _g('4'),
        _g('5', center: '  '),
      ]);
      expect(list, ['أ', 'ب']);
    });

    test('matchesCenter: الكل / سنتر معيّن / بدون سنتر', () {
      final a = _g('1', center: 'النور');
      final none = _g('2');
      expect(GroupController.matchesCenter(a, null), isTrue);
      expect(GroupController.matchesCenter(none, null), isTrue);
      expect(GroupController.matchesCenter(a, 'النور'), isTrue);
      expect(GroupController.matchesCenter(a, 'الأمل'), isFalse);
      expect(GroupController.matchesCenter(none, 'النور'), isFalse);
      expect(GroupController.matchesCenter(none, GroupController.kNoCenterFilter),
          isTrue);
      expect(GroupController.matchesCenter(a, GroupController.kNoCenterFilter),
          isFalse);
    });

    test('الفلتر بيتجاهل فرق المسافات في اسم السنتر', () {
      final g = _g('1', center: '  سنتر   النور ');
      expect(GroupController.matchesCenter(g, 'سنتر النور'), isTrue);
    });
  });

  group('GroupController.sectionsOf — أقسام القايمة', () {
    test('كل سنتر وتحته مجموعاته، مرتّبين بالاسم، و«بدون سنتر» آخرًا', () {
      final secs = GroupController.sectionsOf([
        _g('1', center: 'ب'),
        _g('2'),
        _g('3', center: 'أ'),
        _g('4', center: ' ب '),
      ]);
      expect(secs.map((s) => s.center).toList(), ['أ', 'ب', null]);
      expect(secs[0].groups.map((g) => g.name), ['3']);
      expect(secs[1].groups.map((g) => g.name), ['1', '4']);
      expect(secs[2].groups.map((g) => g.name), ['2']);
    });

    test('من غير أي سنتر: قسم واحد بدون عنوان', () {
      final secs = GroupController.sectionsOf([_g('1'), _g('2')]);
      expect(secs.length, 1);
      expect(secs.single.center, isNull);
      expect(secs.single.groups.length, 2);
    });

    test('قايمة فاضية: مفيش أقسام', () {
      expect(GroupController.sectionsOf(const []), isEmpty);
    });
  });
}
