// lib/views/booklets/booklet_details_page.dart
//
// spec 041 — تفاصيل ملزمة: الطلاب المؤهَّلون، تسليم مستقل عن الدفع،
// دفعات جزئية، تسجيل سريع (استلم + دفع)، بحث، فلاتر، وسجل تاريخي.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/controllers/booklet_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/booklet_message.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/booklet_math.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/booklets/booklet_widgets.dart';
import 'package:active_class/widgets/custom_widgets.dart';

class BookletDetailsPage extends StatefulWidget {
  const BookletDetailsPage({super.key});

  @override
  State<BookletDetailsPage> createState() => _BookletDetailsPageState();
}

class _BookletDetailsPageState extends State<BookletDetailsPage> {
  final BookletController c = Get.find<BookletController>();
  final int bookletId = Get.arguments as int;
  final _fin = TeamModeService().canSeeFinancials;
  final _search = TextEditingController();

  DeliveryFilter _delivery = DeliveryFilter.all;
  PayFilter _pay = PayFilter.all;
  bool _historical = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _money(double v) => FormatHelper.formatCurrency(v);

  /// تسجيل سريع بضغطة: تسليم (لو لسه) + دفع المتبقي كاملًا (لو فيه)،
  /// مع "تراجع" من الـSnackBar.
  Future<void> _quick(BookletStudentRow r) async {
    final sid = r.student.id!;
    final wasDelivered = r.delivered;
    if (!wasDelivered) await c.setDelivered(bookletId, sid, true);
    var paidNow = 0.0;
    int? paymentId;
    if (_fin && r.remaining > 0) {
      final err = await c.addPayment(bookletId, sid, r.remaining);
      if (err != null) return ToastHelper.error(err);
      paidNow = r.remaining;
      final mine = c.paymentsOf(bookletId, sid);
      if (mine.isNotEmpty) paymentId = mine.first.id;
    }
    if (!mounted) return;
    final canUndo =
        paymentId == null || TeamModeService().canDeletePaymentsNow;
    final msg = '${r.student.name}: ${wasDelivered ? '' : 'استلم'}'
        '${!wasDelivered && paidNow > 0 ? ' + ' : ''}'
        '${paidNow > 0 ? 'دفع ${_money(paidNow)}' : ''}';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
      action: canUndo
          ? SnackBarAction(
              label: 'تراجع',
              onPressed: () async {
                if (paymentId != null) await c.deletePayment(paymentId);
                if (!wasDelivered) await c.setDelivered(bookletId, sid, false);
              },
            )
          : null,
    ));
  }

  Future<void> _deliverAll() async {
    final pending =
        c.rowsFor(bookletId).where((r) => !r.delivered).length;
    if (pending == 0) return ToastHelper.info('كل الطلاب استلموا بالفعل');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسليم للكل'),
        content: Text('هيتسجّل تسليم الملزمة لـ $pending طالب لسه ما استلموش. '
            'الدفع مش هيتأثر.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تسليم')),
        ],
      ),
    );
    if (ok != true) return;
    final n = await c.deliverAll(bookletId);
    ToastHelper.success('اتسلّمت لـ $n طالب');
  }

  Future<void> _remind(BookletStudentRow r, Booklet b) async {
    final settings = Get.find<SettingsController>();
    final msg = buildBookletReminderMessage(
      studentName: r.student.name,
      bookletName: b.name,
      price: b.price,
      paid: r.paid,
      remaining: r.remaining,
      teacherName: settings.teacherFullName.value,
    );
    if (!mounted) return;
    await launchGuardianWhatsapp(
      context: context,
      phone: r.student.guardianPhone,
      whatsapp: r.student.guardianWhatsapp,
      message: msg,
      dialCode: settings.countryDial.value,
    );
  }

  /// قائمة اللي عليهم متبقي — إرسال تذكير لكل واحد بضغطة (بتتعلّم ✓ بعد الإرسال).
  Future<void> _remindAll(Booklet b) async {
    final owing = c
        .rowsFor(bookletId)
        .where((r) => r.remaining > 0)
        .toList();
    if (owing.isEmpty) return ToastHelper.info('مفيش حد عليه متبقي');
    final sent = <int>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                Text('تذكير ${owing.length} ولي أمر بمتبقي "${b.name}"',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in owing)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.student.name),
                          subtitle: Text('متبقي ${_money(r.remaining)}'),
                          trailing: sent.contains(r.student.id)
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.successColor)
                              : IconButton(
                                  icon: const Icon(Icons.send_rounded,
                                      color: Colors.green),
                                  onPressed: () async {
                                    await _remind(r, b);
                                    setSheet(() => sent.add(r.student.id!));
                                  },
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(Booklet b) async {
    final fmt = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('PDF'),
            onTap: () => Navigator.pop(ctx, ExportFormat.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_rounded),
            title: const Text('Excel'),
            onTap: () => Navigator.pop(ctx, ExportFormat.xlsx),
          ),
        ]),
      ),
    );
    if (fmt == null || !mounted) return;
    final rows = c.rowsFor(bookletId, historical: _historical);
    final header = [
      'الطالب',
      'الكود',
      'التسليم',
      if (_fin) ...['المدفوع', 'المتبقي', 'الحالة'],
    ];
    final data = [
      for (final r in rows)
        [
          r.student.name,
          r.student.code,
          r.delivered ? 'استلم' : 'لم يستلم',
          if (_fin) ...[
            _money(r.paid),
            _money(r.remaining),
            statusLabel(r.status),
          ],
        ],
    ];
    final sum = c.summaryFor(bookletId);
    final footer = [
      'استلم ${sum.delivered} من ${sum.eligible}',
      if (_fin) ...[
        'المحصَّل: ${_money(sum.collected)}',
        'المتبقي: ${_money(sum.remaining)}',
      ],
    ];
    ToastHelper.info('جاري التصدير…');
    final res = await ExportService().exportBookletSheet(
      bookletName: b.name,
      header: header,
      rows: data,
      footer: footer,
      format: fmt,
    );
    if (!mounted) return;
    if (res.success && res.path != null) {
      await Share.shareXFiles([XFile(res.path!)], subject: 'كشف ${b.name}');
    } else {
      ToastHelper.error(res.error ?? 'تعذّر التصدير');
    }
  }

  Future<void> _exclude(BookletStudentRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استثناء الطالب'),
        content: Text(
          'هيتشال "${r.student.name}" من الملزمة دي.'
          '${r.paid > 0 ? '\nدفعاته المسجّلة (${_money(r.paid)}) هتفضل محفوظة في السجل.' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استثناء')),
        ],
      ),
    );
    if (ok == true) await c.setExcluded(bookletId, r.student.id!, true);
  }

  Future<void> _showExcluded() async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final list = c.excludedStudents(bookletId);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const Text('الطلاب المستثنون',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('مفيش طلاب مستثنين'))),
              for (final s in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name),
                  trailing: TextButton(
                    onPressed: () => c.setExcluded(bookletId, s.id!, false),
                    child: const Text('إلغاء الاستثناء'),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  void _openPayments(BookletStudentRow r, Booklet b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentsSheet(
          bookletId: bookletId,
          student: r.student.id!,
          name: r.student.name,
          price: b.price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = c.booklets.firstWhereOrNull((x) => x.id == bookletId);
      if (b == null) {
        return Scaffold(
            appBar: AppBar(), body: const Center(child: Text('الملزمة اتحذفت')));
      }
      final all = c.rowsFor(bookletId,
          filter: BookletFilter(delivery: _delivery, pay: _pay),
          historical: _historical);
      final q = _q.trim().toLowerCase();
      final rows = q.isEmpty
          ? all
          : all
              .where((r) =>
                  r.student.name.toLowerCase().contains(q) ||
                  r.student.code.toLowerCase().contains(q))
              .toList();
      final sum = c.summaryFor(bookletId);
      return Scaffold(
        appBar: AppBar(
          title: Text(b.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'excluded') _showExcluded();
                if (v == 'all') _deliverAll();
                if (v == 'remindAll') _remindAll(b);
                if (v == 'export') _export(b);
                if (v == 'history') setState(() => _historical = !_historical);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'all', child: Text('تسليم للكل')),
                if (_fin)
                  const PopupMenuItem(
                      value: 'remindAll', child: Text('تذكير المتأخرين (واتساب)')),
                const PopupMenuItem(
                    value: 'export', child: Text('تصدير كشف الملزمة')),
                const PopupMenuItem(
                    value: 'excluded', child: Text('الطلاب المستثنون')),
                CheckedPopupMenuItem(
                    value: 'history',
                    checked: _historical,
                    child: const Text('السجل التاريخي')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _header(b, sum),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: CustomSearchBar(
                controller: _search,
                hintText: 'ابحث باسم الطالب أو الكود',
                onChanged: (v) => setState(() => _q = v),
                onClear: () => setState(() {
                  _q = '';
                  _search.clear();
                }),
              ),
            ),
            _filters(),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'مفيش طلاب مطابقين',
                      subtitle: 'غيّر البحث أو الفلاتر')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _row(rows[i], b),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _header(Booklet b, BookletSummary sum) {
    Widget stat(String label, Color color, {String? text, double? amount}) {
      final st = TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: color);
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: bookletCardDecoration(context),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat('استلموا', AppTheme.primaryColor,
            text: '${sum.delivered}/${sum.eligible}'),
        if (_fin) ...[
          stat('محصَّل', AppTheme.successColor, amount: sum.collected),
          stat('متبقي',
              sum.remaining > 0 ? AppTheme.errorColor : AppTheme.successColor,
              amount: sum.remaining),
        ],
      ]),
    );
  }

  Widget _filters() {
    Widget chip(String label, bool sel, VoidCallback on) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: sel,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(on),
          ),
        );
    final owing = _pay == PayFilter.owing;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('الكل', _delivery == DeliveryFilter.all && _pay == PayFilter.all,
              () {
            _delivery = DeliveryFilter.all;
            _pay = PayFilter.all;
          }),
          chip('لم يستلم', _delivery == DeliveryFilter.notDelivered, () {
            _delivery = _delivery == DeliveryFilter.notDelivered
                ? DeliveryFilter.all
                : DeliveryFilter.notDelivered;
          }),
          if (_fin)
            chip('عليه متبقي', owing,
                () => _pay = owing ? PayFilter.all : PayFilter.owing),
        ],
      ),
    );
  }

  Widget _row(BookletStudentRow r, Booklet b) {
    final inactive = r.student.isArchived || r.excluded;
    final needsPay = _fin && r.remaining > 0;
    final quickLabel = !r.delivered && needsPay
        ? 'استلم + دفع'
        : !r.delivered
            ? 'استلم'
            : needsPay
                ? 'دفع'
                : null;
    final Color subColor;
    String sub;
    if (!_fin) {
      sub = r.delivered ? 'استلم' : 'لم يستلم';
      subColor = r.delivered ? AppTheme.successColor : Colors.grey;
    } else if (r.status == BookletPaymentStatus.full) {
      sub = r.overpaid > 0 ? 'مدفوعة (زيادة ${_money(r.overpaid)})' : 'مدفوعة';
      subColor = AppTheme.successColor;
    } else {
      sub = 'متبقي ${_money(r.remaining)}';
      subColor = r.status == BookletPaymentStatus.partial
          ? AppTheme.warningColor
          : AppTheme.errorColor;
    }
    if (_fin && r.lastPaymentAt != null) {
      sub += ' • آخر دفعة ${FormatHelper.formatDate(r.lastPaymentAt!)}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: bookletCardDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 6, end: 2),
        leading: IconButton(
          tooltip: r.delivered ? 'إلغاء التسليم' : 'تسليم',
          icon: Icon(
            r.delivered
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: r.delivered ? AppTheme.successColor : Colors.grey,
            size: 28,
          ),
          onPressed: () => c.setDelivered(bookletId, r.student.id!, !r.delivered),
        ),
        title: Text(
          r.student.name +
              (r.student.isArchived
                  ? ' (مؤرشف)'
                  : r.excluded
                      ? ' (مستثنى)'
                      : ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: inactive ? Colors.grey : null),
        ),
        subtitle: Text(sub,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: subColor)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (quickLabel != null && !inactive)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => _quick(r),
              child: Text(quickLabel, style: const TextStyle(fontSize: 12)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
                if (v == 'pay') _openPayments(r, b);
              if (v == 'remind') _remind(r, b);
              if (v == 'exclude') _exclude(r);
            },
            itemBuilder: (_) => [
              if (_fin)
                const PopupMenuItem(value: 'pay', child: Text('الدفعات')),
              if (_fin && r.remaining > 0)
                const PopupMenuItem(
                    value: 'remind', child: Text('تذكير ولي الأمر (واتساب)')),
              if (!inactive)
                const PopupMenuItem(value: 'exclude', child: Text('استثناء')),
            ],
          ),
        ]),
      ),
    );
  }
}

class _PaymentsSheet extends StatefulWidget {
  final int bookletId;
  final int student;
  final String name;
  final double price;
  const _PaymentsSheet({
    required this.bookletId,
    required this.student,
    required this.name,
    required this.price,
  });

  @override
  State<_PaymentsSheet> createState() => _PaymentsSheetState();
}

class _PaymentsSheetState extends State<_PaymentsSheet> {
  final BookletController c = Get.find<BookletController>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _add() async {
    final v = parseAmount(_amount.text);
    if (v == null) return ToastHelper.error('اكتب مبلغ صحيح');
    final err = await c.addPayment(widget.bookletId, widget.student, v);
    if (err != null) {
      ToastHelper.error(err);
    } else {
      _amount.clear();
      ToastHelper.success('اتسجّلت الدفعة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = TeamModeService().canDeletePaymentsNow;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Obx(() {
          final list = c.paymentsOf(widget.bookletId, widget.student);
          final paid = bookletPaid(list);
          final remaining = bookletRemaining(widget.price, paid);
          final st = bookletPaymentStatus(widget.price, paid);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Row(children: [
                Expanded(
                  child: Text(widget.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                StatusPill(statusLabel(st), statusColor(st)),
              ]),
              const SizedBox(height: 12),
              LabeledProgress(
                label: 'مدفوع ${FormatHelper.formatCurrency(paid)}',
                trailing: 'متبقي ${FormatHelper.formatCurrency(remaining)}',
                value: widget.price <= 0 ? 1 : paid / widget.price,
                color: statusColor(st),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'مبلغ الدفعة',
                        prefixIcon: Icon(Icons.payments_rounded),
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('إضافة')),
              ]),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, children: [
                    ActionChip(
                      label: const Text('المتبقي بالكامل'),
                      onPressed: () => _amount.text = _n(remaining),
                    ),
                    if (remaining > 1)
                      ActionChip(
                        label: const Text('نصف المتبقي'),
                        onPressed: () => _amount.text = _n(remaining / 2),
                      ),
                  ]),
                ),
              const SizedBox(height: 8),
              const Divider(),
              if (list.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(8), child: Text('مفيش دفعات لسه')),
              for (final p in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline_rounded,
                      color: AppTheme.successColor),
                  title: Text(FormatHelper.formatCurrency(p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(FormatHelper.formatDate(p.date)),
                  trailing: canDelete
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => c.deletePayment(p.id!),
                        )
                      : null,
                ),
            ],
          );
        }),
      ),
    );
  }
}
