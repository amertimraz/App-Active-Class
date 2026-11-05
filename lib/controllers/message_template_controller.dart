// lib/controllers/message_template_controller.dart
//
// رسائل واتساب المحفوظة: تحميل/إضافة/تعديل/تكرار/حذف (محلية). أول مرة بس
// بنزرع رسايل جاهزة (المعلم يعدّل عليها أو يمسحها، ومش بتتزرع تاني).
import 'dart:convert';

import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/message_templates.dart';

const String _kSeededKey = 'message_templates_seeded';

class MessageTemplateController extends GetxController {
  static MessageTemplateController get to => Get.find();

  final templates = <MessageTemplate>[].obs;
  final loading = false.obs;

  final _db = DatabaseService();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  static MessageTemplate fromRow(Map<String, Object?> r) {
    List<String> levels = const [];
    final raw = r[COL_MT_LEVELS] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        levels = (jsonDecode(raw) as List).map((e) => '$e').toList();
      } catch (_) {}
    }
    return MessageTemplate(
      id: r[COL_MT_ID] as int?,
      title: (r[COL_MT_TITLE] as String?) ?? '',
      body: (r[COL_MT_BODY] as String?) ?? '',
      category: MessageCategoryX.fromDb(r[COL_MT_CATEGORY] as String?),
      levels: levels,
    );
  }

  static Map<String, Object?> toRow(MessageTemplate t, {int sort = 0}) => {
        COL_MT_TITLE: t.title.trim(),
        COL_MT_BODY: t.body,
        COL_MT_CATEGORY: t.category.dbValue,
        COL_MT_LEVELS: jsonEncode(
            t.levels.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
        COL_MT_SORT: sort,
      };

  Future<void> load() async {
    loading.value = true;
    try {
      if (await _db.getSetting(_kSeededKey) != '1') {
        final existing = await _db.getMessageTemplateRows();
        if (existing.isEmpty) {
          var i = 0;
          for (final s in starterTemplates()) {
            await _db.insertMessageTemplateRow(toRow(s, sort: i++));
          }
        }
        await _db.setSetting(_kSeededKey, '1');
      }
      final rows = await _db.getMessageTemplateRows();
      templates.assignAll(rows.map(fromRow));
    } finally {
      loading.value = false;
    }
  }

  Future<void> save(MessageTemplate t) async {
    if (!t.isValid) return;
    if (t.id == null) {
      await _db.insertMessageTemplateRow(toRow(t, sort: templates.length));
    } else {
      await _db.updateMessageTemplateRow(t.id!, toRow(t));
    }
    await load();
  }

  Future<void> duplicate(MessageTemplate t) async {
    await _db.insertMessageTemplateRow(toRow(
        MessageTemplate(
            title: '${t.title} (نسخة)',
            body: t.body,
            category: t.category,
            levels: t.levels),
        sort: templates.length));
    await load();
  }

  Future<void> delete(int id) async {
    await _db.deleteMessageTemplateRow(id);
    await load();
  }
}
