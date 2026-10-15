// test/duplicate_detection_test.dart — spec 052 (اكتشاف التكرار)
import 'package:active_class/utils/duplicate_detection.dart';
import 'package:flutter_test/flutter_test.dart';

DupStudentInput st(int id, String name, String code, int gid,
        {String? phone,
        DateTime? created,
        bool archived = false,
        int? sibling,
        int records = 0}) =>
    DupStudentInput(
      id: id,
      name: name,
      code: code,
      groupId: gid,
      guardianPhone: phone,
      createdAt: created,
      isArchived: archived,
      siblingGroupId: sibling,
      recordCount: records,
    );

void main() {
  group('التطبيع', () {
    test('normalizeName: تشكيل/ألف/ياء/تاء مربوطة/مسافات', () {
      expect(normalizeName('  أحمدُ   مصطفى '), normalizeName('احمد مصطفي'));
      expect(normalizeName('فاطمة'), normalizeName('فاطمه'));
    });
    test('codeStem يشيل -N بس', () {
      expect(codeStem('g206-2'), 'G206');
      expect(codeStem('G206'), 'G206');
      expect(codeStem('G5A10-2'), 'G5A10');
      expect(codeStem('G5A10'), 'G5A10');
    });
  });

  group('pickCanonical', () {
    final d1 = DateTime(2026, 1, 1), d2 = DateTime(2026, 5, 1);
    test('الأكتر بيانات يكسب', () {
      final c = [
        CandidateCopy(id: 1, name: 'a', recordCount: 5, createdAt: d1),
        CandidateCopy(id: 2, name: 'a', recordCount: 40, createdAt: d2),
      ];
      expect(pickCanonical(c), 2);
    });
    test('تعادل ← الأقدم', () {
      final c = [
        CandidateCopy(id: 1, name: 'a', recordCount: 5, createdAt: d2),
        CandidateCopy(id: 2, name: 'a', recordCount: 5, createdAt: d1),
      ];
      expect(pickCanonical(c), 2);
    });
    test('تعادل كامل ← الكود بلا لاحقة', () {
      final c = [
        CandidateCopy(id: 1, name: 'a', suffixed: true, createdAt: d1),
        CandidateCopy(id: 2, name: 'a', suffixed: false, createdAt: d1),
      ];
      expect(pickCanonical(c), 2);
    });
    test('المؤرشف ما يبقاش الأساسي لو فيه نشط', () {
      final c = [
        CandidateCopy(id: 1, name: 'a', isArchived: true, recordCount: 100),
        CandidateCopy(id: 2, name: 'a', recordCount: 1),
      ];
      expect(pickCanonical(c), 2);
    });
  });

  group('مجموعات', () {
    test('نفس الاسم المطبّع ← حالة، واسم مختلف ← لا', () {
      final cases = detectGroupDuplicates([
        const DupGroupInput(id: 1, name: 'Grade 2', studentCount: 21),
        const DupGroupInput(id: 2, name: ' grade   2 ', studentCount: 24),
        const DupGroupInput(id: 3, name: 'Grade 3'),
      ]);
      expect(cases.length, 1);
      expect(cases.first.kind, DuplicateKind.group);
      expect(cases.first.reason, MatchReason.sameGroupName);
      expect(cases.first.copies.map((c) => c.id).toSet(), {1, 2});
      expect(cases.first.canonicalId, 2); // الأكتر طلاب
      expect(cases.first.selectedByDefault, true);
    });
    test('مفيش تكرار ← فاضي', () {
      expect(
          detectGroupDuplicates([
            const DupGroupInput(id: 1, name: 'A'),
            const DupGroupInput(id: 2, name: 'B'),
          ]),
          isEmpty);
    });
  });

  group('طلاب', () {
    test('نفس الكود بلاحقة -2 ← sameCode ومحدّد', () {
      final cases = detectStudentDuplicates([
        st(1, 'محمد', 'G206', 10, records: 30),
        st(2, 'محمد', 'G206-2', 11, records: 4),
        st(3, 'سارة', 'G207', 10),
      ]);
      expect(cases.length, 1);
      final c = cases.first;
      expect(c.reason, MatchReason.sameCode);
      expect(c.selectedByDefault, true);
      expect(c.canonicalId, 1);
      expect(c.duplicateIds, [2]);
    });

    test('3 نسخ ← حالة واحدة', () {
      final cases = detectStudentDuplicates([
        st(1, 'علي', 'G1', 1),
        st(2, 'علي', 'G1-2', 1),
        st(3, 'علي', 'G1-3', 1),
      ]);
      expect(cases.length, 1);
      expect(cases.first.copies.length, 3);
    });

    test('نفس الاسم نفس المجموعة بأكواد مختلفة ← sameNameInGroup وغير محدّد',
        () {
      final cases = detectStudentDuplicates([
        st(1, 'منى', 'A1', 5, phone: '01011111111'),
        st(2, 'منى', 'A9', 5, phone: '01022222222'),
      ]);
      expect(cases.length, 1);
      expect(cases.first.reason, MatchReason.sameNameInGroup);
      expect(cases.first.selectedByDefault, false);
      expect(cases.first.guardianMismatch, true);
    });

    test('نفس الاسم في مجموعتين مختلفتين غير مكرّرتين ← مش تكرار', () {
      final cases = detectStudentDuplicates([
        st(1, 'منى', 'A1', 5),
        st(2, 'منى', 'A9', 6),
      ]);
      expect(cases, isEmpty);
    });

    test('نفس الاسم في مجموعتين مكرّرتين ← تكرار مرتبط بالعنقود', () {
      final groups = [
        const DupGroupInput(id: 5, name: 'Grade 2'),
        const DupGroupInput(id: 6, name: 'grade 2'),
      ];
      final clusters = groupClusterKeys(groups);
      final cases = detectStudentDuplicates([
        st(1, 'منى', 'A1', 5),
        st(2, 'منى', 'A9', 6),
      ], groupClusters: clusters);
      expect(cases.length, 1);
      expect(cases.first.groupClusterKey, isNotNull);
    });

    test('إخوة (نفس ولي الأمر، أسماء مختلفة) ← مش تكرار', () {
      final cases = detectStudentDuplicates([
        st(1, 'أحمد', 'S1', 5, phone: '01011111111', sibling: 1),
        st(2, 'محمود', 'S2', 5, phone: '01011111111', sibling: 1),
      ]);
      expect(cases, isEmpty);
    });

    test('تطابق الكود يغطّي تطابق الاسم (حالة واحدة بس)', () {
      final cases = detectStudentDuplicates([
        st(1, 'نور', 'N1', 5),
        st(2, 'نور', 'N1-2', 5),
      ]);
      expect(cases.length, 1);
      expect(cases.first.reason, MatchReason.sameCode);
    });

    test('بلا كود ولا اسم متطابق ← فاضي', () {
      expect(
          detectStudentDuplicates([
            st(1, 'أ', 'A', 1),
            st(2, 'ب', 'B', 1),
          ]),
          isEmpty);
    });
  });
}
