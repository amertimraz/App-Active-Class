// شاشات الإرسال الجماعي وكارت الحصة الجاية وبطاقة الـPDF.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/bulk_send_service.dart';
import 'package:active_class/services/student_card_pdf.dart';
import 'package:active_class/utils/next_session.dart';
import 'package:active_class/utils/send_queue.dart';
import 'package:active_class/views/messages/bulk_send_page.dart';
import 'package:active_class/views/messages/send_queue_page.dart';
import 'package:active_class/widgets/next_session_card.dart';

Student _s(int id, String name, {String? phone}) => Student(
    id: id, name: name, code: 'S$id', groupId: 1, price: 100, guardianPhone: phone);

Widget _host(Widget child, {bool dark = false, double scale = 1.0}) =>
    GetMaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: w!),
      ),
      home: child,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting('ar');
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  List<QueueItem> items() => [
        QueueItem.forStudent(_s(1, 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا',
            phone: '0100'),
            message: 'رسالة ١\nسطر تاني', subtitle: '150 ج.م'),
        QueueItem.forStudent(_s(2, 'بسمة'), message: 'رسالة ٢'), // من غير رقم
        QueueItem.forStudent(_s(3, 'يوسف', phone: '0102'), message: 'رسالة ٣'),
      ];

  group('شاشة الطابور', () {
    for (final dark in [false, true]) {
      testWidgets('بلا overflow ×1.6 dark=$dark على 320', (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            SendQueuePage(title: 'تذكير الدفع', items: items()),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('بيتحرك للتالية بعد الفتح ويتخطّى اللي من غير رقم',
        (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      await tester.pumpWidget(_host(SendQueuePage(
        title: 'تذكير الدفع',
        items: items(),
        opener: (it) async {
          opened.add(it.name);
          return true;
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('0 من 3'), findsNothing); // واحد اتخطّى من الأول
      expect(find.text('1 من 3'), findsOneWidget);
      expect(find.text('مفيش رقم'), findsOneWidget);
      await tester.tap(find.text('افتح واتساب وابعت'));
      await tester.pumpAndSettle();
      expect(opened.length, 1);
      // التالي هو يوسف (بسمة اتخطّت)
      expect(find.text('يوسف'), findsWidgets);
      expect(find.text('2 من 3'), findsOneWidget);
      await tester.tap(find.text('افتح واتساب وابعت'));
      await tester.pumpAndSettle();
      expect(find.text('خلّصت الطابور'), findsOneWidget);
      expect(find.text('3 من 3'), findsOneWidget);
    });

    testWidgets('الضغط على واحدة اتفتحت ما بيلغيش حالتها', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(SendQueuePage(
        title: 'x',
        items: items(),
        opener: (_) async => true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('افتح واتساب وابعت'));
      await tester.pumpAndSettle();
      expect(find.text('اتفتحت'), findsWidgets);
      await tester.tap(find.text('اتفتحت').last); // صف القايمة مش عدّاد السبورة
      await tester.pumpAndSettle();
      expect(find.text('اتفتحت قبل كده ✓'), findsOneWidget);
      expect(find.text('ابعت تاني'), findsOneWidget);
      expect(find.text('اتفتحت'), findsWidgets); // لسه معلّمة
    });

    testWidgets('تخطّي بيعدّي، وإعادة الإرسال للمتخطّين', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(SendQueuePage(
        title: 'x',
        items: items(),
        opener: (_) async => true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();
      expect(find.text('خلّصت الطابور'), findsOneWidget);
      await tester.tap(find.text('ابعت اللي اتخطّوا'));
      await tester.pumpAndSettle();
      expect(find.text('خلّصت الطابور'), findsNothing);
      expect(find.text('الدور على'), findsOneWidget);
    });
  });

  group('صفحة الإرسال الجماعي', () {
    BulkSendData data() {
      final today = DateTime.now();
      return BulkSendData(
        students: [
          _s(1, 'أحمد', phone: '0100'),
          _s(2, 'بسمة'),
          _s(3, 'يوسف', phone: '0102'),
        ],
        groups: [Group(id: 1, name: 'أولى ثانوي', code: 'G1', price: 100)],
        attendance: [
          Attendance(studentId: 1, date: today, status: ATTENDANCE_ABSENT),
          Attendance(studentId: 2, date: today, status: ATTENDANCE_ABSENT),
        ],
        payments: const [],
        homework: const [],
        exams: const {},
      );
    }

    testWidgets('بلا overflow ×1.6 في الوضعين', (tester) async {
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            BulkSendPage(
                initialKind: BulkKind.absence, initialData: data()),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('غياب اليوم: بيعرض الغايبين وبيعلّم اللي من غير رقم',
        (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(BulkSendPage(
          initialKind: BulkKind.absence, initialData: data())));
      await tester.pumpAndSettle();
      expect(find.text('2 طالب • 1 من غير رقم'), findsOneWidget);
      expect(find.text('ابدأ الإرسال (1)'), findsOneWidget);
      expect(find.textContaining('مفيش رقم لولي الأمر'), findsOneWidget);
      // إلغاء الكل يعطّل الزرار
      await tester.tap(find.text('إلغاء الكل'));
      await tester.pumpAndSettle();
      expect(find.text('ابدأ الإرسال (0)'), findsOneWidget);
      await tester.tap(find.text('اختيار الكل'));
      await tester.pumpAndSettle();
      expect(find.text('ابدأ الإرسال (1)'), findsOneWidget);
    });

    testWidgets('كارت الغياب بيتبدّل لتذكير الدفع (فاضي)', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(BulkSendPage(
          initialKind: BulkKind.absence, initialData: data())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تذكير الدفع'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مفيش حد عليه متبقي'), findsOneWidget);
    });
  });

  group('كارت الحصة الجاية', () {
    final g = Group(id: 1, name: 'العواسجة — تانية ثانوي علمي رياضة', code: 'G', price: 1);
    NextSessionInfo info({bool live = false}) => NextSessionInfo(
          group: g,
          start: DateTime(2026, 11, 7, 16),
          end: DateTime(2026, 11, 7, 18),
          isLive: live,
          studentCount: 18,
          overdueCount: 3,
        );

    for (final dark in [false, true]) {
      for (final live in [false, true]) {
        testWidgets('بلا overflow ×1.6 dark=$dark live=$live', (tester) async {
          tester.view.physicalSize = const Size(640, 1136);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              Scaffold(
                body: SingleChildScrollView(
                  child: NextSessionCard(
                    info: info(live: live),
                    canSeeFinancials: true,
                    onAttendance: () {},
                    onRemind: () {},
                    now: DateTime(2026, 11, 7, live ? 16 : 15, 20),
                  ),
                ),
              ),
              dark: dark,
              scale: 1.6));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('بيعرض المتأخرين وزرارين، وبيخفي الماليات بدون صلاحية',
        (tester) async {
      var attendance = 0, remind = 0;
      Widget card(bool fin) => _host(Scaffold(
            body: NextSessionCard(
              info: info(),
              canSeeFinancials: fin,
              onAttendance: () => attendance++,
              onRemind: () => remind++,
              now: DateTime(2026, 11, 7, 15, 20),
            ),
          ));
      await tester.pumpWidget(card(true));
      await tester.pumpAndSettle();
      expect(find.textContaining('بعد 40 دقيقة'), findsOneWidget);
      expect(find.textContaining('18 طالب'), findsOneWidget);
      expect(find.text('3 متأخر'), findsOneWidget);
      await tester.tap(find.byTooltip('ابدأ الحضور'));
      await tester.tap(find.text('3 متأخر'));
      expect(attendance, 1);
      expect(remind, 1);

      await tester.pumpWidget(card(false));
      await tester.pumpAndSettle();
      expect(find.text('3 متأخر'), findsNothing);
    });
  });

  group('بطاقة الطالب PDF', () {
    test('بتتبني بصيغة PDF سليمة', () async {
      final bytes = await StudentCardPdf.build(const StudentCardData(
        studentName: 'مصطفى عبد الرحمن',
        studentCode: 'S1',
        groupName: 'أولى ثانوي',
        monthLabel: 'نوفمبر 2026',
        present: 7,
        late: 1,
        absent: 1,
        hwDone: 5,
        hwTotal: 8,
        exams: [
          (name: 'امتحان الشهر', grade: '45 / 50'),
          (name: 'كويز', grade: 'غائب'),
        ],
        points: 180,
        levelLabel: 'فضي',
        commitment: 88,
        remainingText: '150 ج.م',
        teacherName: 'أ. سعد',
        teacherSpecialization: 'رياضيات',
      ));
      expect(bytes.length, greaterThan(2000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('من غير ماليات ولا امتحانات برضو بتتبني', () async {
      final bytes = await StudentCardPdf.build(const StudentCardData(
        studentName: 'بسمة',
        studentCode: 'S2',
        groupName: '-',
        monthLabel: 'نوفمبر 2026',
        present: 0,
        late: 0,
        absent: 0,
        hwDone: 0,
        hwTotal: 0,
        exams: [],
        points: 0,
        levelLabel: 'مبتدئ',
        commitment: null,
      ));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
