// lib/controllers/group_controller.dart

import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
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

  /// يضيف مجموعة جديدة. بيرجّع true لو نجح فعلاً — الشاشة المستدعية
  /// هي المسؤولة عن إظهار رسالة النجاح، عشان ميحصلش "تم الحفظ" وهمي
  /// لو الحفظ فشل فعلياً (زي تكرار اسم/كود المجموعة).
  Future<bool> addGroup(Group group) async {
    try {
      final id = await _dbService.insertGroup(group);
      final newGroup = group.copyWith(id: id);
      groups.add(newGroup);
      return true;
    } catch (e) {
      ToastHelper.error(_groupErrorMessage(e));
      return false;
    }
  }

  Future<bool> updateGroup(Group group) async {
    try {
      await _dbService.updateGroup(group);
      final index = groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        groups[index] = group;
      }
      return true;
    } catch (e) {
      ToastHelper.error(_groupErrorMessage(e));
      return false;
    }
  }

  /// يترجم أخطاء قاعدة البيانات الشائعة لرسالة مفهومة (زي تكرار
  /// اسم/كود المجموعة — كلاهما UNIQUE) بدل رسالة عامة تخفي السبب.
  String _groupErrorMessage(Object e) {
    if (e is DatabaseException && e.isUniqueConstraintError()) {
      return 'يوجد مجموعة بنفس الاسم أو الكود بالفعل — غيّر البيانات وحاول تاني';
    }
    return 'حدث خطأ في حفظ المجموعة';
  }

  /// يحذف مجموعة نهائياً — بدون أي تأكيد داخلي (التأكيد وتوضيح حجم
  /// الحذف المتتالي مسؤولية الشاشة المستدعية). بيرجّع true لو نجح
  /// وبيحدّث قائمة المجموعات محلياً على طول.
  /// نقطة الاستدعاء الوحيدة لحذف مجموعة من كل التطبيق — الفحص هنا (بدل
  /// تكراره في كل شاشة) يضمن إن المنع يتطبّق بنفس الاتساق من أي مكان.
  /// راجع specs/006-archived-group-delete-protection.
  Future<bool> deleteGroup(int id) async {
    try {
      final archivedCount = await _dbService.getArchivedStudentCountForGroup(id);
      if (archivedCount > 0) {
        ToastHelper.error(
            'لا يمكن حذف المجموعة — بها $archivedCount طالب مؤرشف. '
            'تعامل معهم أولاً من شاشة الأرشيف.');
        return false;
      }
      await _dbService.deleteGroup(id);
      groups.removeWhere((g) => g.id == id);
      return true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في حذف المجموعة');
      return false;
    }
  }

  Future<int> getGroupStudentCount(int groupId) async {
    return await _dbService.getGroupStudentCount(groupId);
  }
}
