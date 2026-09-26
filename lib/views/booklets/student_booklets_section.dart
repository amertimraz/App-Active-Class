// lib/views/booklets/student_booklets_section.dart
//
// spec 041 — قسم "الملازم" في تفاصيل الطالب: حالة التسليم + المدفوع/المتبقي
// لكل ملزمة، و"متبقي ملازم" منفصل بصريًا عن مديونية الاشتراك (FR-011/012).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/booklet_controller.dart';
import 'package:active_class/utils/booklet_math.dart';
import 'package:active_class/utils/helpers.dart';

bool studentHasBooklets(int studentId) =>
    Get.isRegistered<BookletController>() &&
    Get.find<BookletController>().linesForStudent(studentId).isNotEmpty;

class StudentBookletsSection extends StatefulWidget {
  final int studentId;
  const StudentBookletsSection({super.key, required this.studentId});

  @override
  State<StudentBookletsSection> createState() => _StudentBookletsSectionState();
}

class _StudentBookletsSectionState extends State<StudentBookletsSection> {
  int get studentId => widget.studentId;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<BookletController>()) {
      Get.find<BookletController>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<BookletController>()) return const SizedBox.shrink();
    final c = Get.find<BookletController>();
    return Obx(() {
      final lines = c.linesForStudent(studentId);
      if (lines.isEmpty) return const SizedBox.shrink();
      final remaining = c.remainingForStudent(studentId);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.menu_book_rounded, color: Colors.indigo),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('الملازم والكتب',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              Text('متبقي ملازم: ${FormatHelper.formatCurrency(remaining)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: remaining > 0 ? Colors.indigo : Colors.green)),
            ]),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(l.booklet.name)),
                  Text(l.delivered ? 'استلم' : 'لم يستلم',
                      style: TextStyle(
                          fontSize: 12,
                          color: l.delivered ? Colors.green : Colors.orange)),
                  const SizedBox(width: 10),
                  Text(
                    switch (l.status) {
                      BookletPaymentStatus.full => 'مدفوعة',
                      BookletPaymentStatus.partial =>
                        'متبقي ${FormatHelper.formatCurrency(l.remaining)}',
                      BookletPaymentStatus.none => 'لم يدفع',
                    },
                    style: const TextStyle(fontSize: 12),
                  ),
                ]),
              ),
          ],
        ),
      );
    });
  }
}
