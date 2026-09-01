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

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/services/database_service.dart';

class ParentPortalService {
  static final ParentPortalService _instance = ParentPortalService._internal();
  factory ParentPortalService() => _instance;
  ParentPortalService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();
  Worker? _profileWorker;
  Worker? _licenseWorker;

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

  /// بتتابع تفعيل/تعديل مدة بوابة أولياء الأمور وتعيد نشر البروفايل
  /// (بتاريخ الانتهاء الجديد) فورًا عند أي تغيير — مهم بالذات لسيناريو
  /// "تجديد بعد انتهاء": من غيرها، صفحة /track العامة كانت هتفضل تعرض
  /// تاريخ الانتهاء القديم (المنتهي) لحد ما يحصل أي نشر عرضي تاني.
  /// مسجَّلة من غير أي شرط على الحالة الحالية (فعّالة/منتهية) عشان
  /// تلتقط التفعيل الأول والتجديد بعد الانتهاء على السواء.
  void _watchLicenseChanges() {
    if (_licenseWorker != null) return;
    if (!Get.isRegistered<LicenseController>()) return;
    final lic = LicenseController.to;
    _licenseWorker = everAll(
      [lic.parentPortalEnabled, lic.parentPortalExpiresAt],
      (_) => publishProfile(),
    );
  }

  /// لازم تتنادى مرة واحدة عند إقلاع التطبيق (main.dart، بعد تسجيل
  /// LicenseController وSettingsController) — بتؤمّن إن أي تغيير لاحق
  /// في تفعيل/مدة بوابة أولياء الأمور (سواء من التطبيق نفسه، أو تعديل
  /// مباشر من الأدمن على مستند الترخيص في Firestore ووصل للتطبيق عبر
  /// الاستماع الفوري الموجود بالفعل) بينعكس فورًا على الصفحة العامة.
  ///
  /// من غير النداء ده، الـwatchers (`_watchLicenseChanges`/
  /// `_watchProfileChanges`) كانت بتتسجّل بس أول مرة publishProfile
  /// (أو pushStudentSummary/publishAllStudents) يتنادوا فعليًا — يعني
  /// لو المدرس فتح التطبيق وماعملش أي إجراء بيلمس بوابة أولياء الأمور
  /// (إضافة طالب، تسجيل حضور/دفعة، فتح شاشة الإعدادات)، والأدمن قصّر
  /// أو ألغى مدة البوابة في نفس الوقت، الصفحة العامة كانت بتفضل عارضة
  /// بيانات الطلاب زي ما هي — من غير أي قفل — لحد ما حاجة تانية
  /// تحصل بالصدفة تشغّل publishProfile لأول مرة. ده كان بيسيب البوابة
  /// "متفتحة" فترة غير محددة بعد ما المفروض تتقفل، رغم إن منطق القفل
  /// نفسه (في الصفحة العامة وفي parentPortalActiveNow) سليم.
  void init() {
    _watchLicenseChanges();
    _watchProfileChanges();
  }

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('ParentPortalService: signInAnonymously failed — $e');
      }
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
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return;
    _watchProfileChanges();
    try {
      await _ensureAuth();
      final slug = await ensureSlug();
      await _publishProfile(slug);
    } catch (e) {
      // best-effort — بنسجّل بس عشان فشل صامت زي ده (mismatch في هوية
      // الجهاز/الحساب بعد إعادة تثبيت أو مسح بيانات، مثلاً) يبقى قابل
      // للتشخيص من لوج الجهاز بدل ما يفضل مخفي تمامًا (راجع
      // specs/003-parent-portal-expiry — الحادثة اللي اكتشفناها فيها).
      debugPrint('ParentPortalService: publishProfile failed — $e');
    }
  }

  Future<void> _publishProfile(String slug) async {
    final settings =
        Get.isRegistered<SettingsController>() ? Get.find<SettingsController>() : null;
    // بننشر تاريخ انتهاء بوابة أولياء الأمور (لو موجود) جوه نفس المستند
    // العام ده — عشان صفحة /track/{slug} (كود JS خام، بدون وصول لمجموعة
    // licenses المحمية) تقدر تتحقق بنفسها إن المدة لسه سارية قبل ما
    // تعرض أي بيانات طالب. null صراحةً لو مفيش تاريخ (مدى الحياة)،
    // عشان تجديد لاحق يمسح تاريخ قديم كان منشور.
    final expiresAt = LicenseController.to.parentPortalExpiresAt.value;
    await _db.collection('parent_portal').doc(slug).set({
      'teacherName': settings?.teacherFullName.value ?? '',
      'teacherGender': settings?.teacherGender.value ?? 'male',
      'ownerUid': _auth.currentUser?.uid,
      'deviceId': LicenseController.to.deviceId.value,
      // .toUtc() ضروري هنا — من غيرها الـstring بيطلع بتوقيت محلي بلا
      // علامة timezone، والمتصفح بتاع ولي الأمر (على جهاز تاني، ممكن
      // منطقة زمنية مختلفة) كان هيفسّرها بتوقيته المحلي هو مش توقيت
      // تليفون المدرس — ممكن يفرق ساعات في لحظة القفل الفعلية.
      // .toUtc() بتضمن علامة 'Z' فيرجع new Date() في الجافاسكريبت
      // يفهمها كلحظة مطلقة، بغض النظر عن توقيت أي جهاز.
      'parentPortalExpiresAt': expiresAt?.toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// بيبني بيانات ملخص طالب (من غير أي كتابة) — مستخدمة في النشر الفردي
  /// والجماعي مع بعض، عشان منكررش نفس منطق الحساب في مكانين.
  ///
  /// بيبعت آخر 20 سجل حضور وآخر 15 دفعة بس (مش التاريخ كله) — عشان
  /// المستند يفضل خفيف حتى لطالب قديم عنده سنين من السجلات، ولأن
  /// ولي الأمر أصلاً مهتم بالأحدث مش بأرشيف كامل.
  Map<String, dynamic>? _buildSummaryData(
    Student student, {
    required List<Attendance> attendance,
    required List<Payment> payments,
    required List<Homework> homework,
    required String groupName,
    List<StudentExamRecord> exams = const [],
  }) {
    final last4 = _last4(student.guardianPhone);
    if (last4 == null) return null;
    final code = student.code.toUpperCase();
    if (code.isEmpty) return null;

    // "متأخر" يُحتسب حضورًا في العدّاد، ويُعرض كفئة ثالثة (spec 011)
    final present =
        attendance.where((a) => attendanceCountsAsPresent(a.status)).length;
    final late = attendance
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
        .length;
    final absent = attendance
        .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
        .length;
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final homeworkDone = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_DONE)
        .length;
    final homeworkPartial = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_PARTIAL)
        .length;
    final homeworkNotDone = homework
        .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_NOT_DONE)
        .length;

    final sortedAttendance = [...attendance]
      ..sort((a, b) => b.date.compareTo(a.date));
    final sortedPayments = [...payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final sortedHomework = [...homework]
      ..sort((a, b) => b.date.compareTo(a.date));

    // امتحانات الطالب — بس اللي اترصد فيها درجة أو اتسجّل غياب (مش
    // امتحانات مجدولة لسه مالهاش نتيجة). أحدث 15.
    final examRecords = exams
        .where((e) => e.grade != null || e.isAbsent)
        .toList()
      ..sort((a, b) => b.examDate.compareTo(a.examDate));

    return {
      '_docId': '${code}_$last4',
      'name': student.name,
      'groupName': groupName,
      'present': present,
      'late': late,
      'absent': absent,
      'totalPaid': totalPaid,
      'price': student.price,
      'exemptPercent': student.exemptPercent,
      'homeworkDone': homeworkDone,
      'homeworkPartial': homeworkPartial,
      'homeworkNotDone': homeworkNotDone,
      'attendanceHistory': sortedAttendance.take(20).map((a) => {
            'date': a.date.toIso8601String(),
            'status': normalizeAttendanceStatus(a.status) ?? a.status,
            'statusLabel': attendanceStatusLabel(a.status),
          }).toList(),
      'paymentHistory': sortedPayments.take(15).map((p) => {
            'date': p.date.toIso8601String(),
            'amount': p.amount,
            'note': p.note ?? '',
          }).toList(),
      'homeworkHistory': sortedHomework.take(20).map((h) => {
            'date': h.date.toIso8601String(),
            'status': normalizeHomeworkStatus(h.status) ?? h.status,
            'statusLabel': homeworkStatusLabel(h.status),
          }).toList(),
      'examCount': examRecords.length,
      'examHistory': examRecords.take(15).map((e) => {
            'name': e.examName,
            'date': e.examDate.toIso8601String(),
            'absent': e.isAbsent,
            'grade': e.isAbsent ? null : e.grade,
            'maxGrade': e.maxGrade,
          }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// بينشر ملخص طالب واحد — بتُستخدم بعد إضافة/تعديل/حذف فردي (حضور،
  /// دفعة، بيانات طالب)، مش للنشر الجماعي (شوف publishAllStudents).
  /// بتتجاهل بصمت لو الميزة مش مفعّلة أو رقم ولي الأمر مش موجود/قصير —
  /// مفيش داعي نزعج المستخدم برسائل خطأ لعملية خلفية اختيارية.
  Future<void> pushStudentSummary(int studentId) async {
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return;
    try {
      final student = await _dbService.getStudent(studentId);
      if (student == null) return;

      final attendanceRecords = await _dbService.getAttendanceByStudent(studentId);
      final payments = await _dbService.getPaymentsByStudent(studentId);
      final homework = await _dbService.getHomeworkByStudent(studentId);
      final exams = await _dbService.getStudentExamHistory(studentId);
      final group = await _dbService.getGroup(student.groupId);
      final data = _buildSummaryData(student,
          attendance: attendanceRecords,
          payments: payments,
          homework: homework,
          groupName: group?.name ?? '',
          exams: exams);
      if (data == null) return;
      final docId = data.remove('_docId') as String;

      await _ensureAuth();
      final slug = await ensureSlug();
      // لازم مستند البروفايل يكون موجود الأول — قاعدة أمان الطلاب
      // بتتحقق منه بـ get()، ولو مش موجود أصلاً الكتابة بترفض. الكتابة
      // دي merge رخيصة لو كانت موجودة بالفعل، مش إعادة إنشاء.
      await _publishProfile(slug);

      await _db
          .collection('parent_portal')
          .doc(slug)
          .collection('students')
          .doc(docId)
          .set(data);
    } catch (e) {
      debugPrint('ParentPortalService: pushStudentSummary($studentId) failed — $e');
      // best-effort — مش هنعطّل أي حاجة في التطبيق بسبب فشل نشر خلفي
    }
  }

  /// لازم تُستدعى **قبل** حذف الطالب فعليًا (محتاجين الكود ورقم
  /// التليفون بتاعه للوصول لمستند الملخص) — وإلا بيانات الطالب المحذوف
  /// (اسمه، حضوره، مدفوعاته) تفضل معروضة للأبد لمين يعرف الكود والرقم،
  /// حتى بعد ما يتمسح من التطبيق تمامًا.
  Future<void> removeStudentSummary(Student student) async {
    if (!LicenseController.to.parentPortalActiveNow) return;
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
    _watchLicenseChanges();
    if (!LicenseController.to.parentPortalActiveNow) return 0;
    // عمدًا مش بننادي publishProfile() هنا — بتبلع أي فشل بصمت (مصمّمة
    // كده لاستخدامها الخلفي التفاعلي العادي)، فلو فشلت (مثلاً تسجيل
    // الدخول المجهول فشل)، كنا بنكمل نكتب دفعة الطلاب كلها بمعرّف
    // مستخدم مش متأكدين إنه صاحب المستند فعلاً — وده كان بيخلي قاعدة
    // الأمان ترفض الدفعة *كلها* دفعة واحدة (Firestore batch كله أو
    // ولا حاجة) من غير أي رسالة خطأ توصل للمدرس. هنا بنسيب أي فشل
    // يوصل لصاحب الاستدعاء (شاشة الإعدادات) عشان يظهر له تنبيه واضح.
    _watchProfileChanges();
    await _ensureAuth();
    final slug = await ensureSlug();
    await _publishProfile(slug);

    final students = await _dbService.getAllStudents();
    final allAttendance = await _dbService.getAllAttendance();
    final allPayments = await _dbService.getAllPayments();
    final allHomework = await _dbService.getAllHomework();
    final allGroups = await _dbService.getAllGroups();
    final examsByStudent = await _dbService.getAllStudentExamHistories();

    final groupNameById = {for (final g in allGroups) g.id: g.name};
    final attendanceByStudent = <int, List<Attendance>>{};
    for (final a in allAttendance) {
      attendanceByStudent.putIfAbsent(a.studentId, () => []).add(a);
    }
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in allPayments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }
    final homeworkByStudent = <int, List<Homework>>{};
    for (final h in allHomework) {
      homeworkByStudent.putIfAbsent(h.studentId, () => []).add(h);
    }

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
        attendance: attendanceByStudent[s.id] ?? const [],
        payments: paymentsByStudent[s.id] ?? const [],
        homework: homeworkByStudent[s.id] ?? const [],
        groupName: groupNameById[s.groupId] ?? '',
        exams: examsByStudent[s.id] ?? const [],
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
