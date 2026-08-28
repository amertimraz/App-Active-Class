// lib/controllers/student_controller.dart

import 'dart:async';

import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/helpers.dart';

class StudentController extends GetxController {
  final DatabaseService _dbService = DatabaseService();

  /// الطلاب النشطين بس (غير المؤرشفين) — مصدر الحقيقة لكل الشاشات
  /// النشطة (قوائم، حضور، دفع بالـQR، داشبورد). لا تُمس إلا بـ
  /// loadAllStudents/loadStudentsByGroup.
  final RxList<Student> students = <Student>[].obs;

  /// القائمة المعروضة بعد تطبيق البحث والفلتر (مبنية من students —
  /// نشطين بس)
  final RxList<Student> filteredStudents = <Student>[].obs;

  /// الطلاب المؤرشفين بس — لشاشة الأرشيف فقط
  final RxList<Student> archivedStudents = <Student>[].obs;

  final RxBool    isLoading    = false.obs;
  final RxString  searchQuery  = ''.obs;
  final Rxn<int>  selectedGroupId = Rxn<int>();

  /// عدد كل الطلاب (نشط + مؤرشف) — لفحص حد الباقة بس (راجع
  /// LicenseController.checkCanAddStudent). لا يُستخدم لعرض أي رقم
  /// في الشاشات النشطة العادية.
  int totalStudentCount = 0;

  @override
  void onInit() {
    super.onInit();
    // debounce على searchQuery يُعيد تطبيق الفلتر
    debounce(searchQuery, (_) => filterStudents(),
        time: const Duration(milliseconds: 180));
    loadAllStudents();
  }

  // ── تحميل كل الطلاب (المصدر الأساسي) ───────────────────────────
  Future<void> loadAllStudents() async {
    isLoading(true);
    try {
      final all = await _dbService.getAllStudents();
      totalStudentCount = all.length;
      students.assignAll(all.where((s) => !s.isArchived));
      archivedStudents.assignAll(all.where((s) => s.isArchived));
      filterStudents(); // طبّق الفلتر الحالي (إن وُجد)
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الطلاب');
    } finally {
      isLoading(false);
    }
  }

  /// تحميل الطلاب المؤرشفين بس — لشاشة الأرشيف، بدون إعادة تحميل
  /// قائمة النشطين (أخف وأسرع لو الشاشة دي بس اللي محتاجة تتحدّث).
  Future<void> loadArchivedStudents() async {
    isLoading(true);
    try {
      archivedStudents.assignAll(await _dbService.getArchivedStudents());
      totalStudentCount = await _dbService.getAllStudentsCount();
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الأرشيف');
    } finally {
      isLoading(false);
    }
  }

  /// تحميل طلاب مجموعة — يُحدِّث `students` (نشطين بس) AND يضع الفلتر
  /// بحيث ترى `filteredStudents` طلاب المجموعة النشطين فقط
  Future<void> loadStudentsByGroup(int groupId) async {
    isLoading(true);
    try {
      final all = await _dbService.getAllStudents();
      totalStudentCount = all.length;
      students.assignAll(all.where((s) => !s.isArchived));
      archivedStudents.assignAll(all.where((s) => s.isArchived));
      selectedGroupId.value = groupId;     // ضع فلتر المجموعة
      filterStudents();
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الطلاب');
    } finally {
      isLoading(false);
    }
  }

  Future<List<Group>> loadAllGroups() async {
    return await _dbService.getAllGroups();
  }

  // ── إضافة طالب ──────────────────────────────────────────────────
  /// نقطة الدخول الوحيدة للإضافة — فحص حد الترخيص هنا يضمن إنفاذه
  /// بغض النظر عن الشاشة اللي بينادي منها (رئيسية، طلاب، تفاصيل مجموعة).
  /// الفحص بيحسب كل الطلاب (نشط + مؤرشف) — الأرشفة مش بتفضّي مكان في
  /// حد الباقة (قرار FR-013).
  Future<Student?> addStudent(Student student) async {
    final licenseErr =
        Get.find<LicenseController>().checkCanAddStudent(totalStudentCount);
    if (licenseErr != null) {
      ToastHelper.error(licenseErr);
      return null;
    }
    try {
      final id = await _dbService.insertStudent(student);
      final newStudent = student.copyWith(id: id);
      students.add(newStudent);
      totalStudentCount++;
      filterStudents(); // أعِد تطبيق الفلتر بدل الإضافة المباشرة
      unawaited(ParentPortalService().pushStudentSummary(id));
      return newStudent;
    } catch (e) {
      ToastHelper.error(_studentErrorMessage(e, 'إضافة'));
      return null;
    }
  }

  /// يترجم أخطاء قاعدة البيانات الشائعة لرسالة مفهومة للمدرّس
  /// بدل رسالة عامة تخفي السبب الحقيقي (زي تكرار كود الطالب).
  String _studentErrorMessage(Object e, String action) {
    if (e is DatabaseException && e.isUniqueConstraintError()) {
      return 'يوجد طالب بنفس الكود بالفعل — غيّر الكود وحاول تاني';
    }
    return 'حدث خطأ في $action الطالب';
  }

  /// توليد كود الطالب التالي بناءً على بادئة كود المجموعة
  Future<String> generateNextStudentCode(
      {required String groupPrefix, required int groupId}) async {
    final existing = await _dbService.getStudentsByGroup(groupId);
    int maxSuffix = 0;
    for (final s in existing) {
      if (s.code.startsWith(groupPrefix)) {
        final suffix = s.code.substring(groupPrefix.length);
        final numVal = int.tryParse(suffix);
        if (numVal != null && numVal > maxSuffix) maxSuffix = numVal;
      }
    }
    final next = maxSuffix + 1;
    return '$groupPrefix${next.toString().padLeft(2, '0')}';
  }

  /// عدد الطلاب في المجموعة اللي سعرهم لسه مطابق للسعر العام القديم
  /// للمجموعة (يعني معملهاش أي تخصيص/خصم يدوي) — بيُستخدم لعرض عدد
  /// دقيق قبل تعديل جماعي، بدل ما نفاجئ المدرس بعدد غير متوقع.
  int countStudentsAtGroupPrice({required int groupId, required double price}) {
    return students
        .where((s) => s.groupId == groupId && s.price == price)
        .length;
  }

  /// أكتر سعر متكرر بين طلاب المجموعة (غير السعر الجديد) — ده "السعر
  /// القديم الفعلي" اللي المفروض نعرض تحديثه، بدل ما نعتمد على سعر
  /// المجموعة نفسه كمرجع. الاعتماد على سعر المجموعة بس كان بيكسر
  /// الاكتشاف بعد أول مرة المدرس يرفض فيها التحديث الجماعي (أو بعد أي
  /// تعديل ما اتأكدش): سعر المجموعة كان بيفضل يتغيّر مع كل تعديل، لكن
  /// سعر الطلاب الفعلي بيفضل زي ما هو، فالمقارنة بينهم كانت بتفضل تكبر
  /// وتفضل السعر الفعلي مايتكتشفش تاني. الاعتماد على أكتر سعر متكرر
  /// فعليًا بين الطلاب بيخلي الاكتشاف يشتغل صح مهما اتكرر التعديل.
  double? mostCommonPriceForGroup(int groupId, {double? excludePrice}) {
    final counts = <double, int>{};
    for (final s in students) {
      if (s.groupId != groupId) continue;
      if (excludePrice != null && s.price == excludePrice) continue;
      counts[s.price] = (counts[s.price] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// تحديث سعر المجموعة العام لا يلمس سعر أي طالب تلقائيًا — كل طالب
  /// بيحتفظ بسعره المستقل من وقت إضافته (ممكن يكون اتعدّل يدويًا
  /// لخصم أو حالة خاصة). الدالة دي بتحدّث بس الطلاب اللي سعرهم لسه
  /// *مطابق تمامًا* للسعر القديم للمجموعة (يعني عمرهم ما اتخصّصوا)،
  /// وبتسيب أي طالب سعره مختلف (خصم، إعفاء بيتحسب كنسبة منفصلة أصلاً
  /// فمش محتاج استثناء، أو اتفاق خاص) من غير أي تغيير.
  Future<int> bulkUpdatePriceForGroupDefault({
    required int groupId,
    required double oldPrice,
    required double newPrice,
  }) async {
    final targets = students
        .where((s) => s.groupId == groupId && s.price == oldPrice)
        .toList();
    for (final s in targets) {
      final updated = s.copyWith(price: newPrice);
      await _dbService.updateStudent(updated);
      final idx = students.indexWhere((x) => x.id == s.id);
      if (idx != -1) students[idx] = updated;
      if (updated.id != null) {
        unawaited(ParentPortalService().pushStudentSummary(updated.id!));
      }
    }
    filterStudents();
    return targets.length;
  }

  // ── تعديل طالب ──────────────────────────────────────────────────
  Future<void> updateStudent(Student student) async {
    try {
      // لازم نعرف الكود/التليفون القديمين قبل التحديث — لو أي منهم
      // تغيّر، مستند ملخص المتابعة القديم (مبني على القيم القديمة)
      // يفضل معلّق على Firestore للأبد من غير ده.
      final old = _findInEitherList(student.id);
      await _dbService.updateStudent(student);
      _replaceInEitherList(student);
      filterStudents();
      if (student.id != null) {
        unawaited(ParentPortalService().pushStudentSummary(student.id!));
        if (old != null &&
            (old.code.toUpperCase() != student.code.toUpperCase() ||
                old.guardianPhone != student.guardianPhone)) {
          unawaited(ParentPortalService().removeStudentSummary(old));
        }
      }
      ToastHelper.success('تم تحديث الطالب بنجاح');
    } catch (e) {
      ToastHelper.error(_studentErrorMessage(e, 'تحديث'));
    }
  }

  Student? _findInEitherList(int? id) =>
      students.firstWhereOrNull((s) => s.id == id) ??
      archivedStudents.firstWhereOrNull((s) => s.id == id);

  /// بيحدّث الطالب في أي قائمة (نشطين/مؤرشفين) هو موجود فيها فعليًا —
  /// محتاجينها لأن شاشة الأرشيف بتقدر تعرض/تعدّل طالب مؤرشف (مش موجود
  /// في `students`).
  void _replaceInEitherList(Student updated) {
    final activeIdx = students.indexWhere((s) => s.id == updated.id);
    if (activeIdx != -1) {
      students[activeIdx] = updated;
      return;
    }
    final archivedIdx = archivedStudents.indexWhere((s) => s.id == updated.id);
    if (archivedIdx != -1) archivedStudents[archivedIdx] = updated;
  }

  /// يربط طالبين كإخوة بشكل ذري — تحديث محلي للاثنين فقط لو نجحت
  /// عملية القاعدة كاملة (منع ربط باتجاه واحد لو فشل نص العملية).
  Future<bool> linkSiblings(Student s1, Student s2) async {
    try {
      await _dbService.linkSiblings(s1, s2);
      for (final s in [s1, s2]) {
        final index = students.indexWhere((x) => x.id == s.id);
        if (index != -1) students[index] = s;
      }
      filterStudents();
      return true;
    } catch (e) {
      ToastHelper.error(_studentErrorMessage(e, 'ربط الإخوة'));
      return false;
    }
  }

  // ── أرشفة / استعادة طالب ────────────────────────────────────────
  /// أرشفة طالب (بديل الحذف النهائي) — بيانات وسجل الطالب يفضلوا
  /// محفوظين كاملين، بس بيختفي من كل الشاشات النشطة. إعادة تحميل
  /// كاملة (loadAllStudents) بدل تحديث محلي جزئي، لأن الأرشفة ممكن
  /// تأثر على طالبين مع بعض (فك ربط عرض الإخوة — راجع
  /// DatabaseService.archiveStudent).
  Future<bool> archiveStudent(int id) async {
    try {
      await _dbService.archiveStudent(id);
      await loadAllStudents();
      return true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في أرشفة الطالب');
      return false;
    }
  }

  /// استعادة طالب مؤرشف — يرجع نشط بسجله كامل.
  Future<bool> unarchiveStudent(int id) async {
    try {
      await _dbService.unarchiveStudent(id);
      await loadAllStudents();
      return true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في استعادة الطالب');
      return false;
    }
  }

  // ── حذف طالب ────────────────────────────────────────────────────
  /// يحذف طالب نهائياً — بدون أي تأكيد داخلي (التأكيد وتوضيح حجم
  /// الحذف المتتالي مسؤولية الشاشة المستدعية، زي deleteGroup تمامًا).
  /// بيرجّع true لو نجح وبيحدّث قائمة الطلاب محلياً على طول.
  Future<bool> deleteStudent(int id) async {
    try {
      final student = _findInEitherList(id);
      await _dbService.deleteStudent(id);
      students.removeWhere((s) => s.id == id);
      archivedStudents.removeWhere((s) => s.id == id);
      totalStudentCount = totalStudentCount > 0 ? totalStudentCount - 1 : 0;
      filterStudents();
      if (student != null) {
        unawaited(ParentPortalService().removeStudentSummary(student));
      }
      return true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في حذف الطالب');
      return false;
    }
  }

  // ── بحث ─────────────────────────────────────────────────────────
  void searchStudents(String query) {
    searchQuery.value = query;
  }

  // ── فلتر مجموعة ──────────────────────────────────────────────────
  void setGroupFilter(int? groupId) {
    selectedGroupId.value = groupId;
    filterStudents();
  }

  // ── تطبيق الفلتر (يعمل دائماً على students النشطين) ─────────────
  void filterStudents() {
    final q   = searchQuery.value.trim().toLowerCase();
    final gid = selectedGroupId.value;

    filteredStudents.assignAll(
      students.where((s) {
        final matchSearch = q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.code.toLowerCase().contains(q);
        final matchGroup = gid == null || s.groupId == gid;
        return matchSearch && matchGroup;
      }).toList(),
    );
  }

  Future<Student?> getStudentByCode(String code) async {
    return await _dbService.getStudentByCode(code);
  }
}
