// lib/views/reports/session_breakdown_page.dart
//
// لست تفصيل الحصص لمجموعة "بالحصة" — كل تاريخ حضور في الشهر المختار
// وسطر لوحده، بعدد الحاضرين والمتوقع منها، بدل رقم شهري مجمّع بس.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';

class SessionBreakdownPage extends StatelessWidget {
  final Group group;
  const SessionBreakdownPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ReportController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('تفصيل حصص ${group.name}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() {
        final days = ctrl.sessionBreakdownForGroup(group.id!);
        final totalExpected =
            days.fold<double>(0, (s, d) => s + d.expectedAmount);

        if (days.isEmpty) {
          return Center(
            child: Text(
              'لسه مفيش حصص متسجّلة للمجموعة دي الشهر ده',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black45),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي المتوقع (${days.length} حصة)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    CurrencyText(
                      totalExpected,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = days[days.length - 1 - i]; // الأحدث فوق
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE، d MMMM', 'ar')
                                    .format(d.date),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 3),
                              Text('${d.presentCount} حاضر',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45)),
                            ],
                          ),
                        ),
                        CurrencyText(
                          d.expectedAmount,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.blue),
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
