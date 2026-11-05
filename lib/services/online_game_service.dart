// lib/services/online_game_service.dart
//
// الألعاب الإلكترونية (داخل الامتحان الإلكتروني) — نشر/إغلاق/حذف ولوحة
// الترتيب عبر Firestore، بنفس نمط OnlineExamService: {slug} مشتق من كود
// الترخيص، مصادقة مجهولة، الحماية في معرفة الـslug + {code}_{last4}.
//
// المسارات (منفصلة تمامًا عن مستندات الامتحانات):
//   online_exams/{slug}/games/{gameId}            ← قراءة عامة، كتابة المالك
//   online_exams/{slug}/games/{gameId}/scores/{code}_{last4}
//        ← الطالب بيكتب أفضل نتيجة له بس، والمدرس بس هو اللي بيعدّد القائمة
//
// ⚠️ مستند اللعبة بيحمل مفتاح الإجابة عمدًا (راجع online_game_model.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/services/online_exam_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/services/team_mode_service.dart';

class OnlineGameService {
  static final OnlineGameService _instance = OnlineGameService._internal();
  factory OnlineGameService() => _instance;
  OnlineGameService._internal();

  /// رابط اللعبة اللي بيتبعت للطلاب. بنستخدم query بدل مسار عشان الصفحة
  /// دليل ثابت (game/index.html) من غير ما نعدّل إعدادات السيرفر.
  static String linkFor(String slug, String gameId) =>
      'active-class.online/game/?s=$slug&g=$gameId';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  Future<String> slug() => OnlineExamService().effectiveSlug();

  CollectionReference<Map<String, dynamic>> _games(String slug) =>
      _db.collection('online_exams').doc(slug).collection('games');

  /// ينشر لعبة جديدة ويرجّع معرّفها. المدرس بيضمن مستند الجذر
  /// (online_exams/{slug}) اللي قواعد الأمان بتشتق منه صلاحية الكتابة؛
  /// المساعد المفوَّض بيكتب تحت games/** بس.
  Future<String> publish({
    required String title,
    required OnlineGameType type,
    required int secondsPerQuestion,
    required List<String> allowedGroupNames,
    required List<GameQuestion> questions,
  }) async {
    await _ensureAuth();
    final s = await slug();
    if (!TeamModeService().isAssistant) {
      await ParentPortalService().publishProfile();
      await _db.collection('online_exams').doc(s).set({
        'ownerUid': _auth.currentUser?.uid,
        'deviceId': LicenseController.to.deviceId.value,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    final id = 'g${DateTime.now().millisecondsSinceEpoch}';
    await _games(s).doc(id).set({
      ...OnlineGame.cloudContent(
        title: title,
        type: type,
        secondsPerQuestion: secondsPerQuestion,
        allowedGroupNames: allowedGroupNames,
        questions: questions,
      ),
      'status': 'open',
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// كل ألعاب المدرس (الأحدث أولًا).
  Future<List<OnlineGame>> listGames() async {
    await _ensureAuth();
    final s = await slug();
    final snap = await _games(s).get();
    final games = snap.docs.map((d) {
      final data = d.data();
      return OnlineGame.fromCloud(d.id, data,
          createdAt: (data['publishedAt'] as Timestamp?)?.toDate());
    }).toList();
    games.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return games;
  }

  /// قفل/فتح اللعبة — القواعد بترفض تسجيل نتيجة جديدة لو مقفولة.
  Future<void> setOpen(String gameId, bool open) async {
    await _ensureAuth();
    final s = await slug();
    await _games(s).doc(gameId).set({
      'status': open ? 'open' : 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<GameScore>> fetchScores(String gameId) async {
    await _ensureAuth();
    final s = await slug();
    final snap = await _games(s).doc(gameId).collection('scores').get();
    return GameScore.ranked(snap.docs.map((d) => GameScore.fromCloud(d.data(),
        updatedAt: (d.data()['updatedAt'] as Timestamp?)?.toDate())));
  }

  /// يحذف اللعبة ونتايجها. Best-effort على النتايج (batch حد 500 عملية).
  Future<void> delete(String gameId) async {
    await _ensureAuth();
    final s = await slug();
    final ref = _games(s).doc(gameId);
    try {
      final scores = await ref.collection('scores').get();
      var batch = _db.batch();
      var n = 0;
      for (final d in scores.docs) {
        batch.delete(d.reference);
        if (++n >= 400) {
          await batch.commit();
          batch = _db.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      debugPrint('OnlineGameService.delete($gameId) scores failed — $e');
    }
    await ref.delete();
  }
}
