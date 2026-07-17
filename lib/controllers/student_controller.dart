// lib/controllers/student_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
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
  Future<Student?> addStudent(Student student) async {
    try {
      final id = await _dbService.insertStudent(student);
      final newStudent = student.copyWith(id: id);
      students.add(newStudent);
      filterStudents(); // أعِد تطبيق الفلتر بدل الإضافة المباشرة
      return newStudent;
    } catch (e) {
      ToastHelper.error('حدث خطأ في إضافة الطالب');
      return null;
    }
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
      await _dbService.updateStudent(student);
      final index = students.indexWhere((s) => s.id == student.id);
      if (index != -1) students[index] = student;
      filterStudents();
      ToastHelper.success('تم تحديث الطالب بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحديث الطالب');
    }
  }

  // ── حذف طالب ────────────────────────────────────────────────────
  Future<void> deleteStudent(int id) async {
    Get.defaultDialog(
      title: 'تأكيد الحذف',
      content: const Text('هل أنت متأكد من حذف هذا الطالب؟'),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Get.back();
            try {
              await _dbService.deleteStudent(id);
              students.removeWhere((s) => s.id == id);
              filterStudents();
              ToastHelper.success('تم حذف الطالب بنجاح');
            } catch (e) {
              ToastHelper.error('حدث خطأ في حذف الطالب');
            }
          },
          child: const Text('حذف'),
        ),
      ],
    );
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
