// lib/views/booklets/booklets_page.dart
//
// spec 041 — قائمة الملازم/الكتب + إنشاء/تعديل/حذف + ملخص لكل ملزمة.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/booklet_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/booklet_math.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/booklets/booklet_widgets.dart';
import 'package:active_class/widgets/custom_widgets.dart';

BookletController _ctrl() => Get.isRegistered<BookletController>()
    ? Get.find<BookletController>()
    : Get.put(BookletController(), permanent: true);

class BookletsPage extends StatefulWidget {
  const BookletsPage({super.key});

  @override
  State<BookletsPage> createState() => _BookletsPageState();
}

class _BookletsPageState extends State<BookletsPage> {
  @override
  void initState() {
    super.initState();
    // الطلاب/المجموعات ممكن تكون اتغيّرت من بره — نحدّث الكاش عند الدخول.
    _ctrl().load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl();
    final fin = TeamModeService().canSeeFinancials;
    return Scaffold(
      appBar: AppBar(title: const Text('الملازم والكتب')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBookletFormSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ملزمة جديدة'),
      ),
      body: Obx(() {
        if (c.booklets.isEmpty) {
          return EmptyState(
            icon: Icons.menu_book_rounded,
            title: 'مفيش ملازم لسه',
            subtitle:
                'أضف ملزمة أو كتاب، حدد سعره والمجموعات، وتابع التسليم والدفع',
            actionLabel: 'ملزمة جديدة',
            onActionPressed: () => showBookletFormSheet(context),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: c.booklets.length + 1,
          itemBuilder: (_, i) => i == 0
              ? _OverallCard(fin: fin)
              : _BookletCard(booklet: c.booklets[i - 1], fin: fin),
        );
      }),
    );
  }
}

/// ملخص كل الملازم على بعض.
class _OverallCard extends StatelessWidget {
  final bool fin;
  const _OverallCard({required this.fin});

  @override
  Widget build(BuildContext context) {
    final o = _ctrl().overall();
    Widget stat(String label, Color color, {String? text, double? amount}) {
      final st =
          TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color);
      return Expanded(
        child: Column(children: [
          amount != null
              ? CurrencyText(amount,
                  style: st, textAlign: TextAlign.center, stacked: true)
              : Text(text!, style: st),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: bookletCardDecoration(context, accent: AppTheme.primaryColor),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat('إجمالي التسليم', AppTheme.primaryColor,
            text: '${o.delivered}/${o.eligible}'),
        if (fin) ...[
          stat('إجمالي المحصَّل', AppTheme.successColor, amount: o.collected),
          stat('إجمالي المتبقي',
              o.remaining > 0 ? AppTheme.errorColor : AppTheme.successColor,
              amount: o.remaining),
        ],
      ]),
    );
  }
}

class _BookletCard extends StatelessWidget {
  final Booklet booklet;
  final bool fin;
  const _BookletCard({required this.booklet, required this.fin});

  Future<void> _delete(BuildContext context) async {
    final c = _ctrl();
    final impact = await c.deleteImpact(booklet.id!);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملزمة'),
        content: Text(
          'هتتحذف "${booklet.name}" نهائيًا بكل سجلات التسليم والدفعات.\n'
          'التسليمات المسجّلة: ${impact.delivered}'
          '${fin ? '\nإجمالي المدفوع: ${FormatHelper.formatCurrency(impact.paid)}' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await c.deleteBooklet(booklet.id!);
      ToastHelper.success('اتحذفت الملزمة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl();
    final canDelete = TeamModeService().canDeletePaymentsNow;
    return Obx(() {
      final sum = c.summaryFor(booklet.id!);
      final groups = c.links.where((l) => l.bookletId == booklet.id).length;
      final total = sum.collected + sum.remaining;
      final allPaid = sum.eligible > 0 && sum.payFull == sum.eligible;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: bookletCardDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed(ROUTE_BOOKLET_DETAILS, arguments: booklet.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booklet.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('$groups مجموعة • ${sum.eligible} طالب',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (fin)
                    StatusPill(FormatHelper.formatCurrency(booklet.price),
                        AppTheme.primaryColor),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        showBookletFormSheet(context, initial: booklet);
                      } else if (v == 'delete') {
                        _delete(context);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      if (canDelete)
                        const PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                LabeledProgress(
                  label: 'التسليم',
                  trailing: '${sum.delivered} / ${sum.eligible}',
                  value: sum.eligible == 0 ? 0 : sum.delivered / sum.eligible,
                  color: AppTheme.primaryColor,
                ),
                if (fin) ...[
                  const SizedBox(height: 10),
                  LabeledProgress(
                    label: 'المحصَّل',
                    trailing:
                        '${((total <= 0 ? (allPaid ? 1 : 0) : sum.collected / total) * 100).round()}%',
                    value: total <= 0 ? (allPaid ? 1 : 0) : sum.collected / total,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final e in [
                      ('محصَّل', sum.collected, AppTheme.successColor),
                      ('من إجمالي', total, Colors.grey.shade700),
                    ])
                      Expanded(
                        child: Column(children: [
                          CurrencyText(e.$2,
                              stacked: true,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: e.$3)),
                          Text(e.$1,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusPill('دفع كامل ${sum.payFull}', AppTheme.successColor),
                    StatusPill('جزئي ${sum.payPartial}', AppTheme.warningColor),
                    StatusPill('لم يدفع ${sum.payNone}', AppTheme.errorColor),
                  ]),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// إنشاء (initial == null) أو تعديل ملزمة.
Future<void> showBookletFormSheet(BuildContext context, {Booklet? initial}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookletForm(initial: initial),
  );
}

class _BookletForm extends StatefulWidget {
  final Booklet? initial;
  const _BookletForm({this.initial});

  @override
  State<_BookletForm> createState() => _BookletFormState();
}

class _BookletFormState extends State<_BookletForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.initial == null
          ? ''
          : (widget.initial!.price == widget.initial!.price.roundToDouble()
              ? widget.initial!.price.toStringAsFixed(0)
              : widget.initial!.price.toString()));
  final Set<int> _groups = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _groups.addAll(_ctrl()
          .links
          .where((l) => l.bookletId == widget.initial!.id)
          .map((l) => l.groupId));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = parseAmount(_price.text);
    if (name.isEmpty) return ToastHelper.error('اكتب اسم الملزمة');
    if (price == null || price < 0) return ToastHelper.error('السعر غير صحيح');
    if (_groups.isEmpty) return ToastHelper.error('اختار مجموعة واحدة على الأقل');
    setState(() => _saving = true);
    final c = _ctrl();
    if (widget.initial == null) {
      await c.createBooklet(
          name: name, price: price, groupIds: _groups.toList());
    } else {
      await c.updateBooklet(widget.initial!,
          name: name, price: price, groupIds: _groups.toList());
    }
    if (mounted) Navigator.pop(context);
    ToastHelper.success('تم الحفظ');
  }

  @override
  Widget build(BuildContext context) {
    final gc = Get.isRegistered<GroupController>()
        ? Get.find<GroupController>()
        : Get.put(GroupController());
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(widget.initial == null ? 'ملزمة جديدة' : 'تعديل الملزمة',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم الملزمة/الكتاب',
                prefixIcon: Icon(Icons.menu_book_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'السعر (0 = مجانية)',
                prefixIcon: Icon(Icons.sell_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => Row(children: [
                  const Expanded(
                    child: Text('المجموعات اللي هتتوزّع عليها',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      final all = gc.groups.map((g) => g.id!).toSet();
                      if (_groups.length == all.length) {
                        _groups.clear();
                      } else {
                        _groups.addAll(all);
                      }
                    }),
                    child: Text(
                        _groups.length == gc.groups.length &&
                                gc.groups.isNotEmpty
                            ? 'إلغاء الكل'
                            : 'اختيار الكل'),
                  ),
                ])),
            Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final g in gc.groups)
                      FilterChip(
                        label: Text(g.name),
                        selected: _groups.contains(g.id),
                        onSelected: (v) => setState(() {
                          v ? _groups.add(g.id!) : _groups.remove(g.id);
                        }),
                      ),
                  ],
                )),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
