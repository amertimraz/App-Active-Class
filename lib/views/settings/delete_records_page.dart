// lib/views/settings/delete_records_page.dart
//
// شاشة "حذف سجلّات بمدى تواريخ" (spec 028) — منفصلة تمامًا عن زر
// "حذف كل البيانات". نسخة احتياطية إجبارية + معاينة + تأكيد.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/controllers/delete_records_controller.dart';
import 'package:active_class/models/deletable_record_type.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/progress_dialog.dart';

class DeleteRecordsPage extends StatelessWidget {
  const DeleteRecordsPage({super.key});

  static final _dateFmt = DateFormat('d MMM yyyy', 'ar');
  static const _warn = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);

  DeleteRecordsController get _c =>
      Get.isRegistered<DeleteRecordsController>()
          ? Get.find<DeleteRecordsController>()
          : Get.put(DeleteRecordsController());

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حذف سجلّات بمدى تواريخ',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _warningHeader(context),
          const SizedBox(height: 18),
          _sectionTitle('المدى الزمني'),
          const SizedBox(height: 8),
          Obx(() => Row(children: [
                Expanded(
                    child: _dateField(context, 'من',
                        c.fromDate.value, (d) => c.setFrom(d))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dateField(context, 'إلى',
                        c.toDate.value, (d) => c.setTo(d))),
              ])),
          Obx(() => (c.fromDate.value != null &&
                  c.toDate.value != null &&
                  !c.rangeValid)
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('تاريخ "من" لازم يكون قبل "إلى"',
                      style: TextStyle(color: _danger, fontSize: 12)),
                )
              : const SizedBox.shrink()),
          const SizedBox(height: 18),
          _sectionTitle('نوع السجلّات'),
          const SizedBox(height: 4),
          ...DeletableRecordType.values.map((t) => Obx(() {
                final allowed = c.isTypeAllowed(t);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  enabled: allowed,
                  title: Text(t.label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: allowed ? null : Colors.grey)),
                  subtitle: allowed
                      ? null
                      : const Text('مالكش صلاحية حذف النوع ده في الفريق',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: c.selectedTypes.contains(t),
                  onChanged: allowed ? (_) => c.toggleType(t) : null,
                );
              })),
          const SizedBox(height: 14),
          Obx(() => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: c.canPreview ? c.runPreview : null,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('معاينة'),
                ),
              )),
          const SizedBox(height: 14),
          Obx(() => _previewCard(c)),
          const SizedBox(height: 8),
          Obx(() {
            // ملاحظة: نقرأ previewTotal (observable) أول حاجة عشان الـObx
            // يفضل يسمع للتغيير حتى لو وضع الفريق مقفول (لو بدأنا بـ
            // teamModeEnabled && ... الـ&& بيقصّر ومايقراش أي observable →
            // GetX يرمي ObxError = مربّع رمادي في الريليس).
            final total = c.previewTotal;
            return (total > 500 && DatabaseService.teamModeEnabled)
                ? _teamNote()
                : const SizedBox.shrink();
          }),
          const SizedBox(height: 18),
          Obx(() => SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _danger.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                  ),
                  onPressed:
                      c.canDelete ? () => _confirmAndDelete(context, c) : null,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('حذف نهائيًا',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              )),
          Obx(() => (c.preview.value == null || c.previewTotal == 0)
              ? const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('اختر المدى والنوع ثم «معاينة» عشان يتفعّل الزر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey)))
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ── مكوّنات ──────────────────────────────────────────────────────
  Widget _warningHeader(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _danger.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'الحذف نهائي — لا يمكن التراجع إلا باستعادة نسخة احتياطية كاملة. '
              'تُنشأ نسخة احتياطية تلقائيًا قبل أي حذف.',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 12, color: _danger),
            ),
          ),
        ]),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14));

  Widget _dateField(BuildContext context, String label, DateTime? value,
          void Function(DateTime) onPick) =>
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(2018),
            lastDate: now,
          );
          if (picked != null) onPick(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? '$label — اختر' : _dateFmt.format(value),
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      );

  Widget _previewCard(DeleteRecordsController c) {
    final p = c.preview.value;
    if (p == null) return const SizedBox.shrink();
    if (c.previewTotal == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('لا سجلّات مطابقة للمدى والأنواع المختارة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warn.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سيُحذف:',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...p.entries.where((e) => c.selectedTypes.contains(e.key)).map((e) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${e.key.label}: ${e.value}',
                    style: const TextStyle(fontSize: 12.5)),
              )),
          const Divider(height: 14),
          Text('الإجمالي: ${c.previewTotal} سجل',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: _warn)),
        ],
      ),
    );
  }

  Widget _teamNote() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'وضع الفريق مفعّل — الحذف هيتزامن مع بقية أجهزة الفريق وقد ياخد وقت في المزامنة.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF0EA5E9)),
        ),
      );

  // ── تأكيد + تنفيذ ────────────────────────────────────────────────
  Future<void> _confirmAndDelete(
      BuildContext context, DeleteRecordsController c) async {
    final needsWord = c.needsTypeConfirm;
    final wordCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final enabled = !needsWord ||
              wordCtrl.text.trim() == kDeleteConfirmWord;
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('تأكيد الحذف'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم حذف ${c.previewTotal} سجل نهائيًا '
                  '(${DeleteRecordsPage._dateFmt.format(c.fromDate.value!)} '
                  '— ${DeleteRecordsPage._dateFmt.format(c.toDate.value!)}). '
                  'تُنشأ نسخة احتياطية أولًا.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (needsWord) ...[
                  const SizedBox(height: 12),
                  const Text('اكتب «حذف» للتأكيد:',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: wordCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                    onChanged: (_) => setDlg(() {}),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _danger, foregroundColor: Colors.white),
                onPressed: enabled ? () => Navigator.pop(ctx, true) : null,
                child: const Text('حذف'),
              ),
            ],
          );
        },
      ),
    );
    wordCtrl.dispose();
    if (ok != true || !context.mounted) return;

    final outcome = await ProgressDialog.run<DeleteOutcome>(
      context,
      title: 'جارٍ الحذف...',
      color: _danger,
      task: c.runDelete,
    );

    if (!context.mounted) return;
    switch (outcome) {
      case DeleteSuccess(:final deleted, :final total):
        final parts = deleted.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key.label}: ${e.value}')
            .join('، ');
        ToastHelper.success('اتحذف $total سجل ($parts)');
      case DeleteBackupFailed(:final reason):
        ToastHelper.error(
            'اتلغى الحذف: فشل إنشاء نسخة احتياطية${reason != null ? " — $reason" : ""}');
      case DeleteError():
        ToastHelper.error('حصل خطأ أثناء الحذف — لم يُحذف شيء');
    }
  }
}
