// test/tour_layer_test.dart — طبقة «جرّبها بنفسك»: بتنوّر على العنصر، والضغط
// عليه بيوصل للزرار الحقيقي وبيكمّل الجولة، وبره الفتحة مقفول.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/tour/tour.dart';

Widget _app(VoidCallback onStudents, VoidCallback onOther) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (c, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(children: [
          child!,
          const Positioned.fill(child: TourLayer()),
        ]),
      ),
      home: Scaffold(
        body: Column(children: [
          const SizedBox(height: 120),
          TourTarget(
            id: 'home.students',
            child: ElevatedButton(
                onPressed: onStudents, child: const Text('الطلاب')),
          ),
          const SizedBox(height: 300),
          ElevatedButton(onPressed: onOther, child: const Text('تاني')),
        ]),
      ),
    );

void main() {
  tearDown(() => TourController.instance.stop());

  testWidgets('الجولة بتنوّر والضغط على العنصر بيكمّل للخطوة اللي بعدها',
      (tester) async {
    var students = 0, other = 0;
    await tester.pumpWidget(_app(() => students++, () => other++));
    TourController.instance.start('add_student');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('الطلاب'), findsWidgets);
    expect(find.textContaining('1 من'), findsOneWidget);

    // خارج الفتحة: الضغط ما يوصلش للزرار التاني
    await tester.tap(find.text('تاني'), warnIfMissed: false);
    await tester.pump();
    expect(other, 0);

    // جوّه الفتحة: يوصل للزرار الحقيقي وتتقدّم الخطوة
    await tester.tap(find.widgetWithText(ElevatedButton, 'الطلاب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(students, 1);
    expect(TourController.instance.index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إنهاء الجولة بيشيل الطبقة والشاشة بترجع تشتغل', (tester) async {
    var other = 0;
    await tester.pumpWidget(_app(() {}, () => other++));
    TourController.instance.start('add_student');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('إنهاء الجولة'));
    await tester.pump();
    expect(TourController.instance.active, isFalse);
    await tester.tap(find.text('تاني'));
    expect(other, 1);
  });
}
