// lib/widgets/guardian_phone_line.dart
//
// سطر رقم ولي الأمر في كروت قوايم الطلاب (أيقونة + الرقم LTR) — عشان
// المدرس يشوفه من غير ما يدخل تفاصيل الطالب. بيرجّع فاضي لو مفيش رقم.
import 'package:flutter/material.dart';

import 'package:active_class/models/student_model.dart';

/// الرقم اللي يتعرض: رقم ولي الأمر، وإلا حقل الواتساب لو كان رقمًا (مش
/// username ولا رابط). null لو مفيش.
String? guardianPhoneForDisplay(Student s) {
  final phone = (s.guardianPhone ?? '').trim();
  if (phone.isNotEmpty) return phone;
  final wa = (s.guardianWhatsapp ?? '').trim();
  if (wa.isNotEmpty && RegExp(r'^[+\d\s\-()٠-٩]{7,}$').hasMatch(wa)) return wa;
  return null;
}

class GuardianPhoneLine extends StatelessWidget {
  const GuardianPhoneLine({super.key, required this.student, this.color});

  final Student student;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final phone = guardianPhoneForDisplay(student);
    if (phone == null) return const SizedBox.shrink();
    final c = color ?? Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.phone_rounded, size: 13, color: c),
        const SizedBox(width: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(phone,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ),
      ]),
    );
  }
}
