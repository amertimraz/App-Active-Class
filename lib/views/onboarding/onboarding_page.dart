// lib/views/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/views/home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String prefsKey = 'has_seen_onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.groups_rounded,
      color: Color(0xFFFF4D7A),
      title: 'نظّم فصولك في مجموعات',
      subtitle: 'أنشئ مجموعة لكل فصل أو صف، وحدّد موعده ورسومه الشهرية بسهولة',
    ),
    _OnboardingSlide(
      icon: Icons.person_rounded,
      color: Color(0xFF23A6F0),
      title: 'أضف طلابك وتابع بياناتهم',
      subtitle:
          'كل طالب له كود QR خاص به، وبيانات ولي أمره، وسجل حضور ومدفوعات مستقل',
    ),
    _OnboardingSlide(
      icon: Icons.fact_check_rounded,
      color: Color(0xFF5B67F1),
      title: 'سجّل الحضور والمدفوعات بسهولة',
      subtitle: 'تابع حضور كل حصة وسجّل الدفعات الشهرية في ثواني',
    ),
    _OnboardingSlide(
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFF10B981),
      title: 'استخدم QR للمسح السريع',
      subtitle:
          'اطبع أكواد QR لطلابك وسجّل الحضور أو الدفع بمسح سريع بدل البحث اليدوي',
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _finish,
                child: const Text('تخطي',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? _slides[_index].color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast ? 'ابدأ الآن' : 'التالي',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
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

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 76, color: slide.color),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
