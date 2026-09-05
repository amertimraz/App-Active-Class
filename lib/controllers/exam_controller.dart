// lib/controllers/exam_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/models/exam_submission_model.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/online_exam_service.dart';
import 'package:active_class/services/booking_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/certificate_model.dart';
import 'package:active_class/utils/helpers.dart';

/// نطاق فلتر صفحة المراكز (spec 018 — واحد نشط في كل مرة).
enum LbScope { all, group, exam, month }

class LbFilter {
  final LbScope scope;
  final int? groupId; // scope == group
  final int? examId; // scope == exam
  final DateTime? month; // scope == month (اليوم 1)
  const LbFilter({
    this.scope = LbScope.all,
    this.groupId,
    this.examId,
    this.month,
  });
}

/// طالب مؤهّل لشهادة تقدير من امتحان (grade > passingGrade وغير غائب).
typedef CertCandidate = ({
  int studentId,
  String name,
  double grade,
  double maxGrade,
});

class ExamController extends GetxController {
  static ExamController get to => Get.find();

  final _db = DatabaseService();

  final exams = <Exam>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadExams();
  }

  // ── Exams ─────────────────────────────────────────────────────────────────

  Future<void> loadExams() async {
    isLoading.value = true;
    try {
      exams.value = await _db.getAllExams();
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Exam>> getExamsForGroup(int groupId) =>
      _db.getExamsForGroup(groupId);

  Future<String?> addExam({
    required String name,
    required DateTime date,
    required double maxGrade,
    required double passingGrade,
    required List<int> groupIds,
    String? reportMonth,
  }) async {
    if (name.trim().isEmpty) return 'أدخل اسم الامتحان';
    if (groupIds.isEmpty) return 'اختر مجموعة على الأقل';
    if (maxGrade <= 0) return 'الدرجة الكاملة يجب أن تكون أكبر من صفر';
    if (passingGrade > maxGrade) return 'درجة النجاح لا تتجاوز الدرجة الكاملة';
    try {
      await _db.insertExam(
        Exam(
            name: name.trim(),
            date: date,
            maxGrade: maxGrade,
            passingGrade: passingGrade,
            reportMonth: reportMonth),
        groupIds,
      );
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل الحفظ: $e';
    }
  }

  Future<String?> editExam(Exam exam, List<int> groupIds) async {
    if (exam.name.trim().isEmpty) return 'أدخل اسم الامتحان';
    if (groupIds.isEmpty) return 'اختر مجموعة على الأقل';
    try {
      // امنع إزالة مجموعة عندها درجات مُدخلة بالفعل — إزالتها كانت
      // بتسيب الدرجات دي "يتيمة" (محفوظة بس مش ظاهرة في أي شاشة)
      // من غير أي تحذير للمدرّس.
      final blocked = await _db.groupsWithGradesNotIn(exam.id!, groupIds);
      if (blocked.isNotEmpty) {
        return 'مينفعش تشيل "${blocked.join('، ')}" — عندها درجات '
            'مُدخلة بالفعل لهذا الامتحان. احذف الدرجات الأول لو عايز تشيل المجموعة.';
      }
      await _db.updateExam(exam, groupIds);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل التعديل: $e';
    }
  }

  Future<void> deleteExam(int examId) async {
    await _db.deleteExam(examId);
    await loadExams();
  }

  // ── Grades ────────────────────────────────────────────────────────────────

  Future<List<ExamGrade>> getGradesForExamGroup(int examId, int groupId) =>
      _db.getGradesForExamGroup(examId, groupId);

  Future<void> saveGrade({
    required int examId,
    required int studentId,
    required double? grade,
    String? notes,
    bool isAbsent = false,
  }) async {
    await _db.upsertGrade(
        examId: examId,
        studentId: studentId,
        grade: grade,
        notes: notes,
        isAbsent: isAbsent);
    // حدّث بوابة أولياء الأمور بدرجة الطالب فورًا (best-effort)
    unawaited(ParentPortalService().pushStudentSummary(studentId));
  }

  Future<ExamGroupStats> getStats(int examId, int groupId, String groupName) =>
      _db.getExamGroupStats(examId, groupId, groupName);

  Future<ExamProgress> getExamProgress(int examId) =>
      _db.getExamProgress(examId);

  Future<Map<int, ExamProgress>> getAllExamsProgress() =>
      _db.getAllExamsProgress();

  // ── Student History ───────────────────────────────────────────────────────

  Future<List<StudentExamRecord>> getStudentHistory(int studentId) =>
      _db.getStudentExamHistory(studentId);

  // ── Leaderboard ───────────────────────────────────────────────────────────

  Future<List<LeaderboardEntry>> getLeaderboard({
    int? examId,
    int? groupId,
    List<int>? examIds,
  }) =>
      _db.getLeaderboard(examId: examId, groupId: groupId, examIds: examIds);

  /// قائمة المراكز حسب الفلتر النشط (spec 018).
  Future<List<LeaderboardEntry>> leaderboard(LbFilter f) {
    switch (f.scope) {
      case LbScope.group:
        // لو المجموعة اتحذفت أثناء ما الفلتر مختارها → رجوع لـ"الكل".
        return _db.getLeaderboard(groupId: f.groupId);
      case LbScope.exam:
        final ok = exams.any((e) => e.id == f.examId);
        return ok
            ? _db.getLeaderboard(examId: f.examId)
            : _db.getLeaderboard();
      case LbScope.month:
        final m = f.month;
        if (m == null) return _db.getLeaderboard();
        final ids = exams
            .where((e) {
              final r = e.effectiveReportMonth;
              return r.year == m.year && r.month == m.month;
            })
            .map((e) => e.id)
            .whereType<int>()
            .toList();
        return _db.getLeaderboard(examIds: ids); // ids فاضية → []
      case LbScope.all:
        return _db.getLeaderboard();
    }
  }

  // ── شهادات تقدير (spec 018) ───────────────────────────────────────────────

  /// طلاب امتحان (كل مجموعاته) اللي `grade > passingGrade` وغير غائبين.
  /// مرتّبين بالنسبة تنازليًا ثم بالاسم.
  Future<List<CertCandidate>> certifiableStudents(int examId) async {
    Exam? exam;
    for (final e in exams) {
      if (e.id == examId) {
        exam = e;
        break;
      }
    }
    if (exam == null) return [];
    final max = exam.maxGrade;
    final pass = exam.passingGrade;
    final seen = <int>{};
    final out = <CertCandidate>[];
    for (final gid in exam.groupIds) {
      for (final g in await _db.getGradesForExamGroup(examId, gid)) {
        final v = g.grade;
        if (v == null || g.isAbsent || v <= pass) continue;
        if (!seen.add(g.studentId)) continue;
        out.add((
          studentId: g.studentId,
          name: g.studentName ?? 'طالب',
          grade: v,
          maxGrade: max,
        ));
      }
    }
    out.sort((a, b) {
      final pa = a.maxGrade > 0 ? a.grade / a.maxGrade : 0.0;
      final pb = b.maxGrade > 0 ? b.grade / b.maxGrade : 0.0;
      final c = pb.compareTo(pa);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  /// يبني CertificateData لتفوّق في امتحان (أو مركز — بتمرير kind/scopeLabel).
  CertificateData buildExamCert({
    required String studentName,
    required double grade,
    required double maxGrade,
    required String examName,
    required DateTime date,
    CertKind kind = CertKind.examExcellence,
    String? scopeLabel,
  }) {
    final s = Get.find<SettingsController>();
    final pct = maxGrade > 0 ? (grade / maxGrade * 100) : 0.0;
    final scope =
        (scopeLabel != null && scopeLabel.trim().isNotEmpty) ? ' ${scopeLabel.trim()}' : '';
    final achievement = switch (kind) {
      CertKind.examExcellence => 'تقديرًا لتفوّقه في امتحان «$examName»',
      CertKind.rank1 => 'لحصوله على المركز الأول$scope',
      CertKind.rank2 => 'لحصوله على المركز الثاني$scope',
      CertKind.rank3 => 'لحصوله على المركز الثالث$scope',
      CertKind.appreciation => 'تقديرًا لتميّزه والتزامه',
    };
    final tn = s.teacherFullName.value.trim();
    final ts = s.teacherSpecialization.value.trim();
    return CertificateData(
      studentName: studentName,
      kind: kind,
      achievementText: achievement,
      gradeText:
          'الدرجة: ${FormatHelper.formatGrade(grade)} من ${FormatHelper.formatGrade(maxGrade)} (${pct.toStringAsFixed(0)}%)',
      dateText: FormatHelper.formatFullDate(date),
      teacherName: tn.isEmpty ? null : tn,
      teacherSpecialization: ts.isEmpty ? null : ts,
      teacherTitle: s.teacherTitle,
    );
  }

  /// شهادة مركز من صفحة الأوائل — النص بمعدّل النسبة عبر عدة امتحانات.
  CertificateData buildRankCert({
    required String studentName,
    required CertKind kind,
    required double pct,
    required int examCount,
    String? scopeLabel,
  }) {
    final s = Get.find<SettingsController>();
    final scope =
        (scopeLabel != null && scopeLabel.trim().isNotEmpty) ? ' ${scopeLabel.trim()}' : '';
    final rank = switch (kind) {
      CertKind.rank1 => 'المركز الأول',
      CertKind.rank2 => 'المركز الثاني',
      CertKind.rank3 => 'المركز الثالث',
      _ => 'مركز متقدّم',
    };
    final tn = s.teacherFullName.value.trim();
    final ts = s.teacherSpecialization.value.trim();
    return CertificateData(
      studentName: studentName,
      kind: kind,
      achievementText: 'لحصوله على $rank$scope',
      gradeText: examCount > 1
          ? 'بمعدّل ${pct.toStringAsFixed(0)}% عبر $examCount امتحانات'
          : 'بنسبة ${pct.toStringAsFixed(0)}%',
      dateText: FormatHelper.formatFullDate(DateTime.now()),
      teacherName: tn.isEmpty ? null : tn,
      teacherSpecialization: ts.isEmpty ? null : ts,
      teacherTitle: s.teacherTitle,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // spec 016 — امتحان إلكتروني
  // ══════════════════════════════════════════════════════════════════════════

  final _online = OnlineExamService();

  List<Exam> get onlineExams =>
      exams.where((e) => e.isOnline).toList();

  Future<List<ExamQuestion>> getQuestions(int examId) =>
      _db.getQuestionsForExam(examId);

  /// يرفع صورة سؤال (spec 019) لخدمة الرفع على الـVPS ويرجّع الرابط،
  /// أو null عند الفشل. examId مش مُستخدم في المسار — بيتساب للتوافق.
  Future<String?> uploadQuestionImage(int examId, List<int> bytes) async {
    String slug = '';
    try {
      slug = await ParentPortalService().ensureSlug();
    } catch (_) {}
    return BookingService().uploadExamImage(bytes, slug: slug);
  }

  Future<List<ExamSubmission>> getSubmissions(int examId) =>
      _db.getSubmissionsForExam(examId);

  /// ينشئ مسودّة امتحان إلكتروني (صف exams بـ is_online=1, status=draft).
  Future<int> createOnlineExamDraft({required String name}) async {
    final examId = await _db.insertExam(
      Exam(name: name.trim().isEmpty ? 'امتحان إلكتروني' : name.trim(),
          date: DateTime.now()),
      const [],
      skipSync: true, // spec 016 — محلي، مايتزامنش للمساعدين
    );
    await _db.setExamOnlineFields(examId, isOnline: true, status: OnlineExamStatus.draft);
    await loadExams();
    return examId;
  }

  /// يحفظ مسودّة امتحان إلكتروني: بيانات الامتحان + الأسئلة + المجموعات.
  Future<String?> saveOnlineExamDraft({
    required Exam exam,
    required List<ExamQuestion> questions,
    required List<int> groupIds,
  }) async {
    if (exam.name.trim().isEmpty) return 'أدخل اسم الامتحان';
    try {
      final totalPoints = questions.fold<double>(0, (s, q) => s + q.points);
      await _db.updateExam(
        exam.copyWith(
          maxGrade: totalPoints <= 0 ? 100 : totalPoints,
          passingGrade: totalPoints <= 0 ? 50 : totalPoints / 2,
        ),
        groupIds,
        skipSync: true, // spec 016 — محلي، مايتزامنش للمساعدين
      );
      await _db.setExamOnlineFields(
        exam.id!,
        isOnline: true,
        status: exam.onlineStatus ?? OnlineExamStatus.draft,
        opensAt: exam.opensAt,
        closesAt: exam.closesAt,
        durationMinutes: exam.durationMinutes,
      );
      await _db.replaceExamQuestions(exam.id!, questions);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل الحفظ: $e';
    }
  }

  /// ينشر امتحانًا إلكترونيًا للسحابة (بدون مفتاح إجابة). يرجّع رسالة خطأ أو null.
  Future<String?> publishOnlineExam(int examId) async {
    if (!LicenseController.to.parentPortalActiveNow) {
      return 'الامتحانات الإلكترونية ضمن إضافة بوابة متابعة أولياء الأمور';
    }
    final exam = exams.firstWhereOrNull((e) => e.id == examId);
    if (exam == null) return 'الامتحان غير موجود';
    final questions = await _db.getQuestionsForExam(examId);
    if (questions.isEmpty) return 'أضف سؤالًا واحدًا على الأقل';
    if (questions.any((q) => !q.isValid)) {
      return 'فيه سؤال ناقص — تأكّد من النص والاختيارات والإجابة الصحيحة والدرجة';
    }
    if (exam.groupIds.isEmpty) return 'اختر مجموعة واحدة على الأقل';
    final opens = exam.opensAt, closes = exam.closesAt, dur = exam.durationMinutes;
    if (opens == null || closes == null || dur == null) {
      return 'حدّد وقت الفتح ووقت القفل ومدة الحل';
    }
    if (!closes.isAfter(opens)) return 'وقت القفل لازم يكون بعد وقت الفتح';
    if (dur <= 0) return 'مدة الحل لازم تكون أكبر من صفر';
    if (dur * 60 > closes.difference(opens).inSeconds) {
      return 'مدة الحل أطول من النافذة الزمنية';
    }

    final allowed = await _db.allowedStudentsForGroups(exam.groupIds);
    if (allowed.students.isEmpty) {
      return 'مفيش طلاب لهم رقم ولي أمر صالح في المجموعات المختارة';
    }

    final allGroups = await _db.getAllGroups();
    final groupNames = allGroups
        .where((g) => exam.groupIds.contains(g.id))
        .map((g) => g.name)
        .toList();

    try {
      // كتابات Firestore بتتعلّق للأبد لو النت مقطوع/ضعيف (الـFuture
      // مبيكملش غير لما السيرفر يأكّد) — سقف زمني عشان زر "نشر" ما
      // يفضلش معلّق. الكتابات بتتحفظ محليًا وبتتزامن أول ما النت يرجع.
      var slowNetwork = false;
      try {
        await _online
            .publish(exam, questions, allowed.students, groupNames)
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        slowNetwork = true;
      }
      await _db.setExamOnlineStatus(examId, OnlineExamStatus.published);
      await loadExams();
      if (slowNetwork) {
        return '__WARN__ تم الحفظ. النت ضعيف — ممكن الامتحان ياخد دقيقة '
            'عشان يبان للطلاب. تأكد إنك أونلاين.';
      }
      if (allowed.excludedCount > 0) {
        return '__WARN__ تم النشر. ${allowed.excludedCount} طالب مستبعد (رقم ولي أمر ناقص)';
      }
      return null;
    } catch (e) {
      return 'فشل النشر — تحقق من اتصالك بالإنترنت';
    }
  }

  Future<String?> unpublishOnlineExam(int examId) async {
    try {
      await _online.unpublish(examId);
      await _db.setExamOnlineStatus(examId, OnlineExamStatus.draft);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل — تحقق من اتصالك بالإنترنت';
    }
  }

  /// تعديل ميعاد/اسم امتحان منشور/موقوف بدون إعادة نشر.
  /// [opensAt]/[closesAt] بالتوقيت المحلي — بنحوّلها UTC.
  Future<String?> rescheduleOnlineExam(
    int examId, {
    required DateTime opensAt,
    required DateTime closesAt,
    required int durationMinutes,
    String? name,
  }) async {
    if (name != null && name.trim().isEmpty) return 'أدخل اسم الامتحان';
    if (!closesAt.isAfter(opensAt)) return 'وقت القفل لازم يكون بعد وقت الفتح';
    if (durationMinutes <= 0) return 'مدة الحل لازم تكون أكبر من صفر';
    if (durationMinutes * 60 > closesAt.difference(opensAt).inSeconds) {
      return 'مدة الحل أطول من النافذة الزمنية';
    }
    try {
      await _online.updateSchedule(
        examId,
        opensAtUtc: opensAt.toUtc(),
        closesAtUtc: closesAt.toUtc(),
        durationMinutes: durationMinutes,
        title: name?.trim(),
      );
      if (name != null) await _db.setExamName(examId, name.trim());
      await _db.setExamOnlineFields(
        examId,
        isOnline: true,
        status: OnlineExamStatus.published,
        opensAt: opensAt.toUtc(),
        closesAt: closesAt.toUtc(),
        durationMinutes: durationMinutes,
      );
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل التعديل — تحقق من اتصالك بالإنترنت';
    }
  }

  /// تعديل اسم امتحان (مسودّة أو منشور) — الاسم مش مفتاح إجابة فآمن أي وقت.
  Future<String?> renameOnlineExam(int examId, String name) async {
    if (name.trim().isEmpty) return 'أدخل اسم الامتحان';
    final exam = exams.firstWhereOrNull((e) => e.id == examId);
    try {
      await _db.setExamName(examId, name.trim());
      if (exam?.onlineStatus == OnlineExamStatus.published ||
          exam?.onlineStatus == OnlineExamStatus.stopped) {
        await _online.updateTitle(examId, name.trim());
      }
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل — تحقق من اتصالك بالإنترنت';
    }
  }

  Future<String?> stopOnlineExam(int examId) async {
    try {
      await _online.stopNow(examId, DateTime.now().toUtc());
      await _db.setExamOnlineStatus(examId, OnlineExamStatus.stopped);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل — تحقق من اتصالك بالإنترنت';
    }
  }

  Future<String?> removeOnlineExamFromWeb(int examId) async {
    try {
      await _online.deleteRemote(examId);
      await _db.setExamOnlineStatus(examId, OnlineExamStatus.removed);
      await loadExams();
      return null;
    } catch (e) {
      return 'فشل الحذف من الويب';
    }
  }

  /// يسحب التسليمات من السحابة، يصحّح الأسئلة الموضوعية محليًا، ويكتبها في
  /// exam_submissions بحالة "بانتظار الاعتماد". يرجّع عدد التسليمات أو رسالة خطأ.
  Future<({int pulled, int notSubmitted, String? error})> pullAndGradeOnlineExam(
      int examId) async {
    final exam = exams.firstWhereOrNull((e) => e.id == examId);
    if (exam == null) return (pulled: 0, notSubmitted: 0, error: 'الامتحان غير موجود');
    List<CloudSubmission> subs;
    try {
      subs = await _online.fetchSubmissions(examId);
    } catch (e) {
      return (pulled: 0, notSubmitted: 0, error: 'فشل السحب — تحقق من الإنترنت');
    }

    final questions = await _db.getQuestionsForExam(examId);
    final byKey = {for (final q in questions) 'q${q.id}': q};

    // مطابقة الكود case-insensitive — أكواد الطلاب مش مضمون تبقى كلها
    // uppercase (كود المجموعة اللي المدرس بيكتبه بحرية)، بينما التسليم
    // من السحابة بييجي بالكود uppercase دايمًا.
    final allStudents = await _db.getAllStudents();
    final byCode = {
      for (final st in allStudents)
        if (st.id != null) st.code.trim().toUpperCase(): st,
    };

    final matchedStudentIds = <int>{};
    for (final s in subs) {
      final student = byCode[s.code.trim().toUpperCase()];
      if (student?.id == null) continue;
      matchedStudentIds.add(student!.id!);

      var auto = 0.0;
      byKey.forEach((key, q) {
        final chosen = s.answers[key];
        if (chosen != null && chosen == q.correctIndex) auto += q.points;
      });

      final answersByQid = <int, int>{};
      s.answers.forEach((key, v) {
        final q = byKey[key];
        if (q?.id != null) answersByQid[q!.id!] = v;
      });

      await _db.upsertSubmission(ExamSubmission(
        examId: examId,
        studentId: student.id!,
        startedAt: s.startedAt,
        submittedAt: s.submittedAt,
        answers: answersByQid,
        autoScore: auto,
        finalGrade: auto,
        status: SubmissionStatus.pending,
        autoSubmitted: s.autoSubmitted,
      ));
    }

    // طلاب مسموح لهم بلا تسليم والنافذة انتهت → "لم يسلّم"
    var notSubmitted = 0;
    final closed = exam.closesAt == null ||
        DateTime.now().toUtc().isAfter(exam.closesAt!) ||
        exam.onlineStatus == OnlineExamStatus.stopped;
    if (closed) {
      final allowed =
          (await _db.allowedStudentsForGroups(exam.groupIds)).students;
      for (final st in allowed) {
        if (matchedStudentIds.contains(st.id)) continue;
        final existing = await _db.getSubmissionForStudent(examId, st.id);
        if (existing?.status == SubmissionStatus.approved) continue;
        await _db.upsertSubmission(ExamSubmission(
          examId: examId,
          studentId: st.id,
          status: SubmissionStatus.notSubmitted,
          autoScore: 0,
          finalGrade: 0,
        ));
        notSubmitted++;
      }
    }

    return (pulled: matchedStudentIds.length, notSubmitted: notSubmitted, error: null);
  }

  /// تفاصيل نتيجة كل سؤال لتسليم — للعرض في شاشة المراجعة.
  Future<List<QuestionResult>> questionResults(ExamSubmission sub) async {
    final questions = await _db.getQuestionsForExam(sub.examId);
    return questions
        .map((q) => QuestionResult(
              questionId: q.id!,
              questionText: q.text,
              options: q.options,
              correctIndex: q.correctIndex,
              chosenIndex: sub.answers[q.id],
              points: q.points,
              imageUrl: q.imageUrl,
            ))
        .toList();
  }

  /// يعتمد درجة طالب: يكتب في exam_submissions + exam_grades (نفس مسار
  /// الدرجة اليدوية → pushStudentSummary يشتغل).
  Future<void> approveOnlineGrade(
    int examId,
    int studentId, {
    double? overrideGrade,
  }) async {
    final sub = await _db.getSubmissionForStudent(examId, studentId);
    if (sub == null) return;
    if (sub.status == SubmissionStatus.approved && overrideGrade == null) return;

    final isAbsent = sub.status == SubmissionStatus.notSubmitted;
    final grade = isAbsent ? null : (overrideGrade ?? sub.autoScore ?? 0);

    await _db.updateSubmissionApproval(
        examId, studentId, grade ?? 0, SubmissionStatus.approved);
    await saveGrade(
      examId: examId,
      studentId: studentId,
      grade: grade,
      notes: isAbsent ? null : 'امتحان إلكتروني — تصحيح تلقائي',
      isAbsent: isAbsent,
    );

    // مراجعة تفصيلية لصفحة الطالب — إجابته + الإجابة الصحيحة لكل سؤال.
    // بعد الاعتماد بس، وطبعًا مش لطالب غايب (مفيش إجابات أصلاً).
    if (!isAbsent) {
      try {
        final exam = exams.firstWhereOrNull((e) => e.id == examId);
        final student = await _db.getStudent(studentId);
        final attemptKey =
            student != null ? ParentPortalService().attemptKeyFor(student) : null;
        if (exam != null && attemptKey != null) {
          // sub.answers هي كل اللي questionResults محتاجه — الدرجة/الحالة
          // بتتبعت لـpublishReview لوحدها تحت.
          final results = await questionResults(sub);
          await _online.publishReview(
            examId: examId,
            attemptKey: attemptKey,
            grade: grade ?? 0,
            maxGrade: exam.maxGrade,
            results: results,
          );
        }
      } catch (e) {
        // best-effort — الطالب هيشوف الدرجة الإجمالية من examHistory برضو.
      }
    }
  }

  /// "اعتماد الكل" — يعتمد الطلاب اللي **سلّموا** فقط (حالة pending).
  /// اللي "لم يسلّم" بيتساب للمدرس يعلّمه غائبًا بنفسه (FR-026) — مش
  /// افتراض تلقائي إن كل من لم يسلّم = غائب.
  Future<void> approveAllOnlineGrades(int examId) async {
    final subs = await _db.getSubmissionsForExam(examId);
    for (final s in subs) {
      if (s.status != SubmissionStatus.pending) continue;
      await approveOnlineGrade(examId, s.studentId);
    }
  }

  /// spec 022 — عكس approveOnlineGrade: يشيل درجة الطالب (سجله + بوابة
  /// الأهالي) ومراجعته المنشورة، ويرجّع التسليم لـ"بانتظار الاعتماد".
  /// مشترَكة بين "إلغاء الاعتماد" و"إبطال التسليم" تحت.
  Future<void> _deleteGradeAndReview(int examId, int studentId) async {
    await _db.deleteGrade(examId, studentId);
    unawaited(ParentPortalService().pushStudentSummary(studentId));
    try {
      final student = await _db.getStudent(studentId);
      final attemptKey =
          student != null ? ParentPortalService().attemptKeyFor(student) : null;
      if (attemptKey != null) {
        await _online.deleteReview(examId, attemptKey);
      }
    } catch (e) {
      // best-effort — لو فشل حذف المراجعة على السحابة، الدرجة اتشالت
      // محليًا وفي بوابة الأهالي على أي حال.
    }
  }

  /// إلغاء اعتماد درجة بالغلط — يرجّع التسليم لـ"بانتظار الاعتماد"
  /// ويشيل كل أثر الدرجة (سجل الطالب + بوابة الأهالي + مراجعة الويب).
  Future<void> unapproveOnlineGrade(int examId, int studentId) async {
    final sub = await _db.getSubmissionForStudent(examId, studentId);
    if (sub == null || sub.status != SubmissionStatus.approved) return;
    await _db.updateSubmissionApproval(
        examId, studentId, sub.autoScore ?? 0, SubmissionStatus.pending);
    await _deleteGradeAndReview(examId, studentId);
  }

  /// إبطال تسليم طالب (غش/مشكلة تقنية) — بيعمل نفس أثر إلغاء الاعتماد
  /// (لو كان معتمَد) زيادة عليه: يحذف التسليم من السحابة (عشان الطالب
  /// يقدر يسلّم من الأول) ويعلّم النسخة المحلية "مُبطَل" (FR-014: زر
  /// واحد يعمل الاتنين مع بعض بغضّ النظر عن حالة التسليم الحالية).
  Future<void> voidSubmission(int examId, int studentId) async {
    final sub = await _db.getSubmissionForStudent(examId, studentId);
    if (sub == null ||
        sub.status == SubmissionStatus.notSubmitted ||
        sub.status == SubmissionStatus.voided) {
      return;
    }
    await _deleteGradeAndReview(examId, studentId);
    await _db.voidSubmissionLocally(examId, studentId);
    try {
      final student = await _db.getStudent(studentId);
      final attemptKey =
          student != null ? ParentPortalService().attemptKeyFor(student) : null;
      if (attemptKey != null) {
        await _online.deleteSubmission(examId, attemptKey);
      }
    } catch (e) {
      // best-effort
    }
  }

  /// تعديل سؤال واحد في امتحان منشور/موقوف من غير إلغاء النشر — يحفظ
  /// محليًا ويعيد نشر مصفوفة الأسئلة كاملة (بدون مفتاح إجابة، زي
  /// toCloudMap العادي). يرجّع عدد التسليمات اللي جاوبت على السؤال ده
  /// (بغضّ النظر عن حالتها، ما عدا المُبطَلة) — لعرض تحذير في الواجهة
  /// لو > 0 (FR-011)، من غير ما يغيّر أي درجة معتمَدة تلقائيًا.
  Future<int> updateQuestionAfterPublish(ExamQuestion updated) async {
    await _db.updateQuestion(updated);
    final subs = await _db.getSubmissionsForExam(updated.examId);
    final affected = subs
        .where((s) =>
            s.status != SubmissionStatus.voided &&
            s.answers.containsKey(updated.id))
        .length;
    final questions = await _db.getQuestionsForExam(updated.examId);
    unawaited(_online.republishQuestions(updated.examId, questions));
    return affected;
  }

  // ── رسالة نتيجة الامتحان لولي الأمر (واتساب) ───────────────────────────────
  // راجع specs/008-exam-whatsapp-results. بتتولّد وقت الإرسال بس — مفيش
  // تخزين لها. لو الطالب غايب عن الامتحان بترجع رسالة غياب مستقلة، غير
  // كده رسالة نتيجة (الدرجة + ناجح/راسب حسب درجة نجاح هذا الامتحان
  // بالتحديد، مش نسبة ثابتة).
  String buildGuardianExamResultMessage({
    required ExamGrade grade,
    required Exam exam,
    String teacherName = '',
    String teacherSpecialization = '',
  }) {
    final name = grade.studentName ?? 'الطالب';
    final buffer = StringBuffer();
    if (grade.isAbsent) {
      buffer
        ..writeln('⚠️ *تنبيه غياب عن امتحان*')
        ..writeln('👤 $name')
        ..writeln('📝 لم يحضر امتحان "${exam.name}"');
    } else {
      final g = grade.grade ?? 0;
      final passed = g >= exam.passingGrade;
      buffer
        ..writeln(passed ? '✅ *نتيجة امتحان*' : '⚠️ *نتيجة امتحان*')
        ..writeln('👤 $name')
        ..writeln('📝 امتحان "${exam.name}"')
        ..writeln('📊 الدرجة: ${FormatHelper.formatGrade(g)} من '
            '${FormatHelper.formatGrade(exam.maxGrade)}')
        ..writeln(passed ? '🟢 الحالة: ناجح' : '🔴 الحالة: راسب');
      if ((grade.notes ?? '').trim().isNotEmpty) {
        buffer.writeln('📌 ملاحظات: ${grade.notes!.trim()}');
      }
    }
    if (teacherName.trim().isNotEmpty) {
      buffer.writeln('👨‍🏫 ${teacherName.trim()}');
    }
    if (teacherSpecialization.trim().isNotEmpty) {
      buffer.writeln('📘 ${teacherSpecialization.trim()}');
    }
    return buffer.toString().trimRight();
  }
}
