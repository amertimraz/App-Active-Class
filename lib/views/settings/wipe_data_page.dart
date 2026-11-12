// lib/views/settings/wipe_data_page.dart
//
// «حذف جميع البيانات» بشكل مرن: المدرس يختار الأقسام اللي عايز يحذفها (أو
// الكل)، يشوف عدد اللي هيتحذف، وبعدين تأكيد بكلمة + نسخة احتياطية إجبارية.
// الأقسام اللي بتعتمد على بعض (الطلاب ← حضورهم ودفعاتهم) بتتحدد لوحدها.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/wipe_data_controller.dart';
import 'package:active_class/models/wipe_scope.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/progress_dialog.dart';

class WipeDataPage extends StatelessWidget {
  const WipeDataPage({super.key});

  WipeDataController get _c => Get.isRegistered<WipeDataController>()
      ? Get.find<WipeDataController>()
      : Get.put(WipeDataController());

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'حذف جميع البيانات'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
            AppSpace.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          _warning(t),
          const SizedBox(height: AppSpace.lg),
          Obx(() => _summary(t, c)),
          const SizedBox(height: AppSpace.lg),
          for (final (title, scopes) in kWipeGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpace.sm),
              child: Text(title, style: AppType.label.copyWith(color: t.ink)),
            ),
            Material(
              color: t.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.panel),
                side: BorderSide(color: t.line),
              ),
              child: Column(children: [
                for (var i = 0; i < scopes.length; i++) ...[
                  Obx(() => _row(context, t, c, scopes[i])),
                  if (i < scopes.length - 1)
                    Divider(height: 1, thickness: 1, color: t.line),
                ],
              ]),
            ),
            const SizedBox(height: AppSpace.lg),
          ],
          Obx(() => _deleteButton(context, t, c)),
          const SizedBox(height: AppSpace.sm),
          Text(
            'الإعدادات والترخيص وحساب الدخول ما بيتمسحوش. تقدر ترجّع كل حاجة من النسخة الاحتياطية اللي بتتعمل قبل الحذف.',
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(color: t.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _warning(AppTokens t) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: t.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(color: t.danger.withValues(alpha: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, color: t.danger),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'الحذف نهائي. اختار الأقسام اللي عايز تحذفها بس، أو «اختيار الكل» لو عايز تبدأ من الصفر. بتتعمل نسخة احتياطية تلقائيًا قبل أي حذف.',
              style: AppType.body.copyWith(color: t.danger),
            ),
          ),
        ]),
      );

  /// سبورة الملخص: عدد الأقسام والإجمالي + أزرار الاختيار.
  Widget _summary(AppTokens t, WipeDataController c) {
    final n = c.effective.length;
    final counting = c.isCounting.value;
    final total = c.total;
    return Material(
      color: t.board,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.board),
        side: BorderSide(color: t.boardLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.chalk,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(Icons.delete_sweep_rounded,
                    color: t.onChalk, size: 24),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n == 0 ? 'لسه ما اخترتش حاجة' : 'هتتحذف $n أقسام',
                      style: AppType.title.copyWith(color: t.boardInk),
                    ),
                    Text(
                      n == 0
                          ? 'علّم على الأقسام اللي تحت'
                          : counting
                              ? 'بنحسب…'
                              : 'إجمالي $total سجل',
                      style:
                          AppType.caption.copyWith(color: t.boardInkSoft),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.md),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: c.selectAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.boardInk,
                    side: BorderSide(color: t.boardInkSoft),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.select_all_rounded, size: 18),
                  label: const Text('اختيار الكل'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: c.hasSelection ? c.clear : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.boardInk,
                    disabledForegroundColor:
                        t.boardInkSoft.withValues(alpha: 0.5),
                    side: BorderSide(color: t.boardInkSoft),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.deselect_rounded, size: 18),
                  label: const Text('مسح الاختيار'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context, AppTokens t, WipeDataController c, WipeScope s) {
    final direct = c.selected.contains(s);
    final implied = c.isImplied(s);
    final on = direct || implied;
    final count = c.preview.value?[s];
    return Semantics(
      button: true,
      checked: on,
      label: s.label,
      child: InkWell(
        onTap: implied
            ? () => ToastHelper.info(
                'القسم ده بيتحذف تلقائيًا مع قسم تاني مختار — شيل القسم التاني الأول')
            : () => c.toggle(s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.sm + 2),
            child: Row(children: [
              Icon(
                on
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: on ? (implied ? t.inkFaint : t.danger) : t.inkFaint,
                size: 26,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label,
                        style: AppType.label.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text(
                      implied ? 'بيتحذف تلقائيًا مع القسم التابع له' : s.hint,
                      style: AppType.caption.copyWith(
                          color: implied ? t.caution : t.inkFaint),
                    ),
                  ],
                ),
              ),
              if (on && count != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text('$count',
                      style: AppType.label.copyWith(color: t.danger)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(
      BuildContext context, AppTokens t, WipeDataController c) {
    final canDelete = c.canDelete;
    return Column(children: [
      if (!c.allowed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Text('الحذف ده متاح للمدرس (صاحب الفريق) بس',
              style: AppType.caption.copyWith(color: t.danger)),
        ),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: t.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: t.danger.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          onPressed: canDelete ? () => _confirmAndWipe(context, c) : null,
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('حذف المحدد نهائيًا'),
        ),
      ),
    ]);
  }

  Future<void> _confirmAndWipe(
      BuildContext context, WipeDataController c) async {
    final t = context.tokens;
    final wordCtrl = TextEditingController();
    final eff = kWipeOrder.where(c.effective.contains).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final enabled = wordCtrl.text.trim() == kWipeConfirmWord;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تأكيد الحذف النهائي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('هتتحذف الأقسام دي نهائيًا:',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  for (final s in eff)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                          '• ${s.label}: ${c.preview.value?[s] ?? 0}',
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                  const Divider(height: 18),
                  Text('الإجمالي: ${c.total} سجل',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: t.danger)),
                  const SizedBox(height: 8),
                  const Text('بتتعمل نسخة احتياطية قبل الحذف.',
                      style: TextStyle(fontSize: 12)),
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
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: t.danger, foregroundColor: Colors.white),
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

    final outcome = await ProgressDialog.run<WipeOutcome>(
      context,
      title: 'جارٍ الحذف...',
      icon: Icons.delete_forever_rounded,
      color: t.danger,
      task: c.run,
    );

    if (!context.mounted) return;
    switch (outcome) {
      case WipeSuccess(:final deleted, :final total):
        final parts = deleted.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key.label}: ${e.value}')
            .join('، ');
        ToastHelper.success(
            parts.isEmpty ? 'مكانش فيه حاجة تتحذف' : 'اتحذف $total سجل ($parts)');
      case WipeBackupFailed(:final reason):
        ToastHelper.error(
            'اتلغى الحذف: فشل إنشاء نسخة احتياطية${reason != null ? " — $reason" : ""}');
      case WipeError():
        ToastHelper.error('حصل خطأ أثناء الحذف — لم يُحذف شيء');
    }
  }
}
