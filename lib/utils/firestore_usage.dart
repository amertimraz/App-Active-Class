// lib/utils/firestore_usage.dart
//
// عدّاد محلي لكتابات Firestore بحسب المصدر، لآخر 7 أيام. حصة Firestore مشتركة بين
// كل المدرسين وAdmin Console مش بيقول مين كتب، فالعدّاد ده بيبيّن على جهاز المدرس
// نفسه إيه الأكتر استهلاكًا (تقدر تشوفه بضغطة مطوّلة على رقم الإصدار في «حول
// التطبيق»). مفيش أي بيانات بتتبعت — محلي بس. أي فشل في الحفظ بيتجاهل بهدوء.
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FirestoreUsage {
  FirestoreUsage._();

  static const _key = 'fs_write_usage_v1';
  static const _keepDays = 7;

  // يوم → مصدر → عدد
  static final Map<String, Map<String, int>> _data = {};
  static bool _loaded = false;
  static Timer? _flush;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        (jsonDecode(raw) as Map).forEach((day, m) {
          final src = <String, int>{};
          (m as Map).forEach((k, v) => src['$k'] = (v as num).toInt());
          final cur = _data.putIfAbsent('$day', () => {});
          src.forEach((k, v) => cur[k] = (cur[k] ?? 0) + v);
        });
      }
    } catch (_) {}
  }

  /// يسجّل [n] كتابة من [source] (مثلاً 'portal.student').
  static void write(String source, [int n = 1]) {
    if (n <= 0) return;
    final day = _day(DateTime.now());
    final m = _data.putIfAbsent(day, () => {});
    m[source] = (m[source] ?? 0) + n;
    _flush ??= Timer(const Duration(seconds: 8), () {
      _flush = null;
      unawaited(_save());
    });
  }

  static Future<void> _save() async {
    try {
      await _load();
      final days = _data.keys.toList()..sort();
      while (days.length > _keepDays) {
        _data.remove(days.removeAt(0));
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(_data));
    } catch (_) {}
  }

  /// آخر 7 أيام (الأحدث أولًا): [(يوم, {مصدر: عدد})].
  static Future<List<(String, Map<String, int>)>> recent() async {
    await _load();
    await _save();
    final days = _data.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) (d, Map<String, int>.from(_data[d]!))];
  }
}
