// lib/controllers/student_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

class StudentController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final RxList<Student> students = <Student>[].obs;
  final RxList<Student> filteredStudents = <Student>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final Rxn<int> selectedGroupId = Rxn<int>();

  @override
  void onInit() {
    super.onInit();
    debounce(searchQuery, (_) => filterStudents(), time: const Duration(milliseconds: 180));
    loadAllStudents();
  }

  Future<void> loadStudentsByGroup(int groupId) async {
    isLoading(true);
    try {
      final loadedStudents = await _dbService.getStudentsByGroup(groupId);
      students.assignAll(loadedStudents);
      filteredStudents.assignAll(loadedStudents);
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الطلاب');
    } finally {
      isLoading(false);
    }
  }

  Future<void> loadAllStudents() async {
    isLoading(true);
    try {
      final loadedStudents = await _dbService.getAllStudents();
      students.assignAll(loadedStudents);
      filteredStudents.assignAll(loadedStudents);
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل الطلاب');
    } finally {
      isLoading(false);
    }
  }

  Future<List<Group>> loadAllGroups() async {
    return await _dbService.getAllGroups();
  }

  Future<Student?> addStudent(Student student) async {
    try {
      final id = await _dbService.insertStudent(student);
      final newStudent = student.copyWith(id: id);
      students.add(newStudent);
      filteredStudents.add(newStudent);
      ToastHelper.success('تم إضافة الطالب بنجاح');
      return newStudent;
    } catch (e) {
      ToastHelper.error('حدث خطأ في إضافة الطالب');
      return null;
    }
  }

  /// توليد كود الطالب التالي بناءً على بادئة كود المجموعة مع تسلسل يبدأ من 01
  Future<String> generateNextStudentCode({required String groupPrefix, required int groupId}) async {
    // اجلب طلاب المجموعة الحالية
    final existing = await _dbService.getStudentsByGroup(groupId);
    // استخرج الملحق الرقمي بعد البادئة
    int maxSuffix = 0;
    for (final s in existing) {
      if (s.code.startsWith(groupPrefix)) {
        final suffix = s.code.substring(groupPrefix.length);
        final numVal = int.tryParse(suffix);
        if (numVal != null && numVal > maxSuffix) {
          maxSuffix = numVal;
        }
      }
    }
    final next = maxSuffix + 1;
    final suffixStr = next.toString().padLeft(2, '0');
    return '$groupPrefix$suffixStr';
  }

  Future<void> updateStudent(Student student) async {
    try {
      await _dbService.updateStudent(student);
      final index = students.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        students[index] = student;
      }
      filterStudents();
      ToastHelper.success('تم تحديث الطالب بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحديث الطالب');
    }
  }

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

  void searchStudents(String query) {
    searchQuery.value = query;
  }

  void setGroupFilter(int? groupId) {
    selectedGroupId.value = groupId;
    filterStudents();
  }

  void filterStudents() {
    final q = searchQuery.value.trim();
    final gid = selectedGroupId.value;

    filteredStudents.assignAll(
      students.where((student) {
        final matchSearch = q.isEmpty || student.name.contains(q) || student.code.contains(q);
        final matchGroup = gid == null || student.groupId == gid;
        return matchSearch && matchGroup;
      }).toList(),
    );
  }

  Future<Student?> getStudentByCode(String code) async {
    return await _dbService.getStudentByCode(code);
  }
}
