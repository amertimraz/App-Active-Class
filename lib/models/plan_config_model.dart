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
      id: 'basic', nameAr: 'الباقة الأساسية',
      price: '99 جنيه', originalPrice: '149 جنيه',
      period: 'شهرياً',
      features: [
        '✅ حتى 5 مجموعات',
        '✅ حتى 30 طالب/مجموعة',
        '✅ نسخ احتياطي وتصدير',
        '❌ إرسال واتساب',
      ],
      colorValue: 0xFF10B981, recommended: false, order: 0, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'pro', nameAr: 'الباقة الاحترافية',
      price: '179 جنيه', originalPrice: '249 جنيه',
      period: 'شهرياً',
      features: [
        '✅ مجموعات غير محدودة',
        '✅ طلاب غير محدودين',
        '✅ نسخ احتياطي وتصدير',
        '✅ إرسال واتساب',
      ],
      colorValue: 0xFF4F46E5, recommended: true, order: 1, isVisible: true,
    ),
    const PlanConfigModel(
      id: 'lifetime', nameAr: 'مدى الحياة',
      price: '799 جنيه', originalPrice: '1199 جنيه',
      period: 'مرة واحدة',
      features: [
        '✅ كل مزايا الاحترافية',
        '✅ لا تجديد شهري',
        '✅ كل التحديثات القادمة',
        '⭐ الأفضل قيمة',
      ],
      colorValue: 0xFFF59E0B, recommended: false, order: 2, isVisible: true,
    ),
  ];
}
