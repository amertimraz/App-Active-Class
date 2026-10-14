part of '../settings_page.dart';

// spec 051 — فئة «حول التطبيق والدعم» (نقل حرفي)

Widget _buildAboutSection(BuildContext context, bool isDark) {
  return _buildSection(
    context,
    isDark,
    title: 'عن التطبيق',
    icon: Icons.info_rounded,
    color: const Color(0xFF64748B),
    children: [
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '—';
          return _buildInfoTile(
            isDark,
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF4F46E5),
            title: 'الإصدار',
            trailing: version,
          );
        },
      ),
      _buildDivider(isDark),
      _buildNavTile(
        context,
        isDark,
        icon: Icons.system_update_rounded,
        iconColor: const Color(0xFF10B981),
        title: 'تحقق من التحديثات',
        subtitle: 'ابحث عن نسخة أحدث من التطبيق',
        onTap: () => checkAndShowUpdateDialog(context, silent: false),
      ),
      _buildDivider(isDark),
      _buildNavTile(
        context,
        isDark,
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: 'المساعدة والدعم',
        subtitle: 'تواصل معنا',
        onTap: () => _openSupportWhatsApp(),
      ),
      _buildDivider(isDark),
      _buildNavTile(
        context,
        isDark,
        icon: Icons.privacy_tip_outlined,
        iconColor: const Color(0xFF6366F1),
        title: 'سياسة الخصوصية',
        subtitle: 'كيف نتعامل مع بياناتك',
        onTap: () => _openPrivacyPolicy(),
      ),
    ],
  );
}

// spec 017 — قناة واتساب المجتمع (تحديثات + دعم + اقتراحات). رابط ثابت.
const String _kCommunityChannelUrl =
    'https://whatsapp.com/channel/0029VbDFTCsEquiR7nSaO52X';

Future<void> _openCommunityChannel() async {
  try {
    await launchUrl(Uri.parse(_kCommunityChannelUrl),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذّر فتح القناة، حاول تاني');
  }
}

Widget _buildCommunitySection(BuildContext context, bool isDark) {
  return _buildSection(
    context,
    isDark,
    title: 'المجتمع والدعم',
    icon: Icons.forum_rounded,
    color: const Color(0xFF25D366),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قناة التحديثات والدعم — تابع الجديد أول بأول، وشارك مشاكلك واقتراحاتك مع مجتمع المدرسين.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.7,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openCommunityChannel,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('انضم لقناة التحديثات والدعم',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> _openPrivacyPolicy() async {
  final uri = Uri.parse(
      'https://amertimraz.github.io/App-Active-Class/privacy-policy.html');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذر فتح صفحة سياسة الخصوصية');
  }
}

Future<void> _openSupportWhatsApp() async {
  const supportPhone = '201096066818';
  final settings = Get.find<SettingsController>();
  final teacherName = settings.teacherFullName.value.trim();

  final message = StringBuffer()
    ..writeln(
        'مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز مساعدة/دعم فني.');
  if (teacherName.isNotEmpty) {
    message.writeln('الاسم: $teacherName');
  }

  final uri = Uri.parse(
      'https://wa.me/$supportPhone?text=${Uri.encodeComponent(message.toString())}');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذر فتح واتساب');
  }
}

// ─── Tile Builders ────────────────────────────────────────────────────────

class _AboutCategoryPage extends StatelessWidget {
  const _AboutCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CategoryScaffold(
      title: 'حول التطبيق والدعم',
      highlightId: highlightId,
      children: [
        _buildCommunitySection(context, isDark),
        const SizedBox(height: 14),
        _buildAboutSection(context, isDark),
      ],
    );
  }
}
