// lib/services/parent_portal_service.dart
//
// "بوابة متابعة أولياء الأمور" — إضافة مدفوعة منفصلة (parentPortalEnabled
// على مستند الترخيص، تتحكم فيها لوحة الأدمن). لو مفعّلة، بنبعت ملخص خفيف
// بس لكل طالب (نسبة حضور، مدفوعات) لـ Firestore — عشان صفحة عامة بسيطة
// على الموقع تقدر تعرضها لولي الأمر بعد ما يدخل كود الطالب + آخر 4 أرقام
// من رقم تليفونه (حماية من تخمين الأكواد المتسلسلة).
//
// الحماية الفعلية هنا مش قواعد Firestore معقّدة — هي إن الـ document ID
// نفسه مركّب من {code}_{last4} (زي رابط سرّي غير قابل للتخمين لمين
// معندوش الرقمين مع بعض)، فالقاعدة الأمنية بسيطة: قراءة عامة مسموحة،
// بس لازم تعرف الـ ID الصح الأول عشان توصله.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';

class ParentPortalService {
  static final ParentPortalService _instance = ParentPortalService._internal();
  factory ParentPortalService() => _instance;
  ParentPortalService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();
  Worker? _profileWorker;

  static const String _kSlugKey = 'parent_portal_slug';

  /// بتتابع اسم/جنس المدرس وتعيد النشر أول ما يتغيّروا — من غيرها،
  /// البروفايل كان بينشر مرة واحدة بس أول ما شاشة الإعدادات تتفتح،
  /// فلو المدرس غيّر اسمه بعد كده، صفحة المتابعة تفضل باسمه القديم
  /// لحد ما يقفل الإعدادات ويفتحها تاني بالصدفة.
  void _watchProfileChanges() {
    if (_profileWorker != null) return;
    if (!Get.isRegistered<SettingsController>()) return;
    final settings = Get.find<SettingsController>();
    _profileWorker = everAll(
      [settings.teacherFullName, settings.teacherGender],
      (_) => publishProfile(),
    );
  }

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {}
    }
  }

  String _generateSlug() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// رابط المتابعة الثابت للمدرس — بيتولّد مرة واحدة بس ويتخزّن محليًا.
  Future<String> ensureSlug() async {
    var slug = await _dbService.getSetting(_kSlugKey);
    if (slug == null || slug.isEmpty) {
      slug = _generateSlug();
      await _dbService.setSetting(_kSlugKey, slug);
    }
    return slug;
  }

  Future<String?> getSlugIfExists() => _dbService.getSetting(_kSlugKey);

  /// آخر 4 أرقام من رقم ولي الأمر — عمود الحماية الوحيد، فلو رقم
  /// التليفون فاضي أو أقل من 4 أرقام، الطالب ده مينفعش يتنشر خالص
  /// (بدل ما نضعّف الحماية).
  String? _last4(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return null;
    return digits.substring(digits.length - 4);
  }

  /// بتُنشر لوحدها (مش مربوطة بنجاح نشر طالب) — لو مفيش أي طالب عنده
  /// رقم تليفون صحيح لسه، كان المستند ده مبيتعملش خالص، فصفحة المتابعة
  /// تفضل من غير اسم المدرس وكأنها رابط عام مش رابط المدرس ده تحديدًا.
  Future<void> publishProfile() async {
    if (!LicenseController.to.parentPortalEnabled.value) return;
    _watchProfileChanges();
    try {
      await _ensureAuth();
      final slug = await ensureSlug();
      await _publishProfile(slug);
    } catch (_) {}
  }

  Future<void> _publishProfile(String slug) async {
    final settings =
        Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
    await _db.collection('parent_portal').doc(slug).set({
      'teacherName': settings?.teacherFullName.value ?? '',
      'teacherGender': settings?.teacherGender.value ?? 'male',
      'ownerUid': _auth.currentUser?.uid,
      'deviceId': LicenseController.to.deviceId.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// بيبني بيانات ملخص طالب (من غير أي كتابة) — مستخدمة في النشر الفردي
  /// والجماعي مع بعض، عشان منكررش نفس منطق الحساب في مكانين.
  Map<String, dynamic>? _buildSummaryData(
    Student student, {
    required int present,
    required int absent,
    required double totalPaid,
    required String groupName,
  }) {
    final last4 = _last4(student.guardianPhone);
    if (last4 == null) return null;
    final code = student.code.toUpperCase();
    if (code.isEmpty) return null;
    return {
      '_docId': '${code}_$last4',
      'name': student.name,
      'groupName': groupName,
      'present': present,
      'absent': absent,
      'totalPaid': totalPaid,
      'price': student.price,
      'exemptPercent': student.exemptPercent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// بينشر ملخص طالب واحد — بتُستخدم بعد إضافة/تعديل/حذف فردي (حضور،
  /// دفعة، بيانات طالب)، مش للنشر الجماعي (شوف publishAllStudents).
  /// بتتجاهل بصمت لو الميزة مش مفعّلة أو رقم ولي الأمر مش موجود/قصير —
  /// مفيش داعي نزعج المستخدم برسائل خطأ لعملية خلفية اختيارية.
  Future<void> pushStudentSummary(int studentId) async {
    if (!LicenseController.to.parentPortalEnabled.value) return;
    try {
      final student = await _dbService.getStudent(studentId);
      if (student == null) return;

      final attendanceRecords = await _dbService.getAttendanceByStudent(studentId);
      final present =
          attendanceRecords.where((a) => a.status == ATTENDANCE_PRESENT).length;
      final absent =
          attendanceRecords.where((a) => a.status == ATTENDANCE_ABSENT).length;

      final payments = await _dbService.getPaymentsByStudent(studentId);
      final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);

      final group = await _dbService.getGroup(student.groupId);
      final data = _buildSummaryData(student,
          present: present,
          absent: absent,
          totalPaid: totalPaid,
          groupName: group?.name ?? '');
      if (data == null) return;
      final docId = data.remove('_docId') as String;

      await _ensureAuth();
      final slug = await ensureSlug();

      await _db
          .collection('parent_portal')
          .doc(slug)
          .collection('students')
          .doc(docId)
          .set(data);
    } catch (_) {
      // best-effort — مش هنعطّل أي حاجة في التطبيق بسبب فشل نشر خلفي
    }
  }

  /// لازم تُستدعى **قبل** حذف الطالب فعليًا (محتاجين الكود ورقم
  /// التليفون بتاعه للوصول لمستند الملخص) — وإلا بيانات الطالب المحذوف
  /// (اسمه، حضوره، مدفوعاته) تفضل معروضة للأبد لمين يعرف الكود والرقم،
  /// حتى بعد ما يتمسح من التطبيق تمامًا.
  Future<void> removeStudentSummary(Student student) async {
    if (!LicenseController.to.parentPortalEnabled.value) return;
    try {
      final last4 = _last4(student.guardianPhone);
      if (last4 == null) return;
      final code = student.code.toUpperCase();
      if (code.isEmpty) return;
      final slug = await getSlugIfExists();
      if (slug == null) return;
      await _db
          .collection('parent_portal')
          .doc(slug)
          .collection('students')
          .doc('${code}_$last4')
          .delete();
    } catch (_) {}
  }

  /// نشر شامل لكل الطلاب — بيتنادى أول مرة الميزة تتفعّل، أو يدويًا من
  /// الإعدادات لو المدرس عايز "يحدّث كل حاجة دلوقتي".
  ///
  /// عمدًا مش بينادي pushStudentSummary لكل طالب لوحده — كانت بتعمل
  /// طلب شبكة منفصل (زائد قراءة قاعدة بيانات منفصلة للحضور/المدفوعات)
  /// لكل طالب، يعني لمدرس عنده 100+ طالب كانت بتاخد دقايق وممكن تتقطع
  /// في النص (يسيب الطلاب اللي بعدها من غير نشر خالص). هنا بنقرا كل
  /// الحضور/المدفوعات/المجموعات مرة واحدة بس، ونبعت التحديثات كلها في
  /// دفعة Firestore واحدة (WriteBatch) — طلب شبكة واحد تقريبًا بدل
  /// مئات.
  Future<int> publishAllStudents() async {
    if (!LicenseController.to.parentPortalEnabled.value) return 0;
    await publishProfile();

    final students = await _dbService.getAllStudents();
    final allAttendance = await _dbService.getAllAttendance();
    final allPayments = await _dbService.getAllPayments();
    final allGroups = await _dbService.getAllGroups();

    final groupNameById = {for (final g in allGroups) g.id: g.name};
    final presentByStudent = <int, int>{};
    final absentByStudent = <int, int>{};
    for (final a in allAttendance) {
      if (a.status == ATTENDANCE_PRESENT) {
        presentByStudent.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      } else if (a.status == ATTENDANCE_ABSENT) {
        absentByStudent.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final paidByStudent = <int, double>{};
    for (final p in allPayments) {
      paidByStudent.update(p.studentId, (v) => v + p.amount,
          ifAbsent: () => p.amount);
    }

    await _ensureAuth();
    final slug = await ensureSlug();
    final col = _db.collection('parent_portal').doc(slug).collection('students');

    // Firestore بتحدّد أقصى 500 عملية لكل batch — بنقسّم كل 400 طالب
    // لدفعة منفصلة عشان نفضل بعيد عن الحد الأقصى بهامش أمان.
    var batch = _db.batch();
    var opsInBatch = 0;
    var count = 0;
    for (final s in students) {
      if (s.id == null) continue;
      final data = _buildSummaryData(
        s,
        present: presentByStudent[s.id] ?? 0,
        absent: absentByStudent[s.id] ?? 0,
        totalPaid: paidByStudent[s.id] ?? 0,
        groupName: groupNameById[s.groupId] ?? '',
      );
      if (data == null) continue;
      final docId = data.remove('_docId') as String;
      batch.set(col.doc(docId), data);
      opsInBatch++;
      count++;
      if (opsInBatch >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsInBatch = 0;
      }
    }
    if (opsInBatch > 0) {
      await batch.commit();
    }
    return count;
  }
}
