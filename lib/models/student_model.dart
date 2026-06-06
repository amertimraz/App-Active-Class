// lib/models/student_model.dart

class Student {
  final int? id;
  final String name;
  final String code;
  final int groupId;
  final double price;
  final String? qrPath;
  final int? siblingId;
  final double? siblingsTotal;
  final DateTime? createdAt;
  final DateTime? attendanceStart;
  final String? guardianPhone;
  final DateTime? birthDate; // تاريخ الميلاد

  Student({
    this.id,
    required this.name,
    required this.code,
    required this.groupId,
    required this.price,
    this.qrPath,
    this.siblingId,
    this.siblingsTotal,
    this.createdAt,
    this.attendanceStart,
    this.guardianPhone,
    this.birthDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'group_id': groupId,
      'price': price,
      'qr_path': qrPath,
      'sibling_id': siblingId,
      'siblings_total': siblingsTotal,
      'created_at': createdAt?.toIso8601String(),
      'attendance_start': attendanceStart?.toIso8601String(),
      'guardian_phone': guardianPhone,
      'birth_date': birthDate?.toIso8601String(),
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      groupId: map['group_id'] as int,
      price: (map['price'] as num).toDouble(),
      qrPath: map['qr_path'] as String?,
      siblingId: map['sibling_id'] as int?,
      siblingsTotal: map['siblings_total'] != null ? (map['siblings_total'] as num).toDouble() : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      attendanceStart: map['attendance_start'] != null
          ? DateTime.parse(map['attendance_start'] as String)
          : null,
      guardianPhone: map['guardian_phone'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? code,
    int? groupId,
    double? price,
    String? qrPath,
    int? siblingId,
    double? siblingsTotal,
    DateTime? createdAt,
    DateTime? attendanceStart,
    String? guardianPhone,
    DateTime? birthDate,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      groupId: groupId ?? this.groupId,
      price: price ?? this.price,
      qrPath: qrPath ?? this.qrPath,
      siblingId: siblingId ?? this.siblingId,
      siblingsTotal: siblingsTotal ?? this.siblingsTotal,
      createdAt: createdAt ?? this.createdAt,
      attendanceStart: attendanceStart ?? this.attendanceStart,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  @override
  String toString() => 'Student(id: $id, name: $name, code: $code, price: $price)';
}
