import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/views/home_page.dart';
import 'package:active_class/views/license/plans_page.dart';
import 'package:active_class/views/onboarding/onboarding_page.dart';
import 'package:active_class/views/splash/splash_brand.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final RxBool _slowRx = false.obs;
  bool get _slow => _slowRx.value;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _slowRx.value = true;
    });
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // انتظر حد أدنى لعرض الـ splash
    await Future.delayed(const Duration(milliseconds: 1400));
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
        // لو الجهاز ده مساعد (أو مدرس) في فريق كان مفعّل قبل كده،
        // ترخيصه الشخصي (تجربة منتهية مثلاً) مش المرجع — ترخيص صاحب
        // الفريق هو اللي بيتحقق منه فعليًا على السيرفر. نستنى شوية
        // (TeamModeService.init() بيشتغل في الخلفية من main.dart) قبل
        // ما نحكم بعرض شاشة التجديد، بدل ما نعرضها فورًا لمجرد إن
        // تجربته الشخصية خلصت.
        final wasTeamModeOn =
            await DatabaseService().getSetting(SETTING_TEAM_MODE_ENABLED) ==
                'true';
        if (wasTeamModeOn) {
          final tm = TeamModeService();
          int waitedTeam = 0;
          while (!tm.isEnabled.value && waitedTeam < 5000) {
            await Future.delayed(const Duration(milliseconds: 200));
            waitedTeam += 200;
          }
          if (!mounted) return;
          if (tm.isEnabled.value) {
            await _goHomeOrOnboarding();
            break;
          }
        }
        if (!mounted) return;
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
      body: Obx(() {
        // الرسالة بتظهر بس لو التحقق من الترخيص أخد وقت (مش وميض في كل فتح).
        final loading = LicenseController.to.state.value == LicenseState.loading;
        return SplashBrand(
          title: APP_NAME,
          tagline: 'إدارة الفصول والحضور والمدفوعات',
          status: loading && _slow ? 'جاري التحقق من الترخيص...' : null,
        );
      }),
    );
  }
}
