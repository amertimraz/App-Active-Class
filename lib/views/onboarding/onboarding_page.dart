// lib/views/onboarding/onboarding_page.dart
//
// الشرح التعريفي (أول تشغيل): 4 شرايح برسومات مصغّرة من التطبيق نفسه، تخطّي
// ورجوع (مبدأ حرية المستخدم)، فاتح/داكن، ومؤشر شرائح بوصف للقارئ الصوتي.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/views/home_page.dart';
import 'package:active_class/views/onboarding/onboarding_illustrations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String prefsKey = 'has_seen_onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingSlide {
  final Widget art;
  final String title;
  final String subtitle;
  const _OnboardingSlide(
      {required this.art, required this.title, required this.subtitle});
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = [
    _OnboardingSlide(
      art: GroupsIllustration(),
      title: 'نظّم فصولك في مجموعات',
      subtitle: 'مجموعة لكل فصل أو صف، بموعدها ورسومها الشهرية',
    ),
    _OnboardingSlide(
      art: StudentIllustration(),
      title: 'ملف كامل لكل طالب',
      subtitle: 'بيانات الطالب وولي أمره وكود QR خاص بيه، وسجل حضور ومدفوعات مستقل',
    ),
    _OnboardingSlide(
      art: AttendanceIllustration(),
      title: 'حضور ومدفوعات في ثواني',
      subtitle: 'سجّل حاضر أو متأخر أو غائب، وتابع اللي دفع واللي متبقي عليه',
    ),
    _OnboardingSlide(
      art: ScanIllustration(),
      title: 'امسح QR بدل البحث اليدوي',
      subtitle: 'اطبع أكواد طلابك وسجّل الحضور أو الدفع بمسحة واحدة',
    ),
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingPage.prefsKey, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  void _go(int delta) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = (_index + delta).clamp(0, _slides.length - 1);
    if (reduce) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(target,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isLast = _index == _slides.length - 1;
    final ink = dark ? Colors.white : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFB6BFD6) : const Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // ── الشريط العلوي: رجوع (في البداية) وتخطّي (في النهاية) ──────
            SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 4),
                if (_index > 0)
                  Semantics(
                    button: true,
                    label: 'الشريحة السابقة',
                    child: IconButton(
                      onPressed: () => _go(-1),
                      iconSize: 24,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(Icons.arrow_forward_rounded, color: ink),
                    ),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                if (!isLast)
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        foregroundColor: sub,
                        padding: const EdgeInsets.symmetric(horizontal: 16)),
                    child: const Text('تخطّي',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 4),
              ]),
            ),

            // ── الشرايح ────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 250, child: s.art),
                            const SizedBox(height: 28),
                            Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                  color: ink),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  height: 1.7,
                                  color: sub),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── مؤشر الشرايح ───────────────────────────────────────────
            Semantics(
              label: 'الشريحة ${_index + 1} من ${_slides.length}',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? kOnbIndigo
                            : (dark ? Colors.white24 : const Color(0xFFC7CBD6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── زرار الإجراء الرئيسي (واحد بس) ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: isLast ? _finish : () => _go(1),
                  style: FilledButton.styleFrom(
                    backgroundColor: kOnbIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast ? 'ابدأ الآن' : 'التالي',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
