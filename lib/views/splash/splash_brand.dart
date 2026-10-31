// lib/views/splash/splash_brand.dart
//
// واجهة السبلاش (بلا منطق): شعار يظهر بحركة واحدة هادية، اسم وشعار نصي،
// وشريط تقدّم رفيع. منطق التوجيه فضل في splash_page.dart زي ما هو.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';

class SplashBrand extends StatefulWidget {
  const SplashBrand({super.key, required this.title, required this.tagline, this.status});

  final String title;
  final String tagline;

  /// رسالة حالة (مثلاً "جاري التحقق من الترخيص...")؛ null = بلا رسالة.
  final String? status;

  @override
  State<SplashBrand> createState() => _SplashBrandState();
}

class _SplashBrandState extends State<SplashBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _logo =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<double> _text = CurvedAnimation(
      parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOut));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // احترام إعداد "تقليل الحركة": نعرض الحالة النهائية فورًا.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryColor, Color(0xFF312E81)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          const Spacer(flex: 5),
          // الشعار: ظهور + تكبير بسيط (الحركة الوحيدة في الشاشة)
          AnimatedBuilder(
            animation: _logo,
            builder: (_, child) => Opacity(
              opacity: _logo.value,
              child: Transform.scale(scale: 0.88 + 0.12 * _logo.value, child: child),
            ),
            child: Semantics(
              label: widget.title,
              image: true,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                alignment: Alignment.center,
                child: Image.asset('assets/icon/logo_foreground.png',
                    width: 92, height: 92, excludeFromSemantics: true),
              ),
            ),
          ),
          const SizedBox(height: 26),
          FadeTransition(
            opacity: _text,
            child: Column(children: [
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(widget.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.88))),
              ),
            ]),
          ),
          const Spacer(flex: 4),
          // شريط تقدّم رفيع + رسالة الحالة (لو فيه)
          Semantics(
            liveRegion: true,
            label: widget.status ?? 'جاري التحميل',
            child: Column(children: [
              SizedBox(
                width: 132,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: widget.status == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Text(widget.status ?? '',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.82))),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}
