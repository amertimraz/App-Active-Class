// lib/views/question_bank/question_bank_picker_page.dart
//
// spec 025 — اختيار أسئلة من البنك لإضافتها لامتحان. وضعان: اختيار فردي
// بعلامات، و"أضف N عشوائي" من نطاق (كل البنك / مادة / وسم).
// يرجّع List<BankQuestion> عبر Get.back(result: ...)، أو null عند الإلغاء.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/question_bank_controller.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/services/question_bank_picker.dart';
import 'package:active_class/utils/helpers.dart';

class QuestionBankPickerPage extends StatefulWidget {
  const QuestionBankPickerPage({super.key});

  @override
  State<QuestionBankPickerPage> createState() => _QuestionBankPickerPageState();
}

class _QuestionBankPickerPageState extends State<QuestionBankPickerPage> {
  final QuestionBankController c = Get.isRegistered<QuestionBankController>()
      ? Get.find<QuestionBankController>()
      : Get.put(QuestionBankController());

  final Set<int> _selected = {};
  final _searchCtrl = TextEditingController();

  // "أضف N عشوائي"
  String? _randSubject;
  String? _randTag;
  int _randN = 5;

  @override
  void dispose() {
    _searchCtrl.dispose();
    // الفلاتر مشتركة مع QuestionBankController — رجّعها عشان شاشة البنك
    // متفتحش مفلترة بعد الاختيار.
    c.clearFilters();
    super.dispose();
  }

  void _confirmSelected() {
    final picked = c.items.where((q) => _selected.contains(q.id)).toList();
    if (picked.isEmpty) {
      ToastHelper.info('اختَر سؤالًا واحدًا على الأقل');
      return;
    }
    Get.back(result: picked);
  }

  void _confirmRandom() {
    if (_randN <= 0) {
      ToastHelper.info('اكتب عددًا أكبر من صفر');
      return;
    }
    final pool = c.pool(subject: _randSubject, tag: _randTag);
    if (pool.isEmpty) {
      ToastHelper.info('لا توجد أسئلة في هذا النطاق');
      return;
    }
    Get.back(result: pickRandom(pool, _randN));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('أضف من البنك',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'اختيار'),
                Tab(text: 'عشوائي'),
              ],
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            ),
          ),
          body: Obx(() {
            if (c.count == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('البنك فاضي',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 6),
                    const Text('أضف أسئلة للبنك أولًا من "بنك الأسئلة" في القائمة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ]),
                ),
              );
            }
            return TabBarView(children: [_selectTab(cs), _randomTab(cs)]);
          }),
        ),
      ),
    );
  }

  // ── تبويب الاختيار الفردي ──────────────────────────────────────────
  Widget _selectTab(ColorScheme cs) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          decoration: const InputDecoration(
              hintText: 'ابحث…',
              hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true),
          onChanged: (v) {
            c.setQuery(v);
            setState(() {});
          },
        ),
      ),
      Obx(() {
        final subjects = c.subjects;
        if (subjects.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final s in subjects)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(s,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                  selected: c.subjectFilter.value == s,
                  onSelected: (sel) => c.setSubjectFilter(sel ? s : null),
                ),
              ),
          ]),
        );
      }),
      Expanded(
        child: Obx(() {
          final list = c.items;
          if (list.isEmpty) {
            return Center(
                child: Text('لا نتائج',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: cs.onSurface.withValues(alpha: 0.5))));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final q = list[i];
              final sel = _selected.contains(q.id);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                      color: sel
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.1)),
                ),
                child: CheckboxListTile(
                  dense: true,
                  value: sel,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(q.id!);
                    } else {
                      _selected.remove(q.id);
                    }
                  }),
                  title: Text(q.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${q.type == ExamQuestionType.trueFalse ? 'صح/خطأ' : 'اختيار'}'
                      '${q.subject.isNotEmpty ? ' · ${q.subject}' : ''}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          color: cs.onSurface.withValues(alpha: 0.55))),
                ),
              );
            },
          );
        }),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: FilledButton(
            onPressed: _confirmSelected,
            child: Text('أضف (${_selected.length})',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]);
  }

  // ── تبويب "أضف N عشوائي" ───────────────────────────────────────────
  Widget _randomTab(ColorScheme cs) {
    return Obx(() {
      final subjects = c.subjects;
      final tags = c.tags;
      final pool = c.pool(subject: _randSubject, tag: _randTag);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('النطاق',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: const Text('كل البنك',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              selected: _randSubject == null && _randTag == null,
              onSelected: (_) => setState(() {
                _randSubject = null;
                _randTag = null;
              }),
            ),
            for (final s in subjects)
              ChoiceChip(
                label: Text(s,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                selected: _randSubject == s,
                onSelected: (_) => setState(() {
                  _randSubject = _randSubject == s ? null : s;
                  _randTag = null;
                }),
              ),
            for (final t in tags)
              ChoiceChip(
                label: Text('#$t',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                selected: _randTag == t,
                onSelected: (_) => setState(() {
                  _randTag = _randTag == t ? null : t;
                  _randSubject = null;
                }),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('عدد الأسئلة:',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: '$_randN',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontFamily: 'Cairo'),
                onChanged: (v) => _randN = int.tryParse(v) ?? _randN,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('متاح في هذا النطاق: ${pool.length}',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: pool.isEmpty ? null : _confirmRandom,
            child: const Text('أضف عشوائي',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          ),
        ],
      );
    });
  }
}
