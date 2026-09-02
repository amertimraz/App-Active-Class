// lib/config/constants.dart
const String APP_NAME = 'Active Class';
const String APP_VERSION = '1.0.0';

// Colors
const String PRIMARY_COLOR = '0xFF1976D2';
const String ACCENT_COLOR = '0xFFFFC107';
const String BACKGROUND_COLOR = '0xFFF5F5F5';
const String SURFACE_COLOR = '0xFFFFFFFF';
const String TEXT_PRIMARY = '0xFF212121';
const String TEXT_SECONDARY = '0xFF757575';
const String ERROR_COLOR = '0xFFD32F2F';
const String SUCCESS_COLOR = '0xFF388E3C';

// Font Sizes
const double FONT_SIZE_SMALL = 12.0;
const double FONT_SIZE_NORMAL = 14.0;
const double FONT_SIZE_MEDIUM = 16.0;
const double FONT_SIZE_LARGE = 18.0;
const double FONT_SIZE_XLARGE = 20.0;
const double FONT_SIZE_TITLE = 24.0;

// Padding & Margins
const double PADDING_SMALL = 12.0;
const double PADDING_NORMAL = 20.0;
const double PADDING_LARGE = 28.0;

// Spacing
const double SPACING_SMALL = 6.0;
const double SPACING_NORMAL = 12.0;
const double SPACING_MEDIUM = 16.0;
const double SPACING_LARGE = 20.0;
const double SPACING_XLARGE = 28.0;

// Border Radius
const double BORDER_RADIUS_SMALL = 8.0;
const double BORDER_RADIUS_NORMAL = 12.0;
const double BORDER_RADIUS_LARGE = 16.0;

// Database
const String DATABASE_NAME = 'active_class.db';
const int DATABASE_VERSION = 23;

// Table Names
const String TABLE_GROUPS = 'groups';
const String TABLE_STUDENTS = 'students';
const String TABLE_ATTENDANCE = 'attendance';
const String TABLE_PAYMENTS = 'payments';
const String TABLE_REPORT_LOGS  = 'report_logs';
const String TABLE_EXAMS        = 'exams';
const String TABLE_EXAM_GROUPS  = 'exam_groups';
const String TABLE_EXAM_GRADES  = 'exam_grades';
// spec 016 — امتحان إلكتروني: أسئلة الامتحان وتسليمات الطلاب (محلية فقط،
// خارج مزامنة الفريق في v1).
const String TABLE_EXAM_QUESTIONS   = 'exam_questions';
const String TABLE_EXAM_SUBMISSIONS = 'exam_submissions';
// إعدادات التطبيق (اسم المعلم، العملة، ...) كجدول key/value — عشان
// تتضمن تلقائيًا في أي نسخة احتياطية (اللي بتنسخ ملف قاعدة البيانات فقط).
const String TABLE_APP_SETTINGS = 'app_settings';
const String COL_SETTING_KEY   = 'key';
const String COL_SETTING_VALUE = 'value';

// Column Names - Exams
const String COL_EXAM_ID            = 'id';
const String COL_EXAM_NAME          = 'name';
const String COL_EXAM_DATE          = 'date';
const String COL_EXAM_MAX_GRADE     = 'max_grade';
const String COL_EXAM_PASSING_GRADE = 'passing_grade';
const String COL_EXAM_CREATED_AT    = 'created_at';
// spec 013 — الشهر اللي يُحسب له الامتحان في التقارير الشهرية (نص "YYYY-M").
// null → بديله شهر تاريخ الامتحان (توافق خلفي).
const String COL_EXAM_REPORT_MONTH  = 'report_month';
// spec 016 — أعمدة الامتحان الإلكتروني على جدول exams (null/0 للامتحان الورقي).
const String COL_EXAM_IS_ONLINE      = 'is_online';       // INTEGER 0/1
const String COL_EXAM_ONLINE_STATUS  = 'online_status';   // draft|published|stopped|removed
const String COL_EXAM_OPENS_AT       = 'opens_at';        // ISO-8601 UTC
const String COL_EXAM_CLOSES_AT      = 'closes_at';       // ISO-8601 UTC
const String COL_EXAM_DURATION_MIN   = 'duration_minutes';// INTEGER

// Column Names - Exam Questions (spec 016)
const String COL_EQ_ID            = 'id';
const String COL_EQ_EXAM_ID       = 'exam_id';
const String COL_EQ_POSITION      = 'position';
const String COL_EQ_TYPE          = 'type';          // true_false | mcq
const String COL_EQ_TEXT          = 'text';
const String COL_EQ_OPTIONS       = 'options';       // JSON list<String>
const String COL_EQ_CORRECT_INDEX = 'correct_index';
const String COL_EQ_POINTS        = 'points';
const String COL_EQ_CREATED_AT    = 'created_at';

// Column Names - Exam Submissions (spec 016)
const String COL_ES_ID             = 'id';
const String COL_ES_EXAM_ID        = 'exam_id';
const String COL_ES_STUDENT_ID     = 'student_id';
const String COL_ES_STARTED_AT     = 'started_at';
const String COL_ES_SUBMITTED_AT   = 'submitted_at';
const String COL_ES_ANSWERS_JSON   = 'answers_json';
const String COL_ES_AUTO_SCORE     = 'auto_score';
const String COL_ES_FINAL_GRADE    = 'final_grade';
const String COL_ES_STATUS         = 'status';       // pending | approved | not_submitted
const String COL_ES_AUTO_SUBMITTED = 'auto_submitted';
const String COL_ES_PULLED_AT      = 'pulled_at';

// Column Names - Exam Groups
const String COL_EG_ID       = 'id';
const String COL_EG_EXAM_ID  = 'exam_id';
const String COL_EG_GROUP_ID = 'group_id';

// Column Names - Exam Grades
const String COL_GRADE_ID         = 'id';
const String COL_GRADE_EXAM_ID    = 'exam_id';
const String COL_GRADE_STUDENT_ID = 'student_id';
const String COL_GRADE_VALUE      = 'grade';
const String COL_GRADE_NOTES      = 'notes';
const String COL_GRADE_IS_ABSENT  = 'is_absent';
const String COL_GRADE_CREATED_AT = 'created_at';

// Column Names - Groups
const String COL_GROUP_ID = 'id';
const String COL_GROUP_NAME = 'name';
const String COL_GROUP_CODE = 'code'; // optional unique code
const String COL_GROUP_PRICE = 'price'; // optional fee per group
const String COL_GROUP_COLOR = 'color'; // avatar color (int)
const String COL_GROUP_ICON = 'icon'; // icon name
const String COL_GROUP_SCHEDULE = 'schedule'; // optional text/json schedule
const String COL_GROUP_CREATED_AT = 'created_at';
const String COL_GROUP_PRICING_TYPE = 'pricing_type'; // monthly / per_session

// Column Names - Students
const String COL_STUDENT_ID = 'id';
const String COL_STUDENT_NAME = 'name';
const String COL_STUDENT_CODE = 'code';
const String COL_STUDENT_GROUP_ID = 'group_id';
const String COL_STUDENT_PRICE = 'price';
const String COL_STUDENT_QR_PATH = 'qr_path';
const String COL_STUDENT_SIBLING_ID = 'sibling_id'; // قديم — راجع specs/007-three-sibling-support
const String COL_STUDENT_SIBLINGS_TOTAL = 'siblings_total';
const String COL_STUDENT_SIBLING_GROUP_ID = 'sibling_group_id';
const String COL_STUDENT_CREATED_AT = 'created_at';
const String COL_STUDENT_ATTENDANCE_START = 'attendance_start';
const String COL_STUDENT_GUARDIAN_PHONE = 'guardian_phone';
const String COL_STUDENT_BIRTH_DATE = 'birth_date';
const String COL_STUDENT_EXEMPT_PERCENT = 'exempt_percent';
const String COL_STUDENT_EXEMPT_REASON  = 'exempt_reason';
const String COL_STUDENT_IS_ARCHIVED    = 'is_archived';
const String COL_STUDENT_ARCHIVED_AT    = 'archived_at';

// Exemption preset reasons
const List<String> EXEMPT_PRESET_REASONS = [
  'يتيم',
  'مكفول',
  'إعفاء مؤسسي',
  'ظروف اجتماعية',
  'أخ / أخت لطالب',
  'أخرى',
];

// Column Names - Attendance
const String COL_ATTENDANCE_ID = 'id';
const String COL_ATTENDANCE_STUDENT_ID = 'student_id';
const String COL_ATTENDANCE_DATE = 'date';
const String COL_ATTENDANCE_STATUS = 'status';
const String COL_ATTENDANCE_NOTES = 'notes';
const String COL_ATTENDANCE_CREATED_AT = 'created_at';

// Column Names - Homework (تسجيل حالة الواجب بس — النص نفسه بيفضل في
// الكشكول الورقي، هنا بس بنسجّل عمل/محضرش لكل طالب في كل تاريخ)
const String TABLE_HOMEWORK = 'homework';
const String COL_HOMEWORK_ID = 'id';
const String COL_HOMEWORK_STUDENT_ID = 'student_id';
const String COL_HOMEWORK_DATE = 'date';
const String COL_HOMEWORK_STATUS = 'status';
const String COL_HOMEWORK_CREATED_AT = 'created_at';
const String HOMEWORK_DONE = 'عمل';
const String HOMEWORK_NOT_DONE = 'لم يعمل';
// حالة تالتة: الواجب اتحلّ ناقص. (spec 010 — القيم القديمة عمل/لم يعمل
// تفضل صالحة في القاعدة وتُطبَّع عند العرض.)
const String HOMEWORK_PARTIAL = 'ناقص';

// Column Names - Payments
const String COL_PAYMENT_ID = 'id';
const String COL_PAYMENT_STUDENT_ID = 'student_id';
const String COL_PAYMENT_DATE = 'date';
const String COL_PAYMENT_AMOUNT = 'amount';
const String COL_PAYMENT_NOTE = 'note';
const String COL_PAYMENT_CREATED_AT = 'created_at';

// Column Names - Report Logs
const String COL_REPORT_ID = 'id';
const String COL_REPORT_STUDENT_ID = 'student_id';
const String COL_REPORT_MONTH_START = 'month_start';
const String COL_REPORT_SENT_AT = 'sent_at';

// Attendance Status
const String ATTENDANCE_PRESENT = 'حاضر';
const String ATTENDANCE_ABSENT = 'غائب';
// حالة تالتة: الطالب حضر بس بعد بداية الحصة. (spec 011 — تُحتسب حضورًا في
// النسبة والفوترة بالحصة، وتُعرض مميّزة. القيم القديمة حاضر/غائب تفضل صالحة.)
const String ATTENDANCE_LATE = 'متأخر';

// app_settings key — مهلة السماح (بالدقايق) بعد بداية الحصة قبل ما مسح الـQR
// يسجّل الطالب "متأخر" تلقائيًا. افتراضي 15. (spec 011)
const String SETTING_LATE_GRACE_MINUTES = 'late_grace_minutes';
// app_settings key — تفعيل/تعطيل حساب "متأخر" تلقائيًا عند مسح الـQR.
// افتراضيًا مفعّل؛ لو معطّل الـQR يسجّل "حاضر" دايمًا. (spec 011)
const String SETTING_QR_AUTO_LATE_ENABLED = 'qr_auto_late_enabled';

// app_settings keys — نظام تحصيل الاشتراك الشهري (spec 012).
// billing_arrears: false=مقدّم (الافتراضي، الشهر مستحق من أول يومه)،
//   true=مؤخّر (الشهر الجاري ما يتحسبش لحد ما يخلص).
// prorate_first_month: false=شهر كامل دايمًا (الافتراضي)،
//   true=شهر انضمام الطالب يُحسب نسبيًا بأيامه المشمولة.
const String SETTING_BILLING_ARREARS = 'billing_arrears';
const String SETTING_PRORATE_FIRST_MONTH = 'prorate_first_month';

// Route Names
const String ROUTE_SPLASH = '/splash';
const String ROUTE_HOME = '/';
const String ROUTE_GROUPS = '/groups';
const String ROUTE_STUDENTS = '/students';
const String ROUTE_ATTENDANCE = '/attendance';
const String ROUTE_PAYMENTS = '/payments';
const String ROUTE_QR_SCANNER_ATTENDANCE = '/qr_scanner_attendance';
const String ROUTE_QR_SCANNER_PAYMENT = '/qr_scanner_payment';
const String ROUTE_REPORTS = '/reports';
const String ROUTE_SETTINGS = '/settings';
const String ROUTE_NOTIFICATION_SETTINGS = '/notification_settings';
const String ROUTE_STUDENT_DETAILS = '/student_details';
const String ROUTE_GROUP_DETAILS = '/group_details';
const String ROUTE_ADD_STUDENT = '/add_student';
const String ROUTE_ARCHIVED_STUDENTS = '/archived_students';
const String ROUTE_QR_GALLERY = '/qr_gallery';
const String ROUTE_PAYMENTS_REPORT = '/payments_report';
const String ROUTE_ACTIVATION   = '/activation';
const String ROUTE_PLANS        = '/plans';
const String ROUTE_EXAMS               = '/exams';
const String ROUTE_EXAM_GRADES         = '/exam_grades';
const String ROUTE_LEADERBOARD         = '/leaderboard';
const String ROUTE_STUDENT_EXAM_HISTORY = '/student_exam_history';
const String ROUTE_SCHEDULE            = '/schedule';
const String ROUTE_BOOKINGS            = '/bookings';
const String ROUTE_BOOKING_SETTINGS    = '/booking_settings';
const String ROUTE_LOGIN               = '/login';
const String ROUTE_REGISTER            = '/register';
const String ROUTE_ACCOUNT             = '/account';
const String ROUTE_TEAM_MODE           = '/team_mode';
const String ROUTE_TEAM_JOIN           = '/team_join';
const String ROUTE_TEAM_MEMBERS        = '/team_members';

// Standalone login system (self-hosted Supabase) — app_settings keys
const String SETTING_HAS_LOGGED_IN_BEFORE = 'auth_has_logged_in_before';

// "وضع الفريق" — أعمدة المزامنة المضافة على groups/students/attendance/payments،
// وجدول الطابور المحلي (sync_outbox) اللي بيتفرّغ لسيرفر Supabase.
const String COL_SYNC_UPDATED_AT = 'updated_at';
const String COL_SYNC_REMOTE_ID = 'remote_id';

const String TABLE_SYNC_OUTBOX = 'sync_outbox';
const String COL_OUTBOX_ID = 'id';
const String COL_OUTBOX_TABLE = 'table_name';
const String COL_OUTBOX_ROW_ID = 'row_id';
const String COL_OUTBOX_OP = 'op'; // insert | update | delete
const String COL_OUTBOX_PAYLOAD = 'payload'; // JSON، null لو delete
const String COL_OUTBOX_CREATED_AT = 'created_at';
const String COL_OUTBOX_SYNCED = 'synced'; // 0/1

// app_settings key — حالة وضع الفريق (مفعّل/لأ) محفوظة محليًا عشان
// نعرف نستعيدها بصمت عند فتح التطبيق من غير ما نجبر أي حد يمر بيها.
const String SETTING_TEAM_MODE_ENABLED = 'team_mode_enabled';
const String SETTING_TEAM_ID = 'team_mode_team_id';
// دور الجهاز آخر مرة كان فيها وضع الفريق مفعّل (مالك/مساعد) — محفوظ
// عشان disable() يقدر يعرف يمسح بيانات المساعد المتزامنة محليًا حتى
// لو اتنادى قبل ما isOwner/teamId يتملّوا في الذاكرة للجلسة الحالية.
const String SETTING_TEAM_IS_OWNER = 'team_mode_is_owner';

// app_settings key — تفعيل/تعطيل إرسال تقرير واتساب تلقائي لأولياء
// الأمور بعد اكتمال تسجيل حضور المجموعة (افتراضيًا معطّل).
const String SETTING_REPORT_ON_COMPLETION_ENABLED =
    'attendance_report_on_completion_enabled';

// المدة الافتراضية للحصة (بالدقايق) لما جدول المجموعة يحدد ميعاد
// البداية بس من غير مدة صريحة — بتُستخدم لحساب وقت نهاية الحصة
// وبالتالي العداد التنازلي.
const int DEFAULT_SESSION_MINUTES = 60;
