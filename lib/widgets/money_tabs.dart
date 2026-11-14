// lib/widgets/money_tabs.dart
//
// تابين صغيرين في كارت الفلوس في الرئيسية: «الدفعات» (حساب المستحق) و«الدخل»
// (الكاش الفعلي). جنب كل تاب علامة استفهام بتفتح شرح الفرق، بدل ما نكرّر
// الكروت. الحساب نفسه ما اتغيّرش — دي واجهة بس.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';

enum MoneyTab { payments, income }

class MoneyTabs extends StatelessWidget {
  final MoneyTab selected;
  final ValueChanged<MoneyTab> onSelect;
  const MoneyTabs({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.control + 4),
        border: Border.all(color: t.moneyLine),
      ),
      child: Row(children: [
        Expanded(
          child: _Tab(
            label: 'الدفعات',
            selected: selected == MoneyTab.payments,
            onTap: () => onSelect(MoneyTab.payments),
            onHelp: () => showMoneyHelp(context, MoneyTab.payments),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _Tab(
            label: 'الدخل',
            selected: selected == MoneyTab.income,
            onTap: () => onSelect(MoneyTab.income),
            onHelp: () => showMoneyHelp(context, MoneyTab.income),
          ),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHelp;
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.surface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(
            color: selected ? t.moneyInk.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: label,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Text(label,
                      maxLines: 1,
                      style: AppType.label.copyWith(
                          color: selected ? t.moneyInk : t.inkSoft,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400)),
                ),
              ),
            ),
          ),
        ),
        // علامة الاستفهام: صغيرة بصريًا، ومساحة اللمس 44×44.
        Tooltip(
          message: 'إيه الفرق؟',
          child: InkResponse(
            onTap: onHelp,
            radius: 22,
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.help_outline_rounded,
                  size: 18, color: selected ? t.moneyInk : t.inkFaint),
            ),
          ),
        ),
      ]),
    );
  }
}

/// شيت الشرح: إيه التاب ده بيجاوب عليه، والفرق عن التاني، مع مثال.
void showMoneyHelp(BuildContext context, MoneyTab tab) {
  final t = context.tokens;
  final isIncome = tab == MoneyTab.income;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.board)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(isIncome ? Icons.payments_rounded : Icons.fact_check_rounded,
                  color: t.positive),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                    isIncome ? 'الدخل = الكاش اللي دخل' : 'الدفعات = حساب المستحق',
                    style: AppType.title.copyWith(color: t.ink)),
              ),
            ]),
            const SizedBox(height: AppSpace.md),
            Text(
              isIncome
                  ? 'الفلوس اللي دخلت جيبك فعلًا في الشهر ده، بتاريخ الدفعة (اشتراكات + كراسات). من غير توزيع على الشهور ومن غير حساب المستحق.'
                  : 'بتوريك كام من مستحق الشهر اتسدّد. كل دفعة بتتوزّع على الشهور اللي عليها مستحق، الأقدم أولًا، فالرقم بيتغيّر لو اتدفع بعد كده عن شهر قديم.',
              style: AppType.body.copyWith(color: t.inkSoft, height: 1.7),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              isIncome
                  ? 'بيجاوب على: «قبضت كام الشهر ده؟»'
                  : 'بيجاوب على: «كام من مستحق الشهر ده اتسدّد، ومين لسه عليه؟»',
              style: AppType.label.copyWith(color: t.positive),
            ),
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: t.cautionSoft,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'مثال: طالب دفع 300 في نوفمبر عن اشتراك أكتوبر.\n'
                '• الدخل: بيتحسب في نوفمبر (الفلوس دخلت نوفمبر).\n'
                '• الدفعات: بتتحسب لأكتوبر (الشهر اللي اتسدّد).\n'
                'الرقمين مظبوطين، بس بيجاوبوا على سؤالين مختلفين.',
                style: AppType.caption.copyWith(color: t.caution, height: 1.7),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Get.toNamed(isIncome ? ROUTE_INCOME : ROUTE_REPORTS);
              },
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              icon: Icon(isIncome
                  ? Icons.payments_rounded
                  : Icons.bar_chart_rounded),
              label: Text(isIncome ? 'افتح دخلي' : 'افتح التقارير'),
            ),
          ],
        ),
      ),
    ),
  );
}
