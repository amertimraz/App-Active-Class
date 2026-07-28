// lib/services/update_service.dart
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// معلومات إصدار جديد متاح على GitHub Releases.
class UpdateInfo {
  final String version; // e.g. "1.2.0"
  final String? apkUrl; // رابط تحميل ملف الـ APK مباشرة
  final String htmlUrl; // رابط صفحة الإصدار على GitHub
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.htmlUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  // TODO: غيّر ده لو غيّرت اسم الـ repo على GitHub
  static const String _owner = 'amertimraz';
  static const String _repo = 'App-Active-Class';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  final Dio _dio = Dio();

  /// يتحقق من وجود إصدار أحدث على GitHub. بيرجّع null بهدوء لو مفيش
  /// تحديث، أو لو فشل الاتصال — التحقق ده لازم يكون شفاف تمامًا للمعلم
  /// وميأثرش على استخدام التطبيق العادي.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        _apiUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      if (data is! Map) return null;

      final tagName = (data['tag_name'] as String?) ?? '';
      final remoteVersion = _stripVPrefix(tagName);
      if (remoteVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(remoteVersion, currentVersion) <= 0) {
        return null; // مفيش إصدار أحدث
      }

      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        // نفضّل نسخة arm64-v8a (بتغطي كل الموبايلات الحديثة تقريبًا)،
        // وإلا أي ملف APK تاني موجود في الإصدار.
        Map? preferred;
        Map? fallback;
        for (final a in assets) {
          if (a is! Map) continue;
          final name = (a['name'] as String?) ?? '';
          if (!name.toLowerCase().endsWith('.apk')) continue;
          fallback ??= a;
          if (name.toLowerCase().contains('arm64')) {
            preferred = a;
            break;
          }
        }
        final chosen = preferred ?? fallback;
        apkUrl = chosen?['browser_download_url'] as String?;
      }

      return UpdateInfo(
        version: remoteVersion,
        apkUrl: apkUrl,
        htmlUrl: (data['html_url'] as String?) ??
            'https://github.com/$_owner/$_repo/releases/latest',
        releaseNotes: (data['body'] as String?)?.trim() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String _stripVPrefix(String v) {
    final t = v.trim();
    return t.startsWith('v') || t.startsWith('V') ? t.substring(1) : t;
  }

  /// مقارنة إصدارين على شكل "1.2.0" — بترجع > 0 لو [a] أحدث من [b].
  int _compareVersions(String a, String b) {
    final pa = a.split('+').first.split('.');
    final pb = b.split('+').first.split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
      final nb = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
      if (na != nb) return na - nb;
    }
    return 0;
  }
}
