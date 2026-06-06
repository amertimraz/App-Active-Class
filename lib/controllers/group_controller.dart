// lib/controllers/group_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

class GroupController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final RxList<Group> groups = <Group>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadGroups();
  }

  Future<void> loadGroups() async {
    isLoading(true);
    try {
      final loadedGroups = await _dbService.getAllGroups();
      groups.assignAll(loadedGroups);
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل المجموعات');
    } finally {
      isLoading(false);
    }
  }

  Future<void> addGroup(Group group) async {
    try {
      final id = await _dbService.insertGroup(group);
      final newGroup = group.copyWith(id: id);
      groups.add(newGroup);
      ToastHelper.success('تم إضافة المجموعة بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في إضافة المجموعة');
    }
  }

  Future<void> updateGroup(Group group) async {
    try {
      await _dbService.updateGroup(group);
      final index = groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        groups[index] = group;
      }
      ToastHelper.success('تم تحديث المجموعة بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحديث المجموعة');
    }
  }

  Future<void> deleteGroup(int id) async {
    Get.defaultDialog(
      title: 'تأكيد الحذف',
      content: const Text('هل أنت متأكد من حذف هذه المجموعة؟'),
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
              await _dbService.deleteGroup(id);
              groups.removeWhere((g) => g.id == id);
              ToastHelper.success('تم حذف المجموعة بنجاح');
            } catch (e) {
              ToastHelper.error('حدث خطأ في حذف المجموعة');
            }
          },
          child: const Text('حذف'),
        ),
      ],
    );
  }

  Future<int> getGroupStudentCount(int groupId) async {
    return await _dbService.getGroupStudentCount(groupId);
  }
}
