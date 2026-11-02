// lib/help/help_coverage.dart
//
// خريطة تغطية المساعدة للشاشات — بيستخدمها اختبار test/help_sync_test.dart
// عشان يمنع إن شاشة جديدة تتضاف من غير ما حد يقرر مين يشرحها.
//
// لما تضيف مسار جديد (ROUTE_*) في constants.dart لازم تحطه في واحدة من التلاتة:
//   1) kHelpTopicForRoute  — الشاشة ليها موضوع شرح (أو جزء من موضوع).
//   2) kHelpIgnoredRoutes  — شاشة نظام مش محتاجة شرح (دخول، شاشة بداية...).
//   3) kHelpKnownGaps      — ميزة حقيقية لسه من غير شرح (دين معلن، اتعمل له موضوع قريب).
import 'package:active_class/config/constants.dart';

/// مسار الشاشة → معرّف موضوع المساعدة اللي بيغطيها.
const kHelpTopicForRoute = <String, String>{
  ROUTE_GROUPS: 'groups',
  ROUTE_GROUP_DETAILS: 'groups',
  ROUTE_STUDENTS: 'students',
  ROUTE_ADD_STUDENT: 'students',
  ROUTE_ARCHIVED_STUDENTS: 'students',
  ROUTE_STUDENT_DETAILS: 'student_page',
  ROUTE_SIBLINGS: 'exemption_siblings',
  ROUTE_ATTENDANCE: 'attendance',
  ROUTE_QR_SCANNER_ATTENDANCE: 'attendance',
  ROUTE_RECITATION: 'recitation',
  ROUTE_PAYMENTS: 'payments',
  ROUTE_QR_SCANNER_PAYMENT: 'payments',
  ROUTE_PAYMENTS_REPORT: 'remind_debtors',
  ROUTE_QR_GALLERY: 'qr',
  ROUTE_REPORTS: 'reports',
  ROUTE_PARENT_PORTAL: 'portal',
  ROUTE_PARENT_PORTAL_STUDENTS: 'portal',
  ROUTE_AT_RISK_STUDENTS: 'at_risk',
  ROUTE_EXAMS: 'exams',
  ROUTE_EXAM_GRADES: 'exams',
  ROUTE_LEADERBOARD: 'exams',
  ROUTE_TEAM_MODE: 'team',
  ROUTE_TEAM_JOIN: 'team',
  ROUTE_TEAM_MEMBERS: 'team',
  ROUTE_SETTINGS: 'backup',
  ROUTE_NOTIFICATION_SETTINGS: 'at_risk',
  ROUTE_HELP: 'start',
  ROUTE_HELP_TOPIC: 'start',
};

/// شاشات نظام مش محتاجة موضوع شرح.
const kHelpIgnoredRoutes = <String>{
  ROUTE_SPLASH,
  ROUTE_HOME,
  ROUTE_LOGIN,
  ROUTE_REGISTER,
  ROUTE_ACTIVATION,
  ROUTE_ACCOUNT,
  ROUTE_PLANS,
};

/// ميزات حقيقية لسه من غير موضوع مساعدة (دين معلن — شيل المسار من هنا لما
/// تكتب له موضوع وتحطه في kHelpTopicForRoute).
const kHelpKnownGaps = <String>{
  ROUTE_SCHEDULE, // جدول الحصص
  ROUTE_BOOKINGS, // الحجوزات
  ROUTE_BOOKING_SETTINGS,
  ROUTE_BOOKLETS, // الملازم
  ROUTE_BOOKLET_DETAILS,
  ROUTE_QUESTION_BANK, // بنك الأسئلة
  ROUTE_STUDENT_EXAM_HISTORY,
};

/// كلمات عريضة في الشرح مش بالضرورة نص حرفي في الواجهة (وصف مش اسم زر).
/// أي إضافة هنا لازم تكون مقصودة. الاختبار بيرفض أي كلمة عريضة مش موجودة في
/// الكود ومش هنا.
const kHelpDescriptiveBold = <String>{};
