// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/session_log_controller.dart';
import 'package:active_class/views/home_page.dart';
import 'package:active_class/views/groups/groups_page.dart';
import 'package:active_class/views/groups/group_details_page.dart';
import 'package:active_class/views/students/students_page.dart';
import 'package:active_class/views/students/student_details_page.dart';
import 'package:active_class/views/attendance/attendance_page.dart';
import 'package:active_class/views/payments/payments_page.dart';
import 'package:active_class/views/qr_scanner/qr_scanner_attendance_page.dart';
import 'package:active_class/views/qr_scanner/qr_scanner_payment_page.dart';
import 'package:active_class/views/qr_scanner/qr_gallery_page.dart';
import 'package:active_class/views/reports/reports_page.dart';
import 'package:active_class/views/settings/settings_page.dart';
import 'package:active_class/views/settings/notification_settings_page.dart';
import 'package:active_class/views/reports/payments_report_page.dart';
import 'package:active_class/views/qr_scanner/code39_scanner_payment_page.dart';
import 'package:active_class/views/splash_page.dart';
import 'package:active_class/views/license/activation_page.dart';
import 'package:active_class/views/license/plans_page.dart';
import 'package:active_class/views/exams/exams_page.dart';
import 'package:active_class/views/exams/student_exam_history_page.dart';
import 'package:active_class/views/schedule/schedule_page.dart';
import 'package:active_class/controllers/exam_controller.dart';

import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/auto_backup_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:active_class/firebase_options.dart';
import 'package:active_class/controllers/license_controller.dart';

// تشغيل المهام الخلفية
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// مفاتيح ثابتة لمهام الخلفية وتخزين الحالة
const String kMonthlyCheckTask = 'monthly_whatsapp_check_task';
const String kShouldSendWhatsappReports = 'should_send_whatsapp_reports';

// دالة الاستدعاء الخاصة بالمهام الخلفية (يجب أن تكون مستوى أعلى)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1)).day;
    if (now.day == lastDay) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kShouldSendWhatsappReports, true);
    }
    return Future.value(true);
  });
}

// مراقب دورة حياة التطبيق لتفعيل الإرسال تلقائياً عند العودة للتطبيق
class _LifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _tryTriggerAutoSendIfNeeded();
    }
  }
}

final _LifecycleObserver _lifecycleObserver = _LifecycleObserver();
bool _postFrameScheduled = false;

Future<void> _tryTriggerAutoSendIfNeeded() async {
  // قراءة العلامة من SharedPreferences وإن كانت موجودة شغّل الإرسال ثم امسحها
  final prefs = await SharedPreferences.getInstance();
  final shouldSend = prefs.getBool(kShouldSendWhatsappReports) ?? false;
  if (shouldSend) {
    await prefs.setBool(kShouldSendWhatsappReports, false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = Get.context;
      if (ctx != null) {
        await sendMonthlyReportsViaWhatsAppAuto(ctx);
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ar';
  try {
    await Future.wait([
      initializeDateFormatting('ar'),
      initializeDateFormatting('ar_SA'),
    ]);
  } catch (_) {
    await initializeDateFormatting('ar');
  }

  // تهيئة نظام الإشعارات
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  // تهيئة الحفظ التلقائي
  await AutoBackupService().init();

  // تهيئة Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // تسجيل المتحكمات
  Get.put(LicenseController(), permanent: true);
  Get.put(ThemeController());
  Get.put(SettingsController());
  Get.put(SessionLogController(), permanent: true);
  Get.put(ExamController(), permanent: true);

  // تهيئة Workmanager فقط على الأنظمة المدعومة (ليس الويب)
  if (!kIsWeb) {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      kMonthlyCheckTask,
      kMonthlyCheckTask,
      frequency: const Duration(days: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
          networkType: NetworkType.connected), // يحتاج اتصال للواتساب
      initialDelay: const Duration(hours: 6), // توزيع الحمل
    );

    // إضافة مراقب دورة الحياة
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    // فحص العلامة بعد أول إطار للتطبيق بدون تكرار
    if (!_postFrameScheduled) {
      _postFrameScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _tryTriggerAutoSendIfNeeded();
      });
    }

    return Obx(() => GetMaterialApp(
          title: APP_NAME,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode.value,
          locale: const Locale('ar'),
          builder: (context, child) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashPage(),
          getPages: [
            GetPage(name: ROUTE_SPLASH, page: () => const SplashPage()),
            GetPage(name: ROUTE_HOME, page: () => const HomePage()),
            GetPage(name: ROUTE_GROUPS, page: () => const GroupsPage()),
            GetPage(name: ROUTE_STUDENTS, page: () => const StudentsPage()),
            GetPage(
                name: ROUTE_GROUP_DETAILS,
                page: () => const GroupDetailsPage()),
            GetPage(
                name: ROUTE_STUDENT_DETAILS,
                page: () => const StudentDetailsPage()),
            GetPage(name: ROUTE_ATTENDANCE, page: () => const AttendancePage()),
            GetPage(name: ROUTE_PAYMENTS, page: () => const PaymentsPage()),
            GetPage(
                name: ROUTE_QR_SCANNER_ATTENDANCE,
                page: () => const QRScannerAttendancePage()),
            GetPage(
                name: ROUTE_QR_SCANNER_PAYMENT,
                page: () => const QRScannerPaymentPage()),
            GetPage(name: ROUTE_QR_GALLERY, page: () => const QrGalleryPage()),
            GetPage(name: ROUTE_REPORTS, page: () => const ReportsPage()),
            GetPage(name: ROUTE_SETTINGS, page: () => const SettingsPage()),
            GetPage(
                name: ROUTE_NOTIFICATION_SETTINGS,
                page: () => const NotificationSettingsPage()),
            GetPage(
                name: ROUTE_PAYMENTS_REPORT,
                page: () => const PaymentsReportPage()),
            GetPage(
                name: ROUTE_CODE39_SCANNER_PAYMENT,
                page: () => const Code39ScannerPaymentPage()),
            GetPage(name: ROUTE_ACTIVATION, page: () => const ActivationPage()),
            GetPage(name: ROUTE_PLANS,     page: () => const PlansPage()),
            GetPage(name: ROUTE_EXAMS,     page: () => const ExamsPage()),
            GetPage(name: ROUTE_SCHEDULE,  page: () => const SchedulePage()),
            GetPage(
              name: ROUTE_STUDENT_EXAM_HISTORY,
              page: () {
                final args = Get.arguments as Map<String, dynamic>;
                return StudentExamHistoryPage(
                  studentId:   args['studentId'] as int,
                  studentName: args['studentName'] as String,
                );
              },
            ),
          ],
        ));
  }
}
