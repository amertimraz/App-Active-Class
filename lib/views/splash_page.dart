import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/views/home_page.dart';
import 'package:active_class/views/license/plans_page.dart';
import 'package:active_class/views/onboarding/onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // انتظر حد أدنى لعرض الـ splash
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // انتظر حتى يكتمل فحص الترخيص
    final lc = LicenseController.to;
    int waited = 0;
    while (lc.state.value == LicenseState.loading && waited < 6000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waited += 200;
    }

    if (!mounted) return;

    switch (lc.state.value) {
      case LicenseState.active:
      case LicenseState.trial:
        await _goHomeOrOnboarding();
        break;
      case LicenseState.trialExpired:
      case LicenseState.expired:
      case LicenseState.suspended:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PlansPage()));
        break;
      case LicenseState.loading:
        // timeout — نذهب للهوم كـ fallback
        await _goHomeOrOnboarding();
        break;
    }
  }

  /// يعرض الشرح التعريفي مرة واحدة بس (أول تشغيل)، وبعدها يروح للرئيسية مباشرة.
  Future<void> _goHomeOrOnboarding() async {
    bool seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(OnboardingPage.prefsKey) ?? false;
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => seen ? const HomePage() : const OnboardingPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              Color(0xFF312E81),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/logo_foreground.png',
                    width: 74,
                    height: 74,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                APP_NAME,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'إدارة الفصول والحضور والمدفوعات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 36),

              // Checking license indicator
              Obx(() {
                final lc = LicenseController.to;
                if (lc.state.value == LicenseState.loading) {
                  return Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('جاري التحقق من الترخيص...',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  );
                }
                return const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
