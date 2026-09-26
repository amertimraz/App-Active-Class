// lib/models/booklet_model.dart
//
// spec 041 — الملازم/الكتب. جداول مستقلة تمامًا عن Payment/accumulatedDebt.
import 'package:active_class/config/constants.dart';

DateTime? _dt(dynamic v) =>
    (v == null || (v is String && v.isEmpty)) ? null : DateTime.tryParse('$v');

class Booklet {
  final int? id;
  final String name;
  final double price;
  final DateTime? createdAt;

  const Booklet({this.id, required this.name, required this.price, this.createdAt});

  Map<String, dynamic> toMap() => {
        COL_BK_ID: id,
        COL_BK_NAME: name,
        COL_BK_PRICE: price,
        COL_BK_CREATED_AT: (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Booklet.fromMap(Map<String, dynamic> m) => Booklet(
        id: m[COL_BK_ID] as int?,
        name: (m[COL_BK_NAME] as String?) ?? '',
        price: (m[COL_BK_PRICE] as num?)?.toDouble() ?? 0,
        createdAt: _dt(m[COL_BK_CREATED_AT]),
      );

  Booklet copyWith({String? name, double? price}) => Booklet(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        createdAt: createdAt,
      );
}

class BookletGroupLink {
  final int? id;
  final int bookletId;
  final int groupId;

  const BookletGroupLink({this.id, required this.bookletId, required this.groupId});

  Map<String, dynamic> toMap() => {
        COL_BG_ID: id,
        COL_BG_BOOKLET_ID: bookletId,
        COL_BG_GROUP_ID: groupId,
      };

  factory BookletGroupLink.fromMap(Map<String, dynamic> m) => BookletGroupLink(
        id: m[COL_BG_ID] as int?,
        bookletId: m[COL_BG_BOOKLET_ID] as int,
        groupId: m[COL_BG_GROUP_ID] as int,
      );
}

class BookletRecord {
  final int? id;
  final int bookletId;
  final int studentId;
  final bool delivered;
  final DateTime? deliveredAt;
  final bool excluded;

  const BookletRecord({
    this.id,
    required this.bookletId,
    required this.studentId,
    this.delivered = false,
    this.deliveredAt,
    this.excluded = false,
  });

  Map<String, dynamic> toMap() => {
        COL_BR_ID: id,
        COL_BR_BOOKLET_ID: bookletId,
        COL_BR_STUDENT_ID: studentId,
        COL_BR_DELIVERED: delivered ? 1 : 0,
        COL_BR_DELIVERED_AT: deliveredAt?.toIso8601String(),
        COL_BR_EXCLUDED: excluded ? 1 : 0,
      };

  factory BookletRecord.fromMap(Map<String, dynamic> m) => BookletRecord(
        id: m[COL_BR_ID] as int?,
        bookletId: m[COL_BR_BOOKLET_ID] as int,
        studentId: m[COL_BR_STUDENT_ID] as int,
        delivered: (m[COL_BR_DELIVERED] as num?) == 1,
        deliveredAt: _dt(m[COL_BR_DELIVERED_AT]),
        excluded: (m[COL_BR_EXCLUDED] as num?) == 1,
      );
}

class BookletPayment {
  final int? id;
  final int bookletId;
  final int studentId;
  final double amount;
  final DateTime date;

  const BookletPayment({
    this.id,
    required this.bookletId,
    required this.studentId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        COL_BP_ID: id,
        COL_BP_BOOKLET_ID: bookletId,
        COL_BP_STUDENT_ID: studentId,
        COL_BP_AMOUNT: amount,
        COL_BP_DATE: date.toIso8601String(),
      };

  factory BookletPayment.fromMap(Map<String, dynamic> m) => BookletPayment(
        id: m[COL_BP_ID] as int?,
        bookletId: m[COL_BP_BOOKLET_ID] as int,
        studentId: m[COL_BP_STUDENT_ID] as int,
        amount: (m[COL_BP_AMOUNT] as num?)?.toDouble() ?? 0,
        date: _dt(m[COL_BP_DATE]) ?? DateTime.now(),
      );
}
