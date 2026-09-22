// lib/views/groups/group_details_widgets.dart
// ويدجتس مساعدة صغيرة خاصة بشاشة "تفاصيل المجموعة" — استُخرِجت من
// group_details_page.dart لتقصير الملف الرئيسي (spec 039).
import 'package:flutter/material.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/locked_feature.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Header stat card
// ─────────────────────────────────────────────────────────────────────────────
class HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool locked;

  const HeaderStat(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.onTap,
      this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LockBadge(
        locked: locked,
        child: GestureDetector(
        onTap: locked ? showLockedPermissionHint : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(height: 4),
              // القيم بقت من غير اسم العملة (راجع formatCurrencyCompact)
              // فبقت قصيرة كفاية تفضل في صف واحد بخط مقروء عادي —
              // maxLines:2 يبقى شبكة أمان بس لأرقام كبيرة جدًا مستقبلاً.
              Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action chip
// ─────────────────────────────────────────────────────────────────────────────
class GroupActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const GroupActionChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              // maxLines:2 بدل 1 — تسميات زي "تصفير الطلاب" أطول من باقي
              // الأزرار جنبها ("حذف"، "واتساب") في نفس المساحة المتساوية،
              // فبتلف سطرين بدل ما تتقص.
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student card
// ─────────────────────────────────────────────────────────────────────────────
class StudentCard extends StatelessWidget {
  final Student student;
  final Color groupColor;
  final bool hasPaid;
  final bool canSeeFinancials;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const StudentCard({
    super.key,
    required this.student,
    required this.groupColor,
    required this.hasPaid,
    required this.canSeeFinancials,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onQr,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials =
        student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? groupColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1A2540) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? groupColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Checkbox or Avatar
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? groupColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? groupColor : Colors.grey.shade400,
                          width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials,
                        style: TextStyle(
                            color: groupColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
                ),

              const SizedBox(width: 12),

              // Info
              // الاسم على سطره الخاص كامل دايمًا (بدون قص) — الكود وشارة
              // الدفع نزلوا سطر منفصل تحته بدل ما يزنقوا الاسم جنب أيقونتَي
              // الـQR والقائمة على يمين الصف.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(student.code,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        if (!canSeeFinancials)
                          // مبنفرقش هنا بين دفع/مادفعش — عرض الشارة بس
                          // لما "لم يدفع" كانت هتبقى هي نفسها تسريب
                          // لحالة الدفع (وجودها/غيابها كان هيوضح الحالة
                          // حتى تحت قفل).
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.lock_rounded,
                                size: 10, color: Colors.grey.shade600),
                          )
                        else if (!hasPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('لم يدفع',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (!isSelectionMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBtn(
                        icon: Icons.qr_code_rounded,
                        color: groupColor,
                        onTap: onQr),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: Colors.grey.shade500, size: 20),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'archive') onArchive();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('تعديل')
                            ])),
                        const PopupMenuItem(
                            value: 'archive',
                            child: Row(children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.red))
                            ])),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const IconBtn(
      {super.key, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// شارة إحصائية صغيرة في عنوان نافذة الإرسال
class SendStatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const SendStatBadge({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text('$label: $count',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ]),
      );
}

class GDSessionDay {
  final DateTime date;
  final int presentCount;
  final int totalMarked;
  final List<int> recordIds;
  const GDSessionDay(
      {required this.date,
      required this.presentCount,
      required this.totalMarked,
      required this.recordIds});
}


class GDResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  GDResumeObserver(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
