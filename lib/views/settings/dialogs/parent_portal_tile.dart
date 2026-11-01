part of '../settings_page.dart';

// spec 051 — بلاطة متابعة أولياء الأمور (نقل حرفي)

/// اتنقل التحكم الكامل (الرابط، QR، النشر، طلاب البوابة، طريقة الدخول) لقسم
/// "بوابة أولياء الأمور" في الرئيسية — هنا بس اختصار بيفتحه.
class _ParentPortalTile extends StatelessWidget {
  final bool isDark;
  final bool expired;
  const _ParentPortalTile({required this.isDark, this.expired = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expired
                ? 'صفحة المتابعة مقفولة على أولياء الأمور لحد ما تجدّد الاشتراك.'
                : 'رابط المتابعة، وكود QR، ونشر البيانات، وإرسال الكود لأولياء الأمور — كله في قسم بوابة أولياء الأمور.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black45),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.toNamed(ROUTE_PARENT_PORTAL),
              icon: const Icon(Icons.family_restroom_rounded, size: 18),
              label: const Text('فتح بوابة أولياء الأمور',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── قسم إعدادات قابل للطي بترويسة واضحة ──────────────────────────────────────
