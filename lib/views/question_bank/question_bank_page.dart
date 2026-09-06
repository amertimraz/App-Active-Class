// lib/views/question_bank/question_bank_page.dart
//
// spec 025 — شاشة بنك الأسئلة: تصفّح/بحث/فلترة (مادة/وسم) + إضافة/تعديل/
// حذف. المحرّر عبر question_editor_sheet.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/question_bank_controller.dart';
import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/question_bank/question_editor_sheet.dart';

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  final QuestionBankController c = Get.isRegistered<QuestionBankController>()
      ? Get.find<QuestionBankController>()
      : Get.put(QuestionBankController());
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _subjectSuggestions() => DatabaseService().distinctSubjects();

  Future<void> _add() async {
    final q = await showBankQuestionEditor(context,
        subjectSuggestions: await _subjectSuggestions());
    if (q != null) {
      await c.add(q);
      if (mounted) ToastHelper.success('اتضاف للبنك');
    }
  }

  Future<void> _edit(BankQuestion bq) async {
    final q = await showBankQuestionEditor(context,
        initial: bq, subjectSuggestions: await _subjectSuggestions());
    if (q != null) {
      await c.save(q);
      if (mounted) ToastHelper.success('اتحفظ');
    }
  }

  Future<void> _delete(BankQuestion bq) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف السؤال؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text('هيتشال من البنك نهائيًا. الامتحانات اللي استخدمت نسخة منه مش هتتأثر.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (ok == true && bq.id != null) await c.remove(bq.id!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بنك الأسئلة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('سؤال جديد', style: TextStyle(fontFamily: 'Cairo')),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ابحث في نص السؤال…',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            c.setQuery('');
                            setState(() {});
                          }),
                ),
                onChanged: (v) {
                  c.setQuery(v);
                  setState(() {});
                },
              ),
            ),
            Obx(() {
              final subjects = c.subjects;
              final tags = c.tags;
              if (subjects.isEmpty && tags.isEmpty) return const SizedBox.shrink();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Row(children: [
                  for (final s in subjects)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(s,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                        selected: c.subjectFilter.value == s,
                        onSelected: (sel) =>
                            c.setSubjectFilter(sel ? s : null),
                      ),
                    ),
                  if (tags.isNotEmpty && subjects.isNotEmpty)
                    Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: cs.onSurface.withValues(alpha: 0.15)),
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text('#$t',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                        selected: c.tagFilter.value == t,
                        onSelected: (sel) => c.setTagFilter(sel ? t : null),
                      ),
                    ),
                ]),
              );
            }),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value && c.count == 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = c.items;
                if (c.count == 0) {
                  return _empty(cs, 'البنك فاضي — أضف أول سؤال بالزر تحت.');
                }
                if (list.isEmpty) {
                  return _empty(cs, 'لا توجد أسئلة مطابقة للبحث/الفلتر.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _card(cs, list[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.55))),
        ),
      );

  Widget _card(ColorScheme cs, BankQuestion bq) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _edit(bq),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(bq.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _delete(bq),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _tag(cs, bq.type == ExamQuestionType.trueFalse ? 'صح/خطأ' : 'اختيار',
                    cs.primary),
                if (bq.subject.isNotEmpty) _tag(cs, bq.subject, const Color(0xFF10B981)),
                for (final t in bq.tags) _tag(cs, '#$t', const Color(0xFF64748B)),
                _tag(cs, '${FormatHelper.formatGrade(bq.points)} د',
                    cs.onSurface.withValues(alpha: 0.5)),
                if (bq.imageUrl != null)
                  _tag(cs, '📷', cs.onSurface.withValues(alpha: 0.5)),
              ]),
            ]),
          ),
        ),
      );

  Widget _tag(ColorScheme cs, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}
