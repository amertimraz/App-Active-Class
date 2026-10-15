// test/merge_plan_test.dart — spec 052 (خطة دمج المكرّر)
import 'package:active_class/utils/merge_plan.dart';
import 'package:flutter_test/flutter_test.dart';

RowRef r(int id, String? key, {String? status, int? upd, String? remote}) =>
    RowRef(
      id: id,
      remoteId: remote,
      key: key,
      status: status,
      updatedAt:
          upd == null ? null : DateTime(2026, 1, 1).add(Duration(days: upd)),
    );

StudentRows rows(int id, Map<String, List<RowRef>> m, {String? remote}) =>
    StudentRows(studentId: id, remoteId: remote, byTable: m);

void main() {
  group('دمج طالب', () {
    test('حضور بنفس اليوم يتشال، بيوم مختلف يتنقل', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {
            'attendance': [
              r(10, '2026-10-01', status: 'حاضر'),
              r(11, '2026-10-02', status: 'حاضر')
            ]
          }),
          2: rows(2, {
            'attendance': [
              r(20, '2026-10-01', status: 'حاضر'), // مكرّر
              r(21, '2026-10-03', status: 'غائب'), // جديد
              r(22, '2026-10-04', status: 'حاضر'), // جديد
            ]
          }),
        },
      );
      expect(plan.students.length, 1);
      final p = plan.students.first;
      expect(p.canonicalId, 1);
      expect(p.duplicateId, 2);
      expect(p.drops['attendance']!.map((e) => e.id), [20]);
      expect(p.moves['attendance']!.map((e) => e.id).toSet(), {21, 22});
      expect(plan.summary.moved['attendance'], 2);
      expect(plan.summary.dropped['attendance'], 1);
      expect(plan.summary.conflicts, 0);
    });

    test('تعارض حالة الحضور: الأساسي يكسب ويتعدّ', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {
            'attendance': [r(10, 'd1', status: 'حاضر')]
          }),
          2: rows(2, {
            'attendance': [r(20, 'd1', status: 'غائب')]
          }),
        },
      );
      expect(plan.summary.conflicts, 1);
      expect(plan.students.first.conflicts.first.canonicalStatus, 'حاضر');
      expect(plan.summary.dropped['attendance'], 1);
    });

    test('دفعة بنفس التاريخ+المبلغ تتشال، غيرها تتنقل', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {
            'payments': [r(1, '2026-10-01|100')]
          }),
          2: rows(2, {
            'payments': [r(2, '2026-10-01|100'), r(3, '2026-10-05|100')]
          }),
        },
      );
      expect(plan.summary.dropped['payments'], 1);
      expect(plan.summary.moved['payments'], 1);
    });

    test('درجة بنفس الامتحان تتشال، امتحان تاني يتنقل', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {
            'exam_grades': [r(1, 'e1')]
          }),
          2: rows(2, {
            'exam_grades': [r(2, 'e1'), r(3, 'e2')]
          }),
        },
      );
      expect(plan.summary.dropped['exam_grades'], 1);
      expect(plan.summary.moved['exam_grades'], 1);
    });

    test('صفوف بلا مفتاح (متابعات) بتتنقل كلها', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {}),
          2: rows(2, {
            'student_follow_ups': [r(1, null), r(2, null)]
          }),
        },
      );
      expect(plan.summary.moved['student_follow_ups'], 2);
    });

    test('3 نسخ: المكرّر التاني ما يكرّرش اللي اتنقل من الأول', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2, 3])
        ],
        studentRows: {
          1: rows(1, {
            'homework': [r(1, 'd1')]
          }),
          2: rows(2, {
            'homework': [r(2, 'd2')]
          }),
          3: rows(3, {
            'homework': [r(3, 'd2'), r(4, 'd3')]
          }),
        },
      );
      expect(plan.summary.studentsMerged, 2);
      // d2: اتنقل من 2، فنسخة 3 تتشال. d3 يتنقل.
      expect(plan.summary.moved['homework'], 2);
      expect(plan.summary.dropped['homework'], 1);
    });

    test('نفس المفتاح مرتين عند المكرّر: الأحدث يتنقل والأقدم يتشال', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2])
        ],
        studentRows: {
          1: rows(1, {}),
          2: rows(2, {
            'attendance': [
              r(20, 'd1', upd: 1, status: 'حاضر'),
              r(21, 'd1', upd: 5, status: 'غائب')
            ]
          }),
        },
      );
      final p = plan.students.first;
      expect(p.moves['attendance']!.single.id, 21);
      expect(p.drops['attendance']!.single.id, 20);
    });

    test('سلسلة أ←ب←ج تتحل لـ ج', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(2, [1]),
          const StudentMergeRequest(3, [2]),
        ],
        studentRows: {1: rows(1, {}), 2: rows(2, {}), 3: rows(3, {})},
      );
      expect(plan.students.map((p) => p.canonicalId).toSet(), {3});
      expect(plan.students.map((p) => p.duplicateId).toSet(), {1, 2});
    });

    test('دوّارة ما تعلّقش', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2]),
          const StudentMergeRequest(2, [1]),
        ],
        studentRows: {1: rows(1, {}), 2: rows(2, {})},
      );
      expect(plan.students.length, lessThanOrEqualTo(2));
    });

    test('بلا طلبات ← خطة فاضية', () {
      final plan = buildMergePlan(studentRows: {});
      expect(plan.isEmpty, true);
      expect(plan.summary.totalMoved, 0);
    });
  });

  group('دمج مجموعة', () {
    GroupRows grp(int id, List<StudentBrief> st,
            {Map<String, List<RowRef>> t = const {}, String? remote}) =>
        GroupRows(groupId: id, students: st, byTable: t, remoteId: remote);

    test('المطابق بالاسم يتدمج والغير مطابق يتنقل', () {
      final plan = buildMergePlan(
        groupRequests: [const GroupMergeRequest(1, 2)],
        groupRows: {
          1: grp(1, [
            const StudentBrief(id: 10, name: 'منى أحمد'),
            const StudentBrief(id: 11, name: 'علي حسن'),
          ]),
          2: grp(2, [
            const StudentBrief(id: 20, name: 'منى  أحمد'), // مطابق
            const StudentBrief(id: 21, name: 'ياسمين'), // جديد
          ]),
        },
        studentRows: {
          10: rows(10, {
            'attendance': [r(1, 'd1')]
          }),
          20: rows(20, {
            'attendance': [r(2, 'd1'), r(3, 'd2')]
          }),
        },
      );
      expect(plan.groups.length, 1);
      expect(plan.groups.first.studentsToMove, [21]);
      expect(plan.groups.first.matchedStudents, {20: 10});
      expect(plan.summary.studentsMerged, 1);
      expect(plan.summary.studentsMovedToGroup, 1);
      expect(plan.summary.groupsMerged, 1);
      expect(plan.summary.dropped['attendance'], 1);
      expect(plan.summary.moved['attendance'], 1);
    });

    test('ربط الامتحان بالاتنين: يتشال المكرّر، وغيره يتنقل', () {
      final plan = buildMergePlan(
        groupRequests: [const GroupMergeRequest(1, 2)],
        groupRows: {
          1: grp(1, [], t: {
            'exam_groups': [r(1, 'e1')]
          }),
          2: grp(2, [], t: {
            'exam_groups': [r(2, 'e1'), r(3, 'e2')],
            'session_overrides': [r(4, null)],
          }),
        },
        studentRows: {},
      );
      final g = plan.groups.first;
      expect(g.drops['exam_groups']!.single.id, 2);
      expect(g.moves['exam_groups']!.single.id, 3);
      expect(g.moves['session_overrides']!.single.id, 4);
    });

    test('حالة Grade 2: 45 طالب = 21 أساسي + 24 مكرّر ← أرقام الملخص', () {
      final canon = [
        for (var i = 0; i < 21; i++) StudentBrief(id: 100 + i, name: 'طالب $i')
      ];
      final dups = [
        for (var i = 0; i < 24; i++)
          // 21 مطابق + 3 غير مطابق (جدد)
          StudentBrief(id: 200 + i, name: i < 21 ? 'طالب $i' : 'جديد $i')
      ];
      final sr = <int, StudentRows>{};
      for (var i = 0; i < 21; i++) {
        sr[100 + i] = rows(100 + i, {
          'attendance': [r(1000 + i, 'd1')]
        });
        sr[200 + i] = rows(200 + i, {
          'attendance': [r(2000 + i, 'd1'), r(3000 + i, 'd2')]
        });
      }
      final plan = buildMergePlan(
        groupRequests: [const GroupMergeRequest(1, 2)],
        groupRows: {
          1: GroupRows(groupId: 1, students: canon),
          2: GroupRows(groupId: 2, students: dups),
        },
        studentRows: sr,
      );
      expect(plan.summary.groupsMerged, 1);
      expect(plan.summary.studentsMerged, 21);
      expect(plan.summary.studentsMovedToGroup, 3);
      expect(plan.summary.dropped['attendance'], 21);
      expect(plan.summary.moved['attendance'], 21);
    });
  });

  group('حماية من فقد البيانات', () {
    test('دوّارة صريحة (أ←ب و ب←أ) ما تحذفش ولا طالب', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2]),
          const StudentMergeRequest(2, [1]),
        ],
        studentRows: {1: rows(1, {}), 2: rows(2, {})},
      );
      expect(plan.students, isEmpty);
    });

    test('أساسي مختار داخل المجموعة المكرّرة + دمج المجموعتين: لا دوّارة', () {
      // طالب 10 في الأساسية A (قليل بيانات) وطالب 20 في المكرّرة B (كتير).
      // المدرس اختار 20 أساسي لحالة الطالب، وكمان دمج المجموعتين.
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(20, [10])
        ],
        groupRequests: [const GroupMergeRequest(1, 2)],
        groupRows: {
          1: GroupRows(groupId: 1, students: const [
            StudentBrief(id: 10, name: 'منى أحمد'),
          ]),
          2: GroupRows(groupId: 2, students: const [
            StudentBrief(id: 20, name: 'منى أحمد'),
          ]),
        },
        studentRows: {
          10: rows(10, {
            'attendance': [r(1, 'd1')]
          }),
          20: rows(20, {
            'attendance': [r(2, 'd2'), r(3, 'd3')]
          }),
        },
      );
      // لازم طالب واحد بس يتحذف (10)، و20 يفضل وينتقل لمجموعة A.
      expect(plan.students.length, 1);
      expect(plan.students.first.canonicalId, 20);
      expect(plan.students.first.duplicateId, 10);
      expect(plan.groups.first.studentsToMove, contains(20));
      expect(plan.groups.first.matchedStudents, isEmpty);
      // سجل 10 (d1) اتنقل لـ20.
      expect(plan.summary.moved['attendance'], 1);
    });

    test('الأساسي ما يتحذفش أبدًا (ولا يظهر كمكرّر)', () {
      final plan = buildMergePlan(
        studentRequests: [
          const StudentMergeRequest(1, [2, 3]),
          const StudentMergeRequest(3, [4]),
        ],
        studentRows: {
          1: rows(1, {}),
          2: rows(2, {}),
          3: rows(3, {}),
          4: rows(4, {})
        },
      );
      final dups = plan.students.map((p) => p.duplicateId).toSet();
      final canons = plan.students.map((p) => p.canonicalId).toSet();
      expect(dups.intersection(canons), isEmpty);
      expect(canons, {1});
      expect(dups, {2, 3, 4});
    });
  });
}
