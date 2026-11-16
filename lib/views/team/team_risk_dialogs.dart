// lib/views/team/team_risk_dialogs.dart
//
// تنبيهات تأكيد صريحة بالمخاطر لعمليات وضع الفريق الخطرة (المدرس/المالك):
//   • تعطيل وضع الفريق: بيمسح الفريق (نسخة السيرفر) نهائيًا ويشيل المساعدين.
//   • إعادة مزامنة كل البيانات: بتكتب نسخة الجهاز فوق السيرفر.
//   • تفعيل وضع الفريق: بينشئ فريق جديد وبيرفع كل حاجة من الأول.
// السبب: زرّ التعطيل كان بيتنفّذ فورًا بدون أي تأكيد، فمدرس قفله وفتحه وهو بيحاول
// يصلّح المزامنة فاتمسحت نسخة السيرفر كاملة (٣٨٧ طالب و٥٩٠٠ حضور) وعلق جهازه.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/chalk_dialog.dart';

/// كلمة التأكيد اللي لازم المدرس يكتبها قبل تعطيل وضع الفريق.
const String kDisableTeamConfirmWord = 'تعطيل';

/// هل نص التأكيد المكتوب مطابق؟ (بيتجاهل المسافات على الأطراف).
bool isDisableTeamConfirmed(String typed) =>
    typed.trim() == kDisableTeamConfirmWord;

/// تأكيد تعطيل وضع الفريق للمدرس. بيرجّع true لو أكّد، وبيعمل **نسخة احتياطية
/// تلقائية** قبل ما يكمّل (لو فشلت النسخة بيوقف العملية ويقول ليه).
Future<bool> confirmDisableTeamAsOwner(
    BuildContext context, TeamModeService team) async {
  final pending = await team.pendingOutboxCount() ?? 0;
  final unsynced = await team.unsyncedTotal();
  if (!context.mounted) return false;

  final ctrl = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (ctx, setSt) {
        final t = ctx.tokens;
        return ChalkDialog(
          icon: Icons.warning_amber_rounded,
          tone: ChalkTone.danger,
          title: 'تعطيل وضع الفريق؟',
          subtitle: 'عملية خطرة — اقرأ كويس قبل ما تكمّل',
          body: [
            ChalkRule(
              icon: Icons.delete_forever_rounded,
              color: t.danger,
              text: 'هيتمسح الفريق من السيرفر نهائيًا: كل نسخة السيرفر '
                  '(الطلاب والحضور والمدفوعات والامتحانات...) مش هترجع.',
            ),
            ChalkRule(
              icon: Icons.person_off_rounded,
              color: t.danger,
              text: 'المساعدين هيتشالوا فورًا ويفقدوا الوصول، وهتحتاج تعمل '
                  'لهم دعوة جديدة بعد كده.',
            ),
            ChalkRule(
              icon: Icons.phone_android_rounded,
              text: 'بياناتك على جهازك هتفضل زي ما هي.',
            ),
            ChalkRule(
              icon: Icons.cloud_upload_rounded,
              color: t.caution,
              text: 'لو فتحت وضع الفريق تاني هيتعمل فريق جديد وكل البيانات '
                  'هتترفع من الأول — ومع بيانات كتيرة ممكن ياخد وقت طويل.',
            ),
            ChalkRule(
              icon: Icons.group_rounded,
              color: t.caution,
              text: 'أي بيانات سجّلها مساعد ولسه ما نزلتش على جهازك هتضيع '
                  'للأبد.',
            ),
            if (pending > 0 || unsynced > 0)
              ChalkRule(
                icon: Icons.sync_problem_rounded,
                color: t.danger,
                text: 'عندك ${pending > 0 ? '$pending عملية' : '$unsynced صف'} '
                    'لسه ما اترفعتش للسيرفر — لو عطّلت دلوقتي هتضيع من '
                    'السيرفر.',
              ),
            ChalkRule(
              icon: Icons.save_alt_rounded,
              text: 'هنعمل نسخة احتياطية تلقائية على جهازك قبل التعطيل.',
            ),
            const SizedBox(height: AppSpace.md),
            Text('للتأكيد اكتب كلمة «$kDisableTeamConfirmWord»:',
                style: AppType.label.copyWith(color: t.ink)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: kDisableTeamConfirmWord,
                errorText: error,
                isDense: true,
              ),
              onChanged: (_) {
                if (error != null) setSt(() => error = null);
              },
            ),
          ],
          actions: [
            ChalkAction(
              label: 'تعطيل الفريق',
              icon: Icons.power_settings_new_rounded,
              kind: ChalkActionKind.dangerFilled,
              onPressed: () {
                if (!isDisableTeamConfirmed(ctrl.text)) {
                  setSt(() => error = 'اكتب «$kDisableTeamConfirmWord» بالظبط');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
            ),
            ChalkAction(
              label: 'إلغاء',
              kind: ChalkActionKind.text,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        );
      }),
    ),
  );
  ctrl.dispose();
  if (ok != true) return false;

  // نسخة احتياطية تلقائية قبل ما نمسح الفريق — لو فشلت منكمّلش.
  try {
    final r = await BackupService().createBackup();
    if (!r.success) {
      ToastHelper.error(
          'ماقدرناش نعمل نسخة احتياطية (${r.error ?? 'خطأ'}) — اتلغى التعطيل '
          'حمايةً لبياناتك. جرّب تاني أو اعمل نسخة يدوية الأول.');
      return false;
    }
    ToastHelper.info('اتعملت نسخة احتياطية: ${r.fileName ?? ''}');
  } catch (e) {
    ToastHelper.error('فشل إنشاء النسخة الاحتياطية — اتلغى التعطيل حمايةً '
        'لبياناتك.');
    return false;
  }
  return true;
}

/// تأكيد «إعادة مزامنة كل البيانات»: بتكتب نسخة الجهاز فوق السيرفر.
Future<bool> confirmResyncAll(BuildContext context) => showChalkConfirm(
      context,
      icon: Icons.sync_problem_rounded,
      tone: ChalkTone.caution,
      title: 'إعادة مزامنة كل البيانات؟',
      subtitle: 'استخدمها بس لو بتصلّح مشكلة',
      message: 'هتبعت نسخة جهازك لكل الصفوف وتكتب فوق نسخة السيرفر.\n\n'
          '• لو مساعد عدّل أو سجّل بيانات ولسه ما نزلتش على جهازك، تعديلاته '
          'ممكن تتكتب فوقها.\n'
          '• مع بيانات كتيرة ممكن تاخد وقت طويل وتستهلك نت.\n'
          '• لو المشكلة إن بعض الصفوف ناقصة، الأحسن «رفع الصفوف الناقصة فقط '
          '(آمن)».\n\n'
          'اعمل نسخة احتياطية الأول لو مش متأكد.',
      confirmLabel: 'أعيد المزامنة',
      confirmIcon: Icons.sync_rounded,
    );

/// تأكيد تفعيل وضع الفريق: بينشئ فريق جديد ويرفع كل البيانات.
Future<bool> confirmEnableTeam(BuildContext context) => showChalkConfirm(
      context,
      icon: Icons.groups_rounded,
      title: 'تفعيل وضع الفريق؟',
      message: 'هيتعمل فريق جديد وكل بياناتك هتترفع للسيرفر من الأول.\n\n'
          '• مع بيانات كتيرة ممكن ياخد من دقايق لساعة، وبيستهلك نت.\n'
          '• سيب التطبيق مفتوح وشغّال، ومتمسحش بياناته ولا تسجّل خروج لحد ما '
          'الرفع يخلص (هتشوف «الكل اترفع» في شاشة الفريق).\n'
          '• لو كنت مفعّل الفريق قبل كده وعطّلته، نسخة السيرفر القديمة '
          'اتمسحت وهتترفع بياناتك من جهازك.',
      confirmLabel: 'فعّل وضع الفريق',
      confirmIcon: Icons.check_rounded,
    );
