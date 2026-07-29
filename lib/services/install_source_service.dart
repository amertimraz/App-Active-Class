// lib/services/install_source_service.dart
import 'dart:io';
import 'package:flutter/services.dart';

/// يتحقق من مصدر تثبيت التطبيق (Google Play أو تثبيت مباشر) — مهم عشان
/// خاصية التحديث الذاتي (تحميل APK من GitHub) تشتغل بس للمثبّتين مباشرة.
/// نشرها على Google Play وفيها آلية تحديث ذاتي خارج المتجر مخالفة صريحة
/// لسياسات Google Play وممكن تعرّض الحساب للحظر.
class InstallSourceService {
  static const MethodChannel _channel =
      MethodChannel('active_class/install_source');
  static const String _playStorePackage = 'com.android.vending';

  static bool? _cachedIsPlayStore;

  /// بيرجّع true لو التطبيق متثبّت من Google Play. بيرجّع false بأمان
  /// (يعتبره تثبيت مباشر) في أي حالة غموض — لو مش أندرويد، أو الفحص
  /// فشل لأي سبب — عشان خاصية التحديث تفضل شغالة للمثبّتين مباشرة
  /// بدل ما توقف بالغلط بسبب خطأ فني.
  static Future<bool> isInstalledFromPlayStore() async {
    if (_cachedIsPlayStore != null) return _cachedIsPlayStore!;
    if (!Platform.isAndroid) {
      _cachedIsPlayStore = false;
      return false;
    }
    try {
      final installer =
          await _channel.invokeMethod<String>('getInstallerPackageName');
      _cachedIsPlayStore = installer == _playStorePackage;
    } catch (_) {
      _cachedIsPlayStore = false;
    }
    return _cachedIsPlayStore!;
  }
}
