// lib/controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:active_class/services/auth_service.dart';
import 'package:active_class/services/team_mode_service.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final AuthService _service = AuthService();

  final isLoggedIn = false.obs;
  final currentPhone = RxnString();
  final currentDisplayName = RxnString();
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSilently();
  }

  Future<void> _restoreSilently() async {
    final user = await _service.tryRestoreSession();
    _applyUser(user);
  }

  void _applyUser(User? user) {
    if (user == null) {
      isLoggedIn.value = false;
      currentPhone.value = null;
      currentDisplayName.value = null;
      return;
    }
    isLoggedIn.value = true;
    currentPhone.value = user.userMetadata?['phone'] as String?;
    currentDisplayName.value = user.userMetadata?['display_name'] as String?;
  }

  /// بترجع رسالة خطأ بالعربي، أو null لو نجحت العملية.
  Future<String?> register({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    loading.value = true;
    try {
      // إعدادات "وضع الفريق" مخزّنة على مستوى الجهاز مش الحساب — لازم
      // نصفّرها الأول لو كان فيه حساب سابق مسجّل دخول على نفس الجهاز
      // (زي وقت الاختبار بحسابين على تليفون واحد)، عشان حساب جديد
      // ميوَرثش فريق حساب قبله بالغلط.
      await TeamModeService().resetForAccountSwitch();
      final err = await _service.register(
        phone: phone,
        password: password,
        displayName: displayName,
      );
      if (err == null) _applyUser(_service.currentUser);
      return err;
    } finally {
      loading.value = false;
    }
  }

  Future<String?> signIn({
    required String phone,
    required String password,
  }) async {
    loading.value = true;
    try {
      await TeamModeService().resetForAccountSwitch();
      final err = await _service.signIn(phone: phone, password: password);
      if (err == null) {
        _applyUser(_service.currentUser);
        await TeamModeService().restoreForCurrentUser();
      }
      return err;
    } finally {
      loading.value = false;
    }
  }

  Future<void> signOut() async {
    await TeamModeService().disable();
    await _service.signOut();
    _applyUser(null);
  }
}
