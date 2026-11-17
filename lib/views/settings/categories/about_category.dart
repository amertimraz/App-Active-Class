part of '../settings_page.dart';

// spec 051 — فئة «حول التطبيق والدعم» بتصميم السبورة والكروت:
// سبورة بالإصدار وزر التحديث، كروت الدعم والخصوصية، وكارت قناة المجتمع.

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

Future<void> _openPrivacyPolicy() async {
  final uri = Uri.parse(
      'https://amertimraz.github.io/App-Active-Class/privacy-policy.html');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذر فتح صفحة سياسة الخصوصية');
  }
}

Future<void> _openSupportWhatsApp() => openSupportWhatsApp();

const _kUsageLabels = {
  'portal.student': 'ملخصات طلاب البوابة',
  'portal.profile': 'بروفايل البوابة',
  'device': 'تسجيل الجهاز',
  'exam': 'الامتحانات الإلكترونية',
  'game': 'الألعاب',
  'booking': 'الحجز',
};

Future<void> _showFirestoreUsage(BuildContext context) async {
  final days = await FirestoreUsage.recent();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('كتابات Firestore (على الجهاز ده)'),
      content: SizedBox(
        width: double.maxFinite,
        child: days.isEmpty
            ? const Text('لسه مفيش كتابات متسجّلة.')
            : ListView(shrinkWrap: true, children: [
                for (final d in days) ...[
                  Text('${d.$1} — الإجمالي ${d.$2.values.fold<int>(0, (a, b) => a + b)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final e in (d.$2.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))))
                    Text('  ${_kUsageLabels[e.key] ?? e.key}: ${e.value}'),
                  const SizedBox(height: 8),
                ],
              ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('تمام')),
      ],
    ),
  );
}

class _AboutCategoryPage extends StatelessWidget {
  const _AboutCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    const green = Color(0xFF25D366);
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'حول التطبيق والدعم',
      highlightId: highlightId,
      children: [
        // ── السبورة: الإصدار + تحقق من التحديثات ──
        Material(
          color: t.board,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.board),
            side: BorderSide(color: t.boardLine),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.chalk,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(Icons.info_rounded, color: t.onChalk, size: 24),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.data?.version ?? '—';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Class',
                                style:
                                    AppType.title.copyWith(color: t.boardInk)),
                            // ضغطة مطوّلة = عدّاد كتابات Firestore المحلي (تشخيص).
                            GestureDetector(
                              onLongPress: () => _showFirestoreUsage(context),
                              child: Text('الإصدار $version',
                                  style: AppType.caption
                                      .copyWith(color: t.boardInkSoft)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: () =>
                      checkAndShowUpdateDialog(context, silent: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.chalk,
                    foregroundColor: t.onChalk,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control)),
                  ),
                  icon: const Icon(Icons.system_update_rounded, size: 20),
                  label: const Text('تحقق من التحديثات'),
                ),
                const SizedBox(height: 6),
                Text('ابحث عن نسخة أحدث من التطبيق',
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: t.boardInkSoft)),
              ],
            ),
          ),
        ),
        gap,
        // ── الدعم والخصوصية: كروت ──
        _plainSectionBlock(
          t,
          'عن التطبيق',
          Icons.info_rounded,
          const Color(0xFF64748B),
          _cardGrid([
            _actionCard(
              t,
              icon: Icons.help_outline_rounded,
              color: const Color(0xFFF59E0B),
              title: 'المساعدة والدعم',
              hint: 'تواصل معنا',
              onTap: () => _openSupportWhatsApp(),
            ),
            _actionCard(
              t,
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF10B981),
              title: 'الجديد في التحديث',
              hint: 'آخر ما اتضاف',
              onTap: () => showWhatsNewNow(context),
            ),
            _actionCard(
              t,
              icon: Icons.privacy_tip_outlined,
              color: const Color(0xFF6366F1),
              title: 'سياسة الخصوصية',
              hint: 'كيف نتعامل مع بياناتك',
              onTap: () => _openPrivacyPolicy(),
            ),
          ]),
        ),
        gap,
        // ── قناة المجتمع ──
        _plainSectionBlock(
          t,
          'المجتمع والدعم',
          Icons.forum_rounded,
          green,
          _settingsCard(
            t,
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'قناة التحديثات والدعم — تابع الجديد أول بأول، وشارك مشاكلك واقتراحاتك مع مجتمع المدرسين.',
                    style: AppType.caption
                        .copyWith(color: t.inkSoft, height: 1.7),
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton.icon(
                    onPressed: _openCommunityChannel,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('انضم لقناة التحديثات والدعم'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
