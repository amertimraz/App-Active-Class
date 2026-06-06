// lib/models/group_model.dart

class Group {
  final int? id;
  final String name;
  final String? code; // optional unique code
  final double? price; // optional fee
  final int? color; // ARGB int
  final String? icon; // icon name key
  final String? schedule; // optional text/json
  final DateTime? createdAt;

  Group({
    this.id,
    required this.name,
    this.code,
    this.price,
    this.color,
    this.icon,
    this.schedule,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'price': price,
      'color': color,
      'icon': icon,
      'schedule': schedule,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String?,
      price: map['price'] == null ? null : (map['price'] as num).toDouble(),
      color: map['color'] as int?,
      icon: map['icon'] as String?,
      schedule: map['schedule'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Group copyWith({
    int? id,
    String? name,
    String? code,
    double? price,
    int? color,
    String? icon,
    String? schedule,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      price: price ?? this.price,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Group(id: $id, name: $name, code: $code, price: $price, color: $color, icon: $icon, schedule: $schedule, createdAt: $createdAt)';
}
