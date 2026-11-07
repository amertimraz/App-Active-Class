import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/views/web/web_welcome_page.dart';
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
    // حد أدنى قصير لعرض الـ splash (كان 1.4 ثانية).
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // spec 055: على الويب مفيش استخدام من غير حساب — لو مفيش جلسة دخول،
    // نعرض شاشة الترحيب/الدخول (مسار أندرويد مالوش علاقة).
    if (kIsWeb) {
      User? user;
      try {
        user = await AuthService().tryRestoreSession();
      } catch (_) {}
      if (!mounted) return;
      if (user == null) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WebWelcomePage()));
        return;
      }
    }

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
        // فتح سريع بالحالة المحفوظة: التحقق الفعلي لسه شغّال في الخلفية.
        // لو طلع الترخيص موقوف/منتهي بعد ما فتحنا، نحوّل لشاشة الباقات.
        final pendingCheck = lc.startedOptimistically && !lc.initCompleted.value;
        await _goHomeOrOnboarding();
        if (pendingCheck) _redirectIfRevoked(lc);
        break;
      case LicenseState.trialExpired:
      case LicenseState.expired:
      case LicenseState.suspended:
        if (!await _teamOverridesLicense()) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PlansPage()));
          break;
        }
        await _goHomeOrOnboarding();
        break;
      case LicenseState.loading:
        // timeout — نذهب للهوم كـ fallback
        await _goHomeOrOnboarding();
        break;
    }
  }

  /// لو الجهاز ده مساعد (أو مدرس) في فريق كان مفعّل قبل كده، ترخيصه الشخصي
  /// (تجربة منتهية مثلاً) مش المرجع — ترخيص صاحب الفريق هو اللي بيتحقق منه
  /// على السيرفر. نستنى شوية (TeamModeService.init() بيشتغل في الخلفية من
  /// main.dart) قبل ما نحكم. true = الفريق مفعّل فمنعرضش شاشة التجديد.
  Future<bool> _teamOverridesLicense() async {
    final wasTeamModeOn =
        await DatabaseService().getSetting(SETTING_TEAM_MODE_ENABLED) == 'true';
    if (!wasTeamModeOn) return false;
    final tm = TeamModeService();
    int waitedTeam = 0;
    while (!tm.isEnabled.value && waitedTeam < 5000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waitedTeam += 200;
    }
    return tm.isEnabled.value;
  }

  bool _isBlockedState(LicenseState s) =>
      s == LicenseState.trialExpired ||
      s == LicenseState.expired ||
      s == LicenseState.suspended;

  /// بعد الفتح السريع: لما التحقق الفعلي يخلص ويطلع الترخيص موقوف/منتهي،
  /// نحوّل لشاشة الباقات (نفس سلوك الشاشة قبل الفتح السريع). الـWorker
  /// بيفضل شغّال بعد ما شاشة البداية تتقفل.
  void _redirectIfRevoked(LicenseController lc) {
    Worker? w;
    Future<void> check() async {
      if (!_isBlockedState(lc.state.value)) return;
      if (await _teamOverridesLicense()) return;
      Get.offAll(() => const PlansPage());
    }

    if (lc.initCompleted.value) {
      check();
      return;
    }
    w = ever<bool>(lc.initCompleted, (done) {
      if (!done) return;
      w?.dispose();
      check();
    });
  }

  /// يعرض الشرح التعريفي مرة واحدة بس (أول تشغيل)، وبعدها يروح للرئيسية مباشرة.
  Future<void> _goHomeOrOnboarding() async {
    // الشرح التعريفي مخصوص للموبايل — الويب يدخل الرئيسية على طول.
    bool seen = kIsWeb;
    if (!kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        seen = prefs.getBool(OnboardingPage.prefsKey) ?? false;
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => seen ? const HomePage() : const OnboardingPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        // الرسالة بتظهر بس لو التحقق من الترخيص أخد وقت (مش وميض في كل فتح).
        final loading =
            LicenseController.to.state.value == LicenseState.loading;
        return SplashBrand(
          title: APP_NAME,
          tagline: 'إدارة الفصول والحضور والمدفوعات',
          status: loading && _slow ? 'جاري التحقق من الترخيص...' : null,
        );
      }),
    );
  }
}
