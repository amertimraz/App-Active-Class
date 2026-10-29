// lib/services/announcement_service.dart
//
// spec 054 — قراءة الإعلانات: Firestore (المقدمة، لحظي) + REST عام (الخلفية)
// + كاش محلي للأوفلاين. أي فشل صامت (debugPrint) — الإعلانات ميزة اختيارية.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/announcement_model.dart';

const String kAnnCacheKey = 'ann_cache';
const String kAnnPlanKey = 'ann_plan';
const String kAnnNotifiedKey = 'ann_notified';
const String kAnnPopupSeenKey = 'ann_popup_seen';
String annDismissKey(AnnouncementPlacement p) => 'ann_dismiss_${p.name}';

const String _kProjectId = 'active-class-72e0f';

class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  /// بث لحظي للإعلانات المنشورة (حد أقصى 20). الأخطاء بتتبلع.
  Stream<List<Announcement>> watch() {
    return FirebaseFirestore.instance
        .collection('announcements')
        .where('status', isEqualTo: 'published')
        .limit(20)
        .snapshots()
        .map((s) => [
              for (final d in s.docs) Announcement.fromMap(d.id, d.data())
            ]);
  }

  Future<List<Announcement>> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kAnnCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      return [for (final e in list) Announcement.fromJson(jsonEncode(e))];
    } catch (e) {
      debugPrint('AnnouncementService.loadCache فشل: $e');
      return const [];
    }
  }

  Future<void> saveCache(List<Announcement> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          kAnnCacheKey, jsonEncode([for (final a in items) a.toJson()]));
    } catch (e) {
      debugPrint('AnnouncementService.saveCache فشل: $e');
    }
  }

  /// قراءة REST عامة (بدون مصادقة) — للمهمة الخلفية بدل تهيئة Firebase كاملة.
  /// بترجّع المنشور فقط، أو فاضية عند أي فشل.
  Future<List<Announcement>> fetchViaRest(
      {Duration timeout = const Duration(seconds: 15)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$_kProjectId/databases/(default)/documents/announcements?pageSize=20');
      final req = await client.getUrl(uri).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return const [];
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      return parseRestListResponse(body);
    } catch (e) {
      debugPrint('AnnouncementService.fetchViaRest فشل: $e');
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  /// تحليل رد قائمة المستندات (صرف، للاختبار).
  static List<Announcement> parseRestListResponse(String body) {
    final json = jsonDecode(body);
    final docs = json is Map ? json['documents'] : null;
    if (docs is! List) return const [];
    return [
      for (final d in docs)
        if (d is Map<String, dynamic>)
          Announcement.fromRestDocument(d)
    ].where((a) => a.published).toList();
  }
}
