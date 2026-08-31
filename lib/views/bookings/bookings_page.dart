// lib/views/bookings/bookings_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/booking_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/booking_request_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/clock_text.dart';

const _kPrimary = Color(0xFF4F46E5);
const _kAccent = Color(0xFF0EA5E9);

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final BookingController booking = Get.put(BookingController());
    final StudentController students = Get.put(StudentController());

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF08101F), Color(0xFF121A2D)]
                      : const [Color(0xFFFDFDFF), Color(0xFFEEF4FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          _glow(
            top: -100,
            right: -70,
            size: 230,
            colors: isDark
                ? const [Color(0x334F46E5), Color(0x004F46E5)]
                : const [Color(0x55C7D2FE), Color(0x00C7D2FE)],
          ),
          _glow(
            bottom: 60,
            left: -90,
            size: 240,
            colors: isDark
                ? const [Color(0x330EA5E9), Color(0x000EA5E9)]
                : const [Color(0x55BAE6FD), Color(0x00BAE6FD)],
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark, booking),
                Expanded(
                  child: Obx(() {
                    if (booking.loading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!booking.enabled.value) {
                      return _EmptyState(
                        isDark: isDark,
                        icon: Icons.link_off_rounded,
                        title: 'رابط الحجز غير مفعّل',
                        subtitle: 'فعّل الرابط من الإعدادات عشان تبدأ تستقبل طلبات',
                        actionLabel: 'إعدادات الحجوزات',
                        onAction: () => Get.toNamed(ROUTE_BOOKING_SETTINGS),
                      );
                    }
                    if (booking.syncError.value) {
                      return _EmptyState(
                        isDark: isDark,
                        icon: Icons.sync_problem_rounded,
                        title: 'تعذر تحميل طلبات الحجز',
                        subtitle:
                            'تأكد من الاتصال بالإنترنت وحاول تاني. لو المشكلة استمرت، رابطك القديم ممكن يكون معطوب — تقدر تولّد رابط جديد بدله.',
                        actionLabel: 'إعادة المحاولة',
                        onAction: booking.retry,
                        secondaryActionLabel: 'توليد رابط حجز جديد',
                        onSecondaryAction: () => _confirmRegenerateLink(context, booking),
                      );
                    }
                    if (booking.requests.isEmpty) {
                      return _EmptyState(
                        isDark: isDark,
                        icon: Icons.inbox_rounded,
                        title: 'مفيش طلبات حجز جديدة',
                        subtitle: 'أي طلب يوصل من رابط الحجز هيظهر هنا فورًا',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: booking.requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final r = booking.requests[i];
                        return _RequestCard(
                          request: r,
                          isDark: isDark,
                          onAccept: () async {
                            await showAddStudentSheet(
                              context,
                              controller: students,
                              initialName: r.studentName,
                              initialPhone: r.guardianPhone,
                              onAdded: () async {
                                await booking.removeRequest(r);
                                if (context.mounted) {
                                  AppToast.success(context, 'تم قبول الطلب وإضافة الطالب');
                                }
                              },
                            );
                          },
                          onReject: () async {
                            await booking.removeRequest(r);
                            if (context.mounted) {
                              AppToast.info(context, 'تم رفض الطلب');
                            }
                          },
                          onCall: r.guardianPhone.isEmpty
                              ? null
                              : () => launchUrl(Uri.parse('tel:${r.guardianPhone}')),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerateLink(BuildContext context, BookingController booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('توليد رابط حجز جديد؟', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'الرابط القديم هيوقف عن العمل نهائيًا وأي طلبات حجز وصلت عليه هتضيع. '
          'المفروض تشارك الرابط الجديد بدل القديم مع طلابك.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('توليد رابط جديد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await booking.regenerateLink();
    if (!context.mounted) return;
    if (err != null) {
      AppToast.error(context, err);
    } else {
      AppToast.success(context, 'تم توليد رابط حجز جديد — شاركه من الإعدادات');
    }
  }

  Widget _buildAppBar(BuildContext context, bool isDark, BookingController booking) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Get.back(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              final count = booking.requests.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلبات الحجز',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (booking.enabled.value && count > 0)
                    Text(
                      '$count طلب بانتظار المراجعة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                ],
              );
            }),
          ),
          _IconBtn(
            icon: Icons.settings_rounded,
            isDark: isDark,
            onTap: () => Get.toNamed(ROUTE_BOOKING_SETTINGS),
          ),
        ],
      ),
    );
  }
}

Widget _glow({
  double? top,
  double? right,
  double? bottom,
  double? left,
  required double size,
  required List<Color> colors,
}) {
  return Positioned(
    top: top,
    right: right,
    bottom: bottom,
    left: left,
    child: IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.16)
                  : const Color(0xFFD9E1F2).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: isDark ? Colors.white : const Color(0xFF111827)),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingRequest request;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onCall;

  const _RequestCard({
    required this.request,
    required this.isDark,
    required this.onAccept,
    required this.onReject,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final name = request.studentName.isEmpty ? '(بدون اسم)' : request.studentName;
    final trimmedName = name.trim();
    final initial = trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : '؟';

    final meta = <String>[
      if (request.gradeLevel != null) request.gradeLevel!,
      if (request.classSection != null) request.classSection!,
      if (request.preferredTime != null) request.preferredTime!,
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(color: _kPrimary.withValues(alpha: isDark ? 0.6 : 0.85), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                    if (request.guardianPhone.isNotEmpty)
                      Text(request.guardianPhone,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              color: isDark ? Colors.white54 : Colors.grey[600])),
                  ],
                ),
              ),
              if (onCall != null)
                _CircleAction(icon: Icons.call_rounded, color: const Color(0xFF16A34A), onTap: onCall!),
            ],
          ),
          if (request.createdAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 13, color: isDark ? Colors.white38 : Colors.grey[500]),
                const SizedBox(width: 4),
                ClockBuilder(
                  builder: (_) => Text(
                    'وصل ${FormatHelper.formatDateTime(request.createdAt)}',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: isDark ? Colors.white38 : Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: meta.map((m) => _Chip(text: m, isDark: isDark)).toList(),
            ),
          ],
          if (request.notes != null) ...[
            const SizedBox(height: 8),
            Text(request.notes!,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 12.5, color: isDark ? Colors.white60 : Colors.grey[700])),
          ],
          if (request.customAnswers.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...request.customAnswers.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.grey[700]),
                      children: [
                        TextSpan(text: '${a.label}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: a.value),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('رفض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('قبول', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Chip({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? _kPrimary.withValues(alpha: 0.18) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF3730A3))),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const _EmptyState({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _kPrimary),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600])),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              ),
            ],
            if (secondaryActionLabel != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
