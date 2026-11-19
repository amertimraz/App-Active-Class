// lib/utils/whats_new.dart
//
// «الجديد في هذا التحديث»: ملاحظات كل إصدار (بالعربي المختصر) + منطق صرف بيحدّد
// إيه اللي يتعرض للمدرس بعد التحديث. بلا Flutter ولا SharedPreferences.
//
// لإضافة إصدار جديد: ضيف ReleaseNote في أول kReleaseNotes بنفس رقم version في
// pubspec.yaml (من غير +build). النافذة بتظهر مرة واحدة بعد ما التطبيق يتحدّث.

/// ميزة واحدة: عنوان قصير + سطر شرح. [icon] مفتاح نصّي بتترجمه النافذة لأيقونة
/// (علشان الملف ده يفضل من غير Flutter): chat, reports, income, exam, delete,
/// settings، وأي مفتاح تاني بياخد أيقونة عامة.
class ReleaseItem {
  final String title;
  final String body;
  final String icon;
  const ReleaseItem(this.title, this.body, {this.icon = 'star'});
}

class ReleaseNote {
  /// «major.minor.patch» (من غير رقم البناء).
  final String version;
  final List<ReleaseItem> items;
  const ReleaseNote(this.version, this.items);
}

/// الأحدث أولًا.
const List<ReleaseNote> kReleaseNotes = [
  ReleaseNote('1.2.92', [
    ReleaseItem(
      'رسايل الغياب بمهلة',
      'الغياب التلقائي بيستنى ساعة قبل ما يبعت لولي الأمر، وتحضير الكل بيلغي الرسالة المعلّقة.',
      icon: 'chat',
    ),
    ReleaseItem(
      'السناتر للمدرس بس',
      'المساعد بيشوف السناتر لكن ما بينظّمها، والسنتر بيوصله صح بعد التقييد.',
      icon: 'settings',
    ),
    ReleaseItem(
      'إرسال التقارير ما بيعلّقش',
      'الإرسال الجماعي بيكمّل لو رقم ولي أمر غير صالح، وبيعرض ملخّص بالنتيجة.',
      icon: 'reports',
    ),
  ]),
  ReleaseNote('1.2.91', [
    ReleaseItem(
      'مساعد يشوف سنتر معيّن',
      'حدّد لكل مساعد سناتر أو مجموعات يشوفها بس، وبياناتهم بس هي اللي بتنزل عليه.',
      icon: 'settings',
    ),
  ]),
  ReleaseNote('1.2.90', [
    ReleaseItem(
      'درجة صفر حقيقية',
      'تقدر تسجّل صفر لطالب سمّع غلط، وبيتحسب في المتوسط والتقارير.',
      icon: 'star',
    ),
    ReleaseItem(
      'التسميع في بوابة الأهل',
      'يوم «حضر وما سمّعش» أو الدرجة بيظهر لولي الأمر بتاريخه.',
      icon: 'reports',
    ),
    ReleaseItem(
      'إخفاء الأرقام بيفضل',
      'لو قفلت أرقام الرئيسية، ترجع مقفولة بعد ما تخرج من التطبيق.',
      icon: 'settings',
    ),
  ]),
  ReleaseNote('1.2.89', [
    ReleaseItem(
      'التسميع أدق',
      '«حضر وما سمّعش» بدون صفر، والغايب بدون خانة، وتنبيه قبل الحفظ، والضيف بيظهر.',
      icon: 'star',
    ),
    ReleaseItem(
      'مين فتح رابط المتابعة',
      'شوف مين فتح الرابط وآخر زيارة، وفلتر «ما فتحوش» تبعتلهم.',
      icon: 'reports',
    ),
    ReleaseItem(
      'السناتر',
      'نظّم مجموعاتك تحت سنتر بأقسام وفلتر.',
      icon: 'settings',
    ),
    ReleaseItem(
      'رسوم الشهر أوضح',
      'مستحق ومحصّل ومتبقي، وغير المدفوعين بالمبلغ، وتنقّل بين الشهور.',
      icon: 'income',
    ),
    ReleaseItem(
      'مزامنة الفريق أأمن',
      'تأكيد قبل تعطيل الفريق مع نسخة احتياطية تلقائية، وعلاج لو الفريق اتمسح.',
      icon: 'delete',
    ),
  ]),
  ReleaseNote('1.2.87', [
    ReleaseItem(
      'واتساب تلقائي',
      'رسائل الغياب وتأخر الدفع والإيصالات من رقم Active Class. خدمة بباقات رسايل، اطلب التفعيل من الإعدادات.',
      icon: 'chat',
    ),
    ReleaseItem(
      'تقارير أوضح',
      'تبويبات للحضور والدفعات والامتحانات، ومقارنة بالشهر اللي فات ورسم لآخر ٦ شهور.',
      icon: 'reports',
    ),
    ReleaseItem(
      'دخلي',
      'الكاش اللي دخل فعلًا الشهر ده، وكارت الرئيسية فيه تابين: الدفعات والدخل.',
      icon: 'income',
    ),
    ReleaseItem(
      'امتحان من صورة أو ملف',
      'صوّر الامتحان يتحوّل لمسودة أسئلة تراجعها قبل النشر.',
      icon: 'exam',
    ),
    ReleaseItem(
      'حذف مرن للبيانات',
      'اختار الأقسام والفترة اللي تحذفها بدل «احذف كل حاجة».',
      icon: 'delete',
    ),
  ]),
];

/// «1.2.87» أو «1.2.87+4110» → [1, 2, 87]؛ null لو الصيغة مش مفهومة.
List<int>? parseVersion(String? v) {
  if (v == null) return null;
  final core = v.split('+').first.trim();
  final parts = core.split('.');
  if (parts.length != 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null)) return null;
  return nums.cast<int>();
}

/// -1 / 0 / 1. صيغة مجهولة تتعامل كأنها 0.0.0.
int compareVersions(String? a, String? b) {
  final x = parseVersion(a) ?? const [0, 0, 0];
  final y = parseVersion(b) ?? const [0, 0, 0];
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// اللي يتعرض: إصدارات أحدث من [lastSeen] وأقدم من أو يساوي [current]، الأحدث
/// أولًا، وبحد أقصى [max]. أول تثبيت ([lastSeen] == null) = مفيش حاجة تتعرض
/// (مدرس جديد مايحتاجش «الجديد»). إصدار بلا ملاحظات = مفيش نافذة.
List<ReleaseNote> notesToShow({
  required String? lastSeen,
  required String current,
  List<ReleaseNote> notes = kReleaseNotes,
  int max = 3,
}) {
  if (lastSeen == null || parseVersion(current) == null) return const [];
  final out = notes
      .where((n) =>
          compareVersions(n.version, lastSeen) > 0 &&
          compareVersions(n.version, current) <= 0)
      .toList()
    ..sort((a, b) => compareVersions(b.version, a.version));
  return out.take(max).toList();
}
