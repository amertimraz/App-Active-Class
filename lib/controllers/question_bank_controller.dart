// lib/controllers/question_bank_controller.dart
//
// spec 025 — بنك الأسئلة: تحميل + فلترة (مادة/وسم/بحث نصّي، كلها في
// الذاكرة) + CRUD. متزامن عبر الفريق (SyncEngine._refreshUiForTable
// بينادي refresh عند وصول تغيير).
import 'package:get/get.dart';

import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/services/database_service.dart';

class QuestionBankController extends GetxController {
  final DatabaseService _db = DatabaseService();

  final RxList<BankQuestion> _all = <BankQuestion>[].obs;
  final RxnString subjectFilter = RxnString();
  final RxnString tagFilter = RxnString();
  final RxString query = ''.obs;
  final RxBool isLoading = false.obs;

  int get count => _all.length;

  /// الأسئلة بعد تطبيق الفلاتر (مادة + وسم + بحث نصّي).
  List<BankQuestion> get items {
    final s = subjectFilter.value;
    final t = tagFilter.value;
    final q = query.value.trim().toLowerCase();
    return _all.where((bq) {
      if (s != null && bq.subject != s) return false;
      if (t != null && !bq.tags.contains(t)) return false;
      if (q.isNotEmpty && !bq.text.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  List<String> get subjects {
    final set = <String>{};
    for (final q in _all) {
      if (q.subject.trim().isNotEmpty) set.add(q.subject);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get tags {
    final set = <String>{};
    for (final q in _all) {
      set.addAll(q.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// أسئلة البنك ضمن نطاق ("all" / "subject:X" / "tag:Y") — لـ"أضف N عشوائي".
  List<BankQuestion> pool({String? subject, String? tag}) => _all.where((bq) {
        if (subject != null && bq.subject != subject) return false;
        if (tag != null && !bq.tags.contains(tag)) return false;
        return true;
      }).toList();

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    _all.assignAll(await _db.getBankQuestions());
    isLoading.value = false;
  }

  Future<int> add(BankQuestion q) async {
    final id = await _db.insertBankQuestion(q);
    await refresh();
    return id;
  }

  Future<void> save(BankQuestion q) async {
    await _db.updateBankQuestion(q);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _db.deleteBankQuestion(id);
    await refresh();
  }

  void setSubjectFilter(String? s) => subjectFilter.value = s;
  void setTagFilter(String? t) => tagFilter.value = t;
  void setQuery(String q) => query.value = q;
}
