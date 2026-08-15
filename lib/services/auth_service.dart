// lib/services/auth_service.dart
//
// نظام تسجيل دخول مستقل (رقم تليفون + باسورد) مبني على Supabase
// المستضاف ذاتيًا على VPS المدرس. منفصل تمامًا عن نظام الترخيص
// الحالي (Firebase) — أساس لميزات مستقبلية مبنية على حساب حقيقي.
//
// Supabase مبني على البريد الإلكتروني، فرقم التليفون بيتحوّل داخليًا
// لبريد صناعي (synthetic email) بدون أي إرسال SMS فعلي — المستخدم
// بيشوف "رقم تليفون + باسورد" بس من وجهة نظره.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:active_class/config/supabase_config.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/config/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? _client;
  bool _initializing = false;

  /// تهيئة كسولة — بتتنفذ مرة واحدة بس، وبس لما فعليًا حد يحاول
  /// يسجّل دخول/حساب أو كان مسجّل دخول قبل كده. لو الميزة دي معملهاش
  /// المستخدم استخدام خالص، الدالة دي متتناداش نهائيًا.
  Future<SupabaseClient?> _ensureClient() async {
    if (_client != null) return _client;
    if (_initializing) {
      // تجنّب سباق تهيئة مزدوجة لو اتنادت الدالة مرتين بسرعة
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _client;
    }
    if (!SupabaseConfig.isConfigured) {
      debugPrint('AuthService: Supabase غير مُعدّ بعد — راجع supabase_config.dart');
      return null;
    }
    _initializing = true;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
    } catch (e) {
      debugPrint('AuthService: فشل تهيئة Supabase — $e');
      _client = null;
    } finally {
      _initializing = false;
    }
    return _client;
  }

  /// لو المستخدم سجّل دخول قبل كده، نحاول نستعيد الجلسة بصمت (بدون
  /// ما نجبر أي حد فتح التطبيق عادي على تحميل Supabase).
  Future<User?> tryRestoreSession() async {
    final hasLoggedInBefore =
        await DatabaseService().getSetting(SETTING_HAS_LOGGED_IN_BEFORE);
    if (hasLoggedInBefore != 'true') return null;
    final client = await _ensureClient();
    return client?.auth.currentUser;
  }

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  /// عميل Supabase — بيُستخدم برضه من TeamModeService/SyncEngine بعد
  /// ما يكون فيه جلسة دخول شغالة بالفعل. لسه كسول (بينادي نفس
  /// _ensureClient) عشان مفيش تهيئة إضافية.
  Future<SupabaseClient?> ensureClient() => _ensureClient();

  String _phoneToSyntheticEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@app.local';
  }

  String? validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'رقم التليفون غير صحيح';
    }
    return null;
  }

  String? validatePassword(String password) {
    if (password.length < 6) return 'الباسورد لازم يكون 6 أحرف على الأقل';
    return null;
  }

  /// إنشاء حساب جديد برقم تليفون + باسورد. بترجع رسالة خطأ بالعربي،
  /// أو null لو نجحت العملية.
  Future<String?> register({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    final phoneErr = validatePhone(phone);
    if (phoneErr != null) return phoneErr;
    final passErr = validatePassword(password);
    if (passErr != null) return passErr;

    final client = await _ensureClient();
    if (client == null) return 'تعذر الاتصال بسيرفر الحسابات — تأكد من الإعدادات';

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final res = await client.auth.signUp(
        email: _phoneToSyntheticEmail(phone),
        password: password,
        data: {
          'phone': digits,
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
      );
      if (res.user == null) return 'تعذر إنشاء الحساب — حاول مرة أخرى';
      await _markLoggedIn();
      return null;
    } catch (e) {
      return _mapAnyError(e);
    }
  }

  /// تسجيل الدخول برقم تليفون + باسورد.
  Future<String?> signIn({
    required String phone,
    required String password,
  }) async {
    final phoneErr = validatePhone(phone);
    if (phoneErr != null) return phoneErr;
    if (password.isEmpty) return 'أدخل الباسورد';

    final client = await _ensureClient();
    if (client == null) return 'تعذر الاتصال بسيرفر الحسابات — تأكد من الإعدادات';

    try {
      final res = await client.auth.signInWithPassword(
        email: _phoneToSyntheticEmail(phone),
        password: password,
      );
      if (res.user == null) return 'رقم التليفون أو الباسورد غير صحيح';
      await _markLoggedIn();
      return null;
    } catch (e) {
      return _mapAnyError(e);
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<void> _markLoggedIn() async {
    await DatabaseService().setSetting(SETTING_HAS_LOGGED_IN_BEFORE, 'true');
  }

  /// بيحاول يفهم رسالة الخطأ الحقيقية من أي نوع استثناء (مش بس
  /// AuthException) — على الويب تحديدًا Supabase أحيانًا بيرمي نوع
  /// استثناء تاني (مش AuthException) حتى لو السيرفر رد برسالة واضحة،
  /// فبنعتمد على نص الرسالة نفسه بدل ما نفترض النوع.
  String _mapAnyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'رقم التليفون أو الباسورد غير صحيح';
    }
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('user_already_exists')) {
      return 'رقم التليفون ده مسجّل بحساب بالفعل';
    }
    if (msg.contains('password')) {
      return 'الباسورد لازم يكون 6 أحرف على الأقل';
    }
    if (e is AuthException) {
      return 'حدث خطأ: ${e.message}';
    }
    // لو مش قادرين نحدد سبب واضح من نص الرسالة، نفترض إنها مشكلة اتصال
    // (أقرب احتمال لأي استثناء غير معروف الشكل).
    return 'تعذر الاتصال بسيرفر الحسابات — تأكد من الإنترنت';
  }
}
