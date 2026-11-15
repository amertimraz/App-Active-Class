// lib/controllers/group_controller.dart

import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

/// قسم في قايمة المجموعات: مجموعات سنتر واحد ([center] = null يعني «بدون سنتر»).
class CenterSection {
  final String? center;
  final List<Group> groups;
  const CenterSection(this.center, this.groups);
}

class GroupController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  final RxList<Group> groups = <Group>[].obs;
  final RxBool isLoading = false.obs;

  /// فلتر السنتر في شاشة المجموعات: null = الكل، [kNoCenterFilter] = المجموعات
  /// اللي من غير سنتر، غير كده اسم سنتر. (تنظيم وفلترة بس — مفيش عزل.)
  final RxnString selectedCenter = RxnString();
  static const String kNoCenterFilter = '__none__';

  /// أسماء السناتر المستخدمة فعلًا (من غير تكرار ومن غير فاضي)، مرتّبة.
  List<String> get centers => centersOf(groups);

  /// نفس الحساب ده كدالة صرفة عشان تتختبر بسهولة.
  static List<String> centersOf(Iterable<Group> groups) {
    final seen = <String>{};
    for (final g in groups) {
      final c = normalizeCenter(g.center);
      if (c != null) seen.add(c);
    }
    return seen.toList()..sort();
  }

  /// تطبيع اسم السنتر: مسافات زيادة تتشال، والفاضي = null.
  static String? normalizeCenter(String? raw) {
    final c = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return c.isEmpty ? null : c;
  }

  /// بيقسّم المجموعات لأقسام: كل سنتر (مرتّبة بالاسم) وتحته مجموعاته، وبعدهم
  /// «بدون سنتر». الأقسام الفاضية بتتشال. لو مفيش ولا سنتر → قسم واحد بدون عنوان.
  static List<CenterSection> sectionsOf(Iterable<Group> groups) {
    final byCenter = <String, List<Group>>{};
    final none = <Group>[];
    for (final g in groups) {
      final c = normalizeCenter(g.center);
      if (c == null) {
        none.add(g);
      } else {
        byCenter.putIfAbsent(c, () => []).add(g);
      }
    }
    final names = byCenter.keys.toList()..sort();
    return [
      for (final n in names) CenterSection(n, byCenter[n]!),
      if (none.isNotEmpty) CenterSection(null, none),
    ];
  }

  /// يحط [center] (أو يشيله لو null) على كل المجموعات اللي أرقامها [ids].
  /// بيحدّث القايمة محليًا وبيسجّل التعديل للمزامنة. بيرجّع true لو كله نجح.
  Future<bool> setCenterForGroups(Iterable<int> ids, String? center) async {
    final target = normalizeCenter(center);
    var ok = true;
    for (final id in ids.toSet()) {
      final i = groups.indexWhere((g) => g.id == id);
      if (i == -1) continue;
      final g = groups[i];
      if (normalizeCenter(g.center) == target) continue;
      final updated =
          target == null ? g.copyWith(clearCenter: true) : g.copyWith(center: target);
      try {
        await _dbService.updateGroup(updated);
        groups[i] = updated;
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) ToastHelper.error('حدث خطأ في تحديث بعض المجموعات');
    return ok;
  }

  /// يغيّر اسم سنتر على كل مجموعاته (ولو الاسم الجديد موجود بيتدمجوا).
  Future<bool> renameCenter(String from, String to) {
    final ids = [
      for (final g in groups)
        if (normalizeCenter(g.center) == from && g.id != null) g.id!
    ];
    return setCenterForGroups(ids, to);
  }

  /// يفك السنتر: مجموعاته تفضل موجودة بس من غير سنتر.
  Future<bool> dissolveCenter(String name) => renameCenter(name, '');

  /// هل المجموعة دي تظهر مع فلتر السنتر [filter]؟
  static bool matchesCenter(Group g, String? filter) {
    if (filter == null) return true;
    final c = normalizeCenter(g.center);
    if (filter == kNoCenterFilter) return c == null;
    return c == filter;
  }

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
