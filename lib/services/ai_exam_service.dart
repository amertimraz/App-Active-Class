// lib/services/ai_exam_service.dart
//
// spec 057 — عميل خدمة ai-worker على السيرفر. بيبعت صور مجهّزة، وبيتابع حالة
// الطلب (polling)، وبيرجّع أسئلة مقترحة. التوكن بتاع جلسة المدرس (Supabase)،
// والمفاتيح السرية كلها على السيرفر. أخطاء الخدمة بتتحوّل لرسايل عربي.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:active_class/models/ai_draft_question.dart';
import 'package:active_class/services/auth_service.dart';

class AiExamException implements Exception {
  final String code;
  final String message;
  const AiExamException(this.code, this.message);
  @override
  String toString() => message;
}

/// رسالة عربي لسبب فشل (من fail_reason على السيرفر أو كود HTTP).
String aiFailMessage(String? reason) => switch (reason) {
      'unreadable' => 'مش قادر أقرا أسئلة من الصورة دي — جرّب صورة أوضح',
      'not_educational' => 'المحتوى ده مش تعليمي — اختار صور امتحان أو درس',
      'quota' => 'حصة الذكاء الاصطناعي الشهرية خلصت',
      'paused' => 'الميزة موقوفة مؤقتًا',
      'busy' => 'الخدمة مشغولة دلوقتي — حاول بعد شوية',
      'timeout' => 'العملية أخدت وقت طويل — حاول تاني',
      'bad_output' => 'حصل خطأ في القراءة — حاول تاني',
      'too_large' => 'الصور كبيرة — قلّل العدد أو الحجم',
      'login' => 'سجّل دخول الأول',
      _ => 'تعذّرت العملية — حاول بعد شوية',
    };

class AiExamService {
  AiExamService._();
  static final AiExamService instance = AiExamService._();

  static const _base = 'https://active-class.online/ai/exam';

  Future<String> _token() async {
    final c = await AuthService().ensureClient();
    var s = c?.auth.currentSession;
    if (c == null || s == null) {
      throw AiExamException('login', aiFailMessage('login'));
    }
    if (s.isExpired) {
      s = (await c.auth.refreshSession()).session;
      if (s == null) throw AiExamException('login', aiFailMessage('login'));
    }
    return s.accessToken;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  AiExamException _httpError(http.Response r) {
    String? err;
    try {
      err = (jsonDecode(r.body) as Map)['error'] as String?;
    } catch (_) {}
    final code = switch (r.statusCode) {
      401 => 'login',
      402 => 'quota',
      403 => 'paused',
      413 => 'too_large',
      503 => 'busy',
      _ => err ?? 'error',
    };
    return AiExamException(code, aiFailMessage(code));
  }

  /// المتبقي من الحصة، أو null لو الخدمة مش متاحة.
  Future<({int remaining, int limit})?> quota() async {
    try {
      final r = await http
          .get(Uri.parse('$_base/quota'), headers: _headers(await _token()))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (remaining: (j['remaining'] as num).toInt(), limit: (j['limit'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  /// يبعت الطلب ويستنى النتيجة. [onProgress] اختياري لتحديث الواجهة.
  /// نفس [jobId] لو اتعاد = نفس الطلب (بدون خصم تاني).
  Future<AiExamResult> run({
    required String mode, // convert | generate
    List<Uint8List> images = const [],
    String text = '',
    int count = 10,
    int? mcqCount, // وضع التوليد: عدد أسئلة الاختيار من متعدد
    int tfCount = 0, // وضع التوليد: عدد أسئلة صح/خطأ
    String difficulty = 'medium',
    String? jobId,
    void Function(String status)? onProgress,
    Duration pollEvery = const Duration(milliseconds: 2500),
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final id = jobId ?? const Uuid().v4();
    final token = await _token();

    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$_base/jobs'),
            headers: _headers(token),
            body: jsonEncode({
              'job_id': id,
              'mode': mode,
              'images': [for (final b in images) base64Encode(b)],
              'text': text,
              'count': count,
              if (mcqCount != null) 'mcq_count': mcqCount,
              'tf_count': tfCount,
              'difficulty': difficulty,
              'language': 'ar',
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw AiExamException('timeout', aiFailMessage('timeout'));
    } catch (_) {
      throw const AiExamException('network', 'مفيش اتصال بالإنترنت — اتأكد وحاول تاني');
    }
    if (r.statusCode != 202 && r.statusCode != 200) throw _httpError(r);

    final deadline = DateTime.now().add(timeout);
    var status = (jsonDecode(r.body) as Map<String, dynamic>);
    while (true) {
      final st = status['status'] as String? ?? 'queued';
      onProgress?.call(st);
      if (st == 'done') {
        return AiExamResult.fromJson(
            Map<String, dynamic>.from(status['result'] as Map));
      }
      if (st == 'failed' || st == 'rejected') {
        final reason = status['fail_reason'] as String?;
        throw AiExamException(reason ?? 'error', aiFailMessage(reason));
      }
      if (DateTime.now().isAfter(deadline)) {
        throw AiExamException('timeout', aiFailMessage('timeout'));
      }
      await Future<void>.delayed(pollEvery);
      try {
        final g = await http
            .get(Uri.parse('$_base/jobs/$id'), headers: _headers(await _token()))
            .timeout(const Duration(seconds: 20));
        if (g.statusCode == 404) {
          throw AiExamException('error', aiFailMessage(null));
        }
        if (g.statusCode == 200) {
          status = jsonDecode(g.body) as Map<String, dynamic>;
        }
      } on AiExamException {
        rethrow;
      } catch (e) {
        // انقطاع لحظي أثناء المتابعة: نكمّل المحاولة لحد المهلة.
        debugPrint('ai poll: $e');
      }
    }
  }
}
