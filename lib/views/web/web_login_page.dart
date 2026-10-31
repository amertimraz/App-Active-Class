// lib/views/web/web_login_page.dart
//
// spec 055 (T033) — تسجيل الدخول على الويب: رقم التليفون + باسورد فقط، بنفس
// حساب التطبيق (AuthController.signIn). مفيش تسجيل جديد ولا تجربة مجانية.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/web_login_notice.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/views/splash_page.dart';
import 'package:active_class/views/web/web_auth_widgets.dart';
import 'package:active_class/widgets/phone_field.dart'
    show PhoneSanitizerFormatter;

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    final err = await AuthController.to
        .signIn(phone: _phone.text, password: _pass.text);
    if (!mounted) return;
    if (err == null) {
      // الدخول نجح — لو الفريق ماتحمّلش نعرض السبب بدل تطبيق فاضي.
      final notice = webLoginNoticeFor(TeamModeService().restoreStatus,
          detail: TeamModeService().restoreDetail);
      if (notice != null) {
        await AuthController.to.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _notice = notice;
        });
        return;
      }
      // نرجع للسبلاش: هو اللي بيقرر الشاشة الجاية بعد ما بقى فيه جلسة.
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()), (_) => false);
      return;
    }
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0E2B) : WebAuthPalette.paper;
    final fg = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? WebAuthPalette.mist : const Color(0xFF475569);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final form = _form(context, fg, muted, dark, wide);
          if (!wide) {
            return SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: form))));
          }
          return Row(children: [
            // لوحة الحبر: نفس كشف الحضور مكتمل (هو الرابط البصري بين الشاشتين).
            Expanded(
              flex: 5,
              child: Container(
                color: WebAuthPalette.ink,
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WebBrandMark(),
                    const Spacer(),
                    const Text('أهلًا بيك تاني.\nشغلك مستنيك زي ما سيبته.',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 32,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 32),
                    const AttendanceRegisterArt(animate: false, maxWidth: 440),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: form)),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _form(
      BuildContext context, Color fg, Color muted, bool dark, bool wide) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed:
                  _loading ? null : () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('رجوع',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
              style: TextButton.styleFrom(foregroundColor: muted),
            ),
          ),
          if (!wide) ...[
            const SizedBox(height: 8),
            WebBrandMark(color: fg),
          ],
          SizedBox(height: wide ? 24 : 28),
          Semantics(
            header: true,
            child: Text('سجّل دخولك',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: fg)),
          ),
          const SizedBox(height: 8),
          Text(
              'بنفس رقم التليفون والباسورد اللي بتدخل بيهم تطبيق Active Class.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  height: 1.7,
                  color: muted)),
          const SizedBox(height: 28),
          _label('رقم التليفون', fg),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [PhoneSanitizerFormatter()],
            style: _fieldStyle(fg),
            decoration: _decoration('01xxxxxxxxx', dark),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _passFocus.requestFocus(),
          ),
          const SizedBox(height: 18),
          _label('الباسورد', fg),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            focusNode: _passFocus,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            style: _fieldStyle(fg),
            decoration: _decoration('••••••', dark).copyWith(
              suffixIcon: IconButton(
                tooltip: _obscure ? 'إظهار الباسورد' : 'إخفاء الباسورد',
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: muted),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) {
              TextInput.finishAutofillContext();
              _submit();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      AppTheme.errorColor.withValues(alpha: dark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 20, color: AppTheme.errorColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              height: 1.6,
                              color: dark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C))),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: WebAuthPalette.marker
                      .withValues(alpha: dark ? 0.16 : 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20,
                        color: dark
                            ? WebAuthPalette.marker
                            : const Color(0xFF92400E)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_notice!,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              height: 1.7,
                              color: dark
                                  ? Colors.white
                                  : const Color(0xFF78350F))),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: WebAuthPalette.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('جاري الدخول…',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ])
                : const Text('دخول',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                final p = _phone.text.trim();
                openWebSupport(
                    'مرحبًا، أنا مدرس ناسي باسورد حسابي في Active Class.'
                    '${p.isEmpty ? '' : '\nرقم التليفون المسجل: $p'}'
                    '\nبرجاء إعادة تعيين الباسورد.');
              },
              style: TextButton.styleFrom(foregroundColor: muted),
              child: const Text('نسيت الباسورد؟ كلّمنا على واتساب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
              'معندكش حساب؟ اعمل حساب من تطبيق الموبايل وفعّل وضع الفريق، وبعدها ادخل من هنا.',
              textAlign: TextAlign.start,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.7,
                  color: muted)),
        ],
      ),
    );
  }

  Widget _label(String t, Color fg) => Text(t,
      style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: fg));

  TextStyle _fieldStyle(Color fg) =>
      TextStyle(fontFamily: 'Cairo', fontSize: 16, color: fg);

  InputDecoration _decoration(String hint, bool dark) {
    final line = dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: dark ? Colors.white30 : Colors.black26),
      filled: true,
      fillColor: dark ? const Color(0xFF1B1A45) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(line),
      enabledBorder: b(line),
      focusedBorder: b(WebAuthPalette.brand, 2),
    );
  }
}
