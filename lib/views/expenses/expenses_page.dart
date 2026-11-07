// lib/views/expenses/expenses_page.dart
//
// مصاريف المعلم وصافي الدخل: لكل شهر — المحصّل الفعلي (من غير إسقاط
// المديونية) − المصاريف = الصافي. المصاريف محلية على الجهاز فقط.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/expense_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/views/help/help_widgets.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _db = DatabaseService();
  late DateTime _month;
  bool _loading = true;
  double _collected = 0;
  List<Expense> _expenses = const [];

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final from = _month;
    final to = DateTime(_month.year, _month.month + 1, 1);
    final expenses = await _db.getExpensesInRange(from, to);
    final payments = await _db.getAllPayments();
    final collected = payments
        .where((p) =>
            p.isCollection && !p.date.isBefore(from) && p.date.isBefore(to))
        .fold<double>(0, (s, p) => s + p.amount);
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _collected = collected;
      _loading = false;
    });
  }

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final n = DateTime.now();
    if (next.isAfter(DateTime(n.year, n.month, 1))) return;
    _month = next;
    _load();
  }

  Future<void> _edit([Expense? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ExpenseSheet(existing: existing, defaultMonth: _month),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المصروف؟'),
        content: Text(
            '${expenseCategoryLabel(e.category)} — ${FormatHelper.formatCurrency(e.amount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteExpense(e.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ni = NetIncome.compute(_collected, _expenses);
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(_month);
    final n = DateTime.now();
    final canNext = _month.isBefore(DateTime(n.year, n.month, 1));

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context,
          title: 'المصاريف وصافي الدخل',
          actions: const [HelpButton(topicId: 'expenses')]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: t.chalk,
        foregroundColor: t.onChalk,
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, 96),
              children: [
                Row(children: [
                  IconButton(
                    tooltip: 'الشهر السابق',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(monthLabel,
                        textAlign: TextAlign.center,
                        style: AppType.title.copyWith(color: t.ink)),
                  ),
                  IconButton(
                    tooltip: 'الشهر التالي',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: canNext ? () => _shift(1) : null,
                  ),
                ]),
                const SizedBox(height: AppSpace.sm),
                AppPanel(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('صافي الدخل',
                          style: AppType.label.copyWith(color: t.inkSoft)),
                      CurrencyText(ni.net,
                          style: AppType.title.copyWith(
                              fontSize: 28,
                              color: ni.net >= 0 ? t.positive : t.danger)),
                      const SizedBox(height: AppSpace.md),
                      Row(children: [
                        Expanded(
                            child: _Figure('المحصّل', _collected, t.positive)),
                        Expanded(
                            child: _Figure('المصاريف', ni.expenses, t.danger)),
                      ]),
                      Text('المحصّل = الفلوس اللي دخلت فعلًا في الشهر ده (من غير إسقاط المديونية).',
                          style: AppType.caption.copyWith(color: t.inkFaint)),
                    ],
                  ),
                ),
                if (ni.byCategory.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text('حسب التصنيف',
                      style: AppType.label.copyWith(color: t.ink)),
                  const SizedBox(height: AppSpace.sm),
                  for (final e in (ni.byCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(
                            child: Text(expenseCategoryLabel(e.key),
                                style: AppType.body.copyWith(color: t.ink))),
                        CurrencyText(e.value,
                            style: AppType.body.copyWith(color: t.inkSoft)),
                      ]),
                    ),
                ],
                const SizedBox(height: AppSpace.lg),
                Text('مصاريف الشهر',
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.sm),
                if (_expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                    child: Text('مفيش مصاريف متسجّلة للشهر ده. اضغط «إضافة مصروف».',
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: t.inkSoft)),
                  )
                else
                  for (final e in _expenses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: AppPanel(
                        onTap: () => _edit(e),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpace.md, AppSpace.sm, AppSpace.xs, AppSpace.sm),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(expenseCategoryLabel(e.category),
                                    style:
                                        AppType.label.copyWith(color: t.ink)),
                                Text(
                                  DateFormat('d MMMM', 'ar').format(e.date) +
                                      ((e.note ?? '').isEmpty
                                          ? ''
                                          : ' • ${e.note}'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.caption
                                      .copyWith(color: t.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          CurrencyText(e.amount,
                              style: AppType.label.copyWith(color: t.danger)),
                          IconButton(
                            tooltip: 'حذف',
                            icon: Icon(Icons.delete_rounded,
                                size: 20, color: t.danger),
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            onPressed: () => _delete(e),
                          ),
                        ]),
                      ),
                    ),
              ],
            ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Figure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppType.caption.copyWith(color: t.inkSoft)),
      CurrencyText(value, style: AppType.label.copyWith(color: color)),
    ]);
  }
}

class _ExpenseSheet extends StatefulWidget {
  final Expense? existing;
  final DateTime defaultMonth;
  const _ExpenseSheet({this.existing, required this.defaultMonth});

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _category;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e == null
            ? ''
            : (e.amount == e.amount.roundToDouble()
                ? e.amount.toStringAsFixed(0)
                : e.amount.toString()));
    _note = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? 'other';
    final now = DateTime.now();
    final inMonth =
        now.year == widget.defaultMonth.year && now.month == widget.defaultMonth.month;
    _date = e?.date ?? (inMonth ? now : widget.defaultMonth);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = double.tryParse(
        PhoneHelperDigits.latin(_amount.text).replaceAll(',', '.').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'اكتب مبلغ صحيح أكبر من صفر');
      return;
    }
    final e = Expense(
      id: widget.existing?.id,
      date: _date,
      amount: amount,
      category: _category,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final db = DatabaseService();
    if (e.id == null) {
      await db.insertExpense(e);
    } else {
      await db.updateExpense(e);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'مصروف جديد' : 'تعديل المصروف',
              style: AppType.title.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _amount,
            autofocus: widget.existing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]'))
            ],
            decoration: const InputDecoration(
                labelText: 'المبلغ', prefixIcon: Icon(Icons.payments_rounded)),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kExpenseCategories.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _category == e.key,
                onSelected: (_) => setState(() => _category = e.key),
              ),
          ]),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded),
            label: Text(DateFormat('d MMMM yyyy', 'ar').format(_date)),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes_rounded)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_error!, style: AppType.body.copyWith(color: t.danger)),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// تحويل الأرقام العربية الهندية لأرقام لاتينية (للمبلغ المكتوب).
class PhoneHelperDigits {
  static String latin(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }
}
