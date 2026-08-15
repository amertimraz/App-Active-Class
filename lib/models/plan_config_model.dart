// lib/models/plan_config_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanConfigModel {
  final String id;
  final String nameAr;
  final String price;
  final String originalPrice; // فارغ = لا خصم
  final String period;
  final List<String> features;
  final int colorValue;
  final bool recommended;
  final int order;
  final bool isVisible;

  const PlanConfigModel({
    required this.id,
    required this.nameAr,
    required this.price,
    required this.originalPrice,
    required this.period,
    required this.features,
    required this.colorValue,
    required this.recommended,
    required this.order,
    required this.isVisible,
  });

  factory PlanConfigModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlanConfigModel(
      id:            doc.id,
      nameAr:        d['nameAr']        as String?  ?? doc.id,
      price:         d['price']         as String?  ?? '',
      originalPrice: d['originalPrice'] as String?  ?? '',
      period:        d['period']        as String?  ?? 'سنوياً',
      features:      List<String>.from(d['features'] as List? ?? []),
      colorValue:    d['colorValue']    as int?     ?? 0xFF4F46E5,
      recommended:   d['recommended']   as bool?    ?? false,
      order:         d['order']         as int?     ?? 0,
      isVisible:     d['isVisible']     as bool?    ?? true,
    );
  }

  bool get hasDiscount => originalPrice.isNotEmpty;

  // القيم الافتراضية (fallback)
  static List<PlanConfigModel> get defaults => [
    const PlanConfigModel(
      id: 'monthly', nameAr: 'الباقة الشهرية',
      price: '99 جنيه', originalPrice: '',
      period: 'شهرياً',
      features: [
        '✅ مجموعات وطلاب غير محدودين',
        '✅ نسخ احتياطي وتصدير',
        '✅ إرسال واتساب',
      ],
      colorValue: 0xFF10B981, recommended: false, order: 0, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'four_months', nameAr: 'باقة 4 شهور',
      price: '349 جنيه', originalPrice: '396 جنيه',
      period: '4 شهور',
      features: [
        '✅ مجموعات وطلاب غير محدودين',
        '✅ نسخ احتياطي وتصدير',
        '✅ إرسال واتساب',
      ],
      colorValue: 0xFF4F46E5, recommended: true, order: 1, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'nine_months', nameAr: 'باقة 9 شهور',
      price: '649 جنيه', originalPrice: '891 جنيه',
      period: '9 شهور',
      features: [
        '✅ مجموعات وطلاب غير محدودين',
        '✅ نسخ احتياطي وتصدير',
        '✅ إرسال واتساب',
      ],
      colorValue: 0xFFF59E0B, recommended: false, order: 2, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'yearly', nameAr: 'الباقة السنوية',
      price: '799 جنيه', originalPrice: '1188 جنيه',
      period: '12 شهر',
      features: [
        '✅ مجموعات وطلاب غير محدودين',
        '✅ نسخ احتياطي وتصدير',
        '✅ إرسال واتساب',
        '⭐ أفضل قيمة',
      ],
      colorValue: 0xFFEC4899, recommended: false, order: 3, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'lifetime', nameAr: 'مدى الحياة',
      price: '', originalPrice: '',
      period: 'مرة واحدة',
      features: [
        '✅ كل المميزات مدى الحياة',
        '✅ لا تجديد أبداً',
        '✅ كل التحديثات القادمة',
        '📞 السعر بالتواصل مع الدعم',
      ],
      colorValue: 0xFF8B5CF6, recommended: false, order: 4, isVisible: true,
    ),
  ];
}
