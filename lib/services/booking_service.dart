// lib/services/booking_service.dart
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// طبقة التواصل مع Firestore/Storage الخاصة بميزة "الحجوزات" — صفحة
/// الحجز العامة على الموقع بتقرأ من `teacher_profiles` وتكتب في
/// `booking_requests`، والتطبيق بيسمع لنفس المسارات real-time.
class BookingService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {}
    }
  }

  /// كود عشوائي قصير يُستخدم في رابط الحجز العام — منفصل عن deviceId
  /// عمدًا عشان مانحطش معرّف الجهاز (مرتبط بالترخيص) في رابط عام.
  String generateSlug() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> upsertTeacherProfile({
    required String slug,
    required String deviceId,
    required String name,
    String? photoUrl,
    String? coverUrl,
    String? subject,
    String? title,
    String? bio,
    required bool active,
    required Map<String, dynamic> fields,
    List<Map<String, dynamic>>? customFields,
  }) async {
    await _ensureAuth();
    // ownerUid بيستخدمه Firestore security rules للتحقق إن اللي بيقرا/يمسح
    // طلبات الحجز هو نفس الجهاز اللي فعّل الرابط ده — deviceId وحده مش
    // كفاية كإثبات هوية لأنه مجرد قيمة بيانات ممكن حد يزوّرها.
    await _db.collection('teacher_profiles').doc(slug).set({
      'deviceId': deviceId,
      'ownerUid': _auth.currentUser?.uid,
      'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'subject': subject ?? '',
      'title': title ?? '',
      if (bio != null) 'bio': bio,
      'active': active,
      'fields': fields,
      if (customFields != null) 'customFields': customFields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// يعيد ربط `ownerUid` بالـ uid الحالي لجلسة anonymous auth على الجهاز.
  /// لازم نستدعيها عند كل تشغيل للتطبيق (مش بس لما المعلم يفتح الإعدادات)
  /// لأن إعادة تثبيت التطبيق (مثلاً بعد تحديث بيمسح البيانات) بتولّد uid
  /// جديد، فلو الـ uid القديم فضل مخزّن في Firestore هتترفض كل قراءات
  /// طلبات الحجز بصمت بسبب security rules.
  Future<void> refreshOwnerUid(String slug) async {
    await _ensureAuth();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('teacher_profiles')
        .doc(slug)
        .set({'ownerUid': uid}, SetOptions(merge: true));
  }

  Future<void> setActive(String slug, bool active) async {
    await _ensureAuth();
    await _db
        .collection('teacher_profiles')
        .doc(slug)
        .set({'active': active}, SetOptions(merge: true));
  }

  /// قراءة لمرة واحدة (مش real-time) — تُستخدم عشان نعرض حالة الغلاف/الصورة
  /// الحالية في شاشة الإعدادات من غير ما نفتح listener دائم لسه محتاجينهوش.
  Future<Map<String, dynamic>?> getProfile(String slug) async {
    await _ensureAuth();
    final doc = await _db.collection('teacher_profiles').doc(slug).get();
    return doc.data();
  }

  Future<void> updateCoverUrl(String slug, String coverUrl) async {
    await _ensureAuth();
    await _db
        .collection('teacher_profiles')
        .doc(slug)
        .set({'coverUrl': coverUrl}, SetOptions(merge: true));
  }

  Future<void> updateBio(String slug, String bio) async {
    await _ensureAuth();
    await _db
        .collection('teacher_profiles')
        .doc(slug)
        .set({'bio': bio}, SetOptions(merge: true));
  }

  // نقطة رفع مستضافة على نفس الـ VPS بتاع رابط الحجز — بديل عن Firebase
  // Storage لأن مشروع Firebase على خطة Spark المجانية ومبتدعمش Storage.
  // السر ده ثابت في الكود عمدًا (مش حساس أمنيًا) — أقصى ضرر ممكن لو
  // اتسرّب هو حد يستبدل صورة معلم تاني، مش وصول لبيانات حساسة.
  static const _uploadUrl = 'https://active-class.online/api/upload/photo';
  static const _uploadSecret = '88657c22c85c635ac84ddf4a6a20a3455c082f08e3e8dd47';

  Future<String?> uploadPhoto(String slug, File file, {String kind = 'photo'}) async {
    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'slug': slug,
        'kind': kind,
        'photo': await MultipartFile.fromFile(file.path, filename: 'photo.jpg'),
      });
      final response = await dio.post(
        _uploadUrl,
        data: formData,
        options: Options(headers: {'x-upload-secret': _uploadSecret}),
      );
      return response.data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUploadedImage(String slug, {String kind = 'photo'}) async {
    try {
      final dio = Dio();
      await dio.delete(
        _uploadUrl,
        data: {'slug': slug, 'kind': kind},
        options: Options(headers: {'x-upload-secret': _uploadSecret}),
      );
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRequests(String slug) {
    return _db
        .collection('booking_requests')
        .doc(slug)
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteRequest(String slug, String requestId) async {
    await _ensureAuth();
    await _db
        .collection('booking_requests')
        .doc(slug)
        .collection('requests')
        .doc(requestId)
        .delete();
  }
}
