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

  /// القائمة الكاملة — مصدر الحقيقة، لا تُمس إلا بـ loadAllStudents
  final RxList<Student> students = <Student>[].obs;

  /// القائمة المعروضة بعد تطبيق البحث والفلتر
  final RxList<Student> filteredStudents = <Student>[].obs;

  final RxBool    isLoading    = false.obs;
  final RxString  searchQuery  = ''.obs;
  final Rxn<int>  selectedGroupId = Rxn<int>();

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
      final loaded = await _dbService.getAllStudents();
      students.assignAll(loaded);
      filterStudents(); // طبّق الفلتر الحالي (إن وُجد)
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الطلاب');
    } finally {
      isLoading(false);
    }
  }

  /// تحميل طلاب مجموعة — يُحدِّث `students` AND يضع الفلتر
  /// بحيث ترى `filteredStudents` طلاب المجموعة فقط
  Future<void> loadStudentsByGroup(int groupId) async {
    isLoading(true);
    try {
      final loaded = await _dbService.getAllStudents();
      students.assignAll(loaded);          // حدِّث المصدر الكامل
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
  Future<Student?> addStudent(Student student) async {
    final licenseErr =
        Get.find<LicenseController>().checkCanAddStudent(students.length);
    if (licenseErr != null) {
      ToastHelper.error(licenseErr);
      return null;
    }
    try {
      final id = await _dbService.insertStudent(student);
      final newStudent = student.copyWith(id: id);
      students.add(newStudent);
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

  // ── تعديل طالب ──────────────────────────────────────────────────
  Future<void> updateStudent(Student student) async {
    try {
      // لازم نعرف الكود/التليفون القديمين قبل التحديث — لو أي منهم
      // تغيّر، مستند ملخص المتابعة القديم (مبني على القيم القديمة)
      // يفضل معلّق على Firestore للأبد من غير ده.
      final old = students.firstWhereOrNull((s) => s.id == student.id);
      await _dbService.updateStudent(student);
      final index = students.indexWhere((s) => s.id == student.id);
      if (index != -1) students[index] = student;
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

  // ── حذف طالب ────────────────────────────────────────────────────
  /// يحذف طالب نهائياً — بدون أي تأكيد داخلي (التأكيد وتوضيح حجم
  /// الحذف المتتالي مسؤولية الشاشة المستدعية، زي deleteGroup تمامًا).
  /// بيرجّع true لو نجح وبيحدّث قائمة الطلاب محلياً على طول.
  Future<bool> deleteStudent(int id) async {
    try {
      final student = students.firstWhereOrNull((s) => s.id == id);
      await _dbService.deleteStudent(id);
      students.removeWhere((s) => s.id == id);
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

  // ── تطبيق الفلتر (يعمل دائماً على students الكاملة) ─────────────
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
