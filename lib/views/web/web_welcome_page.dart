// lib/views/web/web_welcome_page.dart
//
// spec 055 — أول شاشة على الويب لمن لم يسجّل دخوله: ترحيب هادئ + كشف الحضور
// وهو بيتعلّم + زر واحد. مفيش تسجيل ولا تجربة (الدخول بحساب التطبيق فقط).
import 'package:flutter/material.dart';

import 'package:active_class/views/web/web_auth_widgets.dart';
import 'package:active_class/views/web/web_login_page.dart';

class WebWelcomePage extends StatelessWidget {
  const WebWelcomePage({super.key});

  void _goLogin(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WebLoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: WebAuthPalette.ink,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 960;
            final pad = wide ? 56.0 : 20.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Flexible(child: WebBrandMark()),
                              const Spacer(),
                              if (wide)
                                TextButton(
                                  onPressed: () => openWebSupport(
                                      'مرحبًا، عايز أفعّل نسخة الويب من Active Class على حسابي.'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: WebAuthPalette.mist),
                                  child: const Text('اطلب تفعيل الويب',
                                      style: TextStyle(
                                          fontFamily: 'Cairo', fontSize: 14)),
                                ),
                            ],
                          ),
                          SizedBox(height: wide ? 72 : 36),
                          wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                        flex: 5, child: _copy(context, wide)),
                                    const SizedBox(width: 56),
                                    const Expanded(
                                        flex: 6,
                                        child: Align(
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: AttendanceRegisterArt())),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _copy(context, wide),
                                    const SizedBox(height: 36),
                                    const AttendanceRegisterArt(),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _copy(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('كشف حضورك،\nعلى شاشة أكبر',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: wide ? 56 : 36,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Text(
              'نفس بيانات تطبيق الموبايل: الحضور والمدفوعات والامتحانات والتقارير. '
              'أي تعديل هنا يوصل لتليفونك، وأي تعديل على التليفون يظهر هنا.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  height: 1.8,
                  color: WebAuthPalette.mist)),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => _goLogin(context),
          autofocus: true,
          style: FilledButton.styleFrom(
            backgroundColor: WebAuthPalette.paper,
            foregroundColor: WebAuthPalette.ink,
            minimumSize: const Size(220, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('تسجيل الدخول',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 14),
        const Text('بنفس رقم التليفون والباسورد اللي في التطبيق.',
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 13, color: WebAuthPalette.mist)),
        if (!wide) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => openWebSupport(
                'مرحبًا، عايز أفعّل نسخة الويب من Active Class على حسابي.'),
            style: TextButton.styleFrom(
                foregroundColor: WebAuthPalette.mist,
                padding: EdgeInsets.zero,
                alignment: AlignmentDirectional.centerStart),
            child: const Text('اطلب تفعيل الويب',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
          ),
        ],
      ],
    );
  }
}
