// lib/services/online_exam_service.dart
//
// spec 016 — نشر/سحب الامتحانات الإلكترونية عبر Firestore، بنفس نمط
// ParentPortalService بالظبط: {slug} مشتق حتميًا من كود الترخيص (يُعاد
// استخدامه من ParentPortalService.ensureSlug)، مصادقة مجهولة، الحماية في
// معرفة الـslug + معرّف المستند {code}_{last4}.
//
// ⚠️ الإجابات الصحيحة **لا تُرفع أبدًا** — toCloudMap على السؤال بيرجّعه
// بدون correctIndex/points. التصحيح كله في ExamController محليًا.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/models/exam_submission_model.dart';
import 'package:active_class/services/parent_portal_service.dart';

/// تسليم طالب كما يُقرأ من السحابة (قبل الربط بطالب محلي والتصحيح).
class CloudSubmission {
  final String code;

  /// مفتاح السؤال (نص "q" + رقم السؤال المحلي) → فهرس اختيار الطالب.
  final Map<String, int> answers;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final bool autoSubmitted;

  const CloudSubmission({
    required this.code,
    required this.answers,
    this.startedAt,
    this.submittedAt,
    this.autoSubmitted = false,
  });
}

class OnlineExamService {
  static final OnlineExamService _instance = OnlineExamService._internal();
  factory OnlineExamService() => _instance;
  OnlineExamService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('OnlineExamService: signInAnonymously failed — $e');
        rethrow;
      }
    }
  }

  Future<String> _slug() => ParentPortalService().ensureSlug();

  DocumentReference<Map<String, dynamic>> _examDoc(String slug, int examId) =>
      _db.collection('online_exams').doc(slug).collection('exams').doc('$examId');

  // ── النشر ───────────────────────────────────────────────────────
  Future<void> publish(
    Exam exam,
    List<ExamQuestion> questions,
    List<AllowedExamStudent> students,
    List<String> allowedGroupNames,
  ) async {
    await _ensureAuth();
    final slug = await _slug();

    // يضمن وجود مستند البروفايل العام (online_exams/{slug} + parent_portal).
    await ParentPortalService().publishProfile();
    await _db.collection('online_exams').doc(slug).set({
      'ownerUid': _auth.currentUser?.uid,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // فحص الهوية على صفحة الطالب بيقرا
    // parent_portal/{slug}/students/{code}_{last4}. نتأكد إن ملخص كل طالب
    // مسموح موجود، وأي ناقص ننشره (best-effort — ما يفشلش النشر بسببه).
    try {
      final studentsCol =
          _db.collection('parent_portal').doc(slug).collection('students');
      for (final st in students) {
        final docId = '${st.code}_${st.last4}';
        final snap = await studentsCol.doc(docId).get();
        if (!snap.exists) {
          await ParentPortalService().pushStudentSummary(st.id);
        }
      }
    } catch (e) {
      debugPrint('OnlineExamService.publish: ensure summaries failed — $e');
    }

    final totalPoints = questions.fold<double>(0, (s, q) => s + q.points);
    final allowedCodes = {for (final st in students) st.code: true};

    await _examDoc(slug, exam.id!).set({
      'title': exam.name,
      'questionCount': questions.length,
      'totalPoints': totalPoints,
      'opensAt': exam.opensAt?.toUtc().toIso8601String(),
      'closesAt': exam.closesAt?.toUtc().toIso8601String(),
      'durationMinutes': exam.durationMinutes,
      'allowedGroupNames': allowedGroupNames,
      'allowedCodes': allowedCodes,
      'questions': questions.map((q) => q.toCloudMap()).toList(),
      'status': 'published',
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unpublish(int examId) async {
    await _ensureAuth();
    final slug = await _slug();
    await _examDoc(slug, examId).delete();
  }

  Future<void> stopNow(int examId, DateTime closesAtUtc) async {
    await _ensureAuth();
    final slug = await _slug();
    await _examDoc(slug, examId).set({
      'status': 'stopped',
      'closesAt': closesAtUtc.toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// تعديل ميعاد/اسم امتحان منشور بدون لمس الأسئلة ولا التسليمات.
  /// بيرجّع الحالة لـ published (لو كانت stopped) بالنافذة الجديدة.
  Future<void> updateSchedule(
    int examId, {
    required DateTime opensAtUtc,
    required DateTime closesAtUtc,
    required int durationMinutes,
    String? title,
  }) async {
    await _ensureAuth();
    final slug = await _slug();
    await _examDoc(slug, examId).set({
      'status': 'published',
      if (title != null) 'title': title,
      'opensAt': opensAtUtc.toUtc().toIso8601String(),
      'closesAt': closesAtUtc.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// تعديل اسم امتحان منشور فقط (بدون تغيير الميعاد).
  Future<void> updateTitle(int examId, String title) async {
    await _ensureAuth();
    final slug = await _slug();
    await _examDoc(slug, examId).set({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteRemote(int examId) async {
    try {
      await _ensureAuth();
      final slug = await _slug();
      final examRef = _examDoc(slug, examId);
      for (final sub in ['submissions', 'attempts']) {
        final snap = await examRef.collection(sub).get();
        // Firestore batch حد أقصى 500 عملية.
        var batch = _db.batch();
        var n = 0;
        for (final d in snap.docs) {
          batch.delete(d.reference);
          if (++n >= 400) {
            await batch.commit();
            batch = _db.batch();
            n = 0;
          }
        }
        if (n > 0) await batch.commit();
      }
      await examRef.delete();
    } catch (e) {
      debugPrint('OnlineExamService.deleteRemote($examId) failed — $e');
    }
  }

  // ── سحب التسليمات ───────────────────────────────────────────────
  Future<List<CloudSubmission>> fetchSubmissions(int examId) async {
    await _ensureAuth();
    final slug = await _slug();
    final examRef = _examDoc(slug, examId);

    final attemptsSnap = await examRef.collection('attempts').get();
    final startedByDoc = <String, DateTime?>{
      for (final d in attemptsSnap.docs)
        d.id: (d.data()['startedAt'] as Timestamp?)?.toDate(),
    };

    final snap = await examRef.collection('submissions').get();
    return snap.docs.map((d) {
      final data = d.data();
      final rawAnswers = (data['answers'] as Map?) ?? const {};
      final answers = <String, int>{};
      rawAnswers.forEach((k, v) {
        if (v is int) answers[k.toString()] = v;
      });
      return CloudSubmission(
        code: (data['code'] as String? ?? '').trim().toUpperCase(),
        answers: answers,
        startedAt: startedByDoc[d.id],
        submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
        autoSubmitted: data['autoSubmitted'] as bool? ?? false,
      );
    }).toList();
  }
}
