// lib/views/reports/session_breakdown_page.dart
//
// لست تفصيل الحصص لمجموعة "بالحصة" — كل تاريخ حضور في الشهر المختار
// وسطر لوحده، بعدد الحاضرين والمتوقع منها، بدل رقم شهري مجمّع بس.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';

class SessionBreakdownPage extends StatelessWidget {
  final Group group;
  const SessionBreakdownPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ReportController>();
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'تفصيل حصص ${group.name}'),
      body: Obx(() {
        final days = ctrl.sessionBreakdownForGroup(group.id!);
        final totalExpected =
            days.fold<double>(0, (s, d) => s + d.expectedAmount);

        if (days.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text(
                'لسه مفيش حصص متسجّلة للمجموعة دي الشهر ده',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: t.inkSoft),
              ),
            ),
          );
        }

        return Column(
          children: [
            // سبورة: عدد الحصص وإجمالي المتوقع
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
              decoration: BoxDecoration(
                color: t.board,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.board)),
              ),
              child: Row(children: [
                Expanded(
                    child: BoardStat(
                        label: 'حصة',
                        value: '${days.length}',
                        color: t.boardInk)),
                Expanded(
                  flex: 2,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CurrencyText(
                        totalExpected,
                        style: AppType.figure.copyWith(color: t.chalk),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('إجمالي المتوقع',
                          style:
                              AppType.caption.copyWith(color: t.boardInkSoft)),
                    ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpace.lg),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = days[days.length - 1 - i]; // الأحدث فوق
                  return AppPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE، d MMMM', 'ar').format(d.date),
                                style: AppType.label.copyWith(color: t.ink),
                              ),
                              const SizedBox(height: 2),
                              Text('${d.presentCount} حاضر',
                                  style: AppType.caption
                                      .copyWith(color: t.inkSoft)),
                            ],
                          ),
                        ),
                        CurrencyText(
                          d.expectedAmount,
                          style: AppType.label.copyWith(color: t.ink),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}
