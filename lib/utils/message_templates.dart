// lib/utils/message_templates.dart
//
// رسائل واتساب محفوظة يكتبها المعلم بنفسه (حصة ملغية، نتيجة امتحان، مستوى
// الطالب…). المتغيّرات بتتكتب وسط النص بين أقواس `{اسم_الطالب}` وبتتعبّى وقت
// الإرسال. «المستوى» بيتحدد من قايمة مستويات يعرّفها المعلم (ممتاز، جيد جدًا…).
// منطق بحت (من غير UI/DB) عشان يتختبر.

/// تصنيف الرسالة (للترتيب والاقتراح فقط).
enum MessageCategory { general, cancel, exam, level }

extension MessageCategoryX on MessageCategory {
  String get dbValue => name;
  String get label => switch (this) {
        MessageCategory.general => 'عامة',
        MessageCategory.cancel => 'حصة ملغية / ظرف طارئ',
        MessageCategory.exam => 'نتيجة امتحان',
        MessageCategory.level => 'مستوى الطالب',
      };
  static MessageCategory fromDb(String? v) => MessageCategory.values
      .firstWhere((c) => c.name == v, orElse: () => MessageCategory.general);
}

/// أسماء المتغيّرات المدعومة (بالعربي زي ما بتتكتب في النص).
class MsgVar {
  static const student = 'اسم_الطالب';
  static const group = 'المجموعة';
  static const date = 'التاريخ';
  static const grade = 'الدرجة';
  static const level = 'المستوى';
  static const teacher = 'المعلم';
  static const all = [student, group, date, grade, level, teacher];
}

/// مستويات افتراضية لو المعلم ما عرّفش مستويات لرسالته.
const List<String> kDefaultLevels = ['ممتاز', 'جيد جدًا', 'جيد', 'مقبول'];

class MessageTemplate {
  final int? id;
  final String title;
  final String body;
  final MessageCategory category;

  /// قايمة المستويات اللي بتظهر كشرايح لو النص فيه {المستوى}.
  final List<String> levels;

  const MessageTemplate({
    this.id,
    required this.title,
    required this.body,
    this.category = MessageCategory.general,
    this.levels = const [],
  });

  bool get isValid => title.trim().isNotEmpty && body.trim().isNotEmpty;

  /// المستويات الفعلية: المعرّفة، وإلا الافتراضية.
  List<String> get effectiveLevels =>
      levels.where((l) => l.trim().isNotEmpty).isEmpty
          ? kDefaultLevels
          : levels.where((l) => l.trim().isNotEmpty).toList();

  MessageTemplate copyWith({
    int? id,
    String? title,
    String? body,
    MessageCategory? category,
    List<String>? levels,
  }) =>
      MessageTemplate(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        levels: levels ?? this.levels,
      );
}

final RegExp _varPattern = RegExp(r'\{([^{}\s][^{}]*)\}');

/// المتغيّرات المستخدمة فعلًا في النص (بدون تكرار، بترتيب ظهورها).
/// بيشمل بس المتغيّرات المعروفة.
List<String> templateVariables(String body) {
  final seen = <String>[];
  for (final m in _varPattern.allMatches(body)) {
    final v = m.group(1)!.trim();
    if (MsgVar.all.contains(v) && !seen.contains(v)) seen.add(v);
  }
  return seen;
}

/// المتغيّرات اللي لازم المعلم يدخلها وقت الإرسال (مش بتتعبّى تلقائيًا).
List<String> askedVariables(String body) => templateVariables(body)
    .where((v) => v == MsgVar.grade || v == MsgVar.level)
    .toList();

/// بيعبّي المتغيّرات. متغيّر معروف من غير قيمة بيفضل زي ما هو ({الدرجة})
/// عشان يبان إنه ناقص في المعاينة؛ ومتغيّر مش معروف بيتساب كمان.
String renderTemplate(String body, Map<String, String> values) {
  return body.replaceAllMapped(_varPattern, (m) {
    final name = m.group(1)!.trim();
    final v = values[name];
    return (v == null || v.trim().isEmpty) ? m.group(0)! : v.trim();
  });
}

/// المتغيّرات المعروفة اللي لسه ناقصة بعد التعبئة.
List<String> missingVariables(String body, Map<String, String> values) {
  return templateVariables(body)
      .where((v) => (values[v] ?? '').trim().isEmpty)
      .toList();
}

/// رسايل جاهزة تتضاف أول مرة (المعلم يعدّل عليها أو يمسحها).
List<MessageTemplate> starterTemplates() => const [
      MessageTemplate(
        title: 'حصة ملغية لظرف طارئ',
        category: MessageCategory.cancel,
        body: 'السلام عليكم ورحمة الله 🌷\n'
            'نعتذر، حصة {المجموعة} يوم {التاريخ} اتلغت لظرف طارئ.\n'
            'هنبلّغكم بميعاد التعويض قريبًا إن شاء الله.',
      ),
      MessageTemplate(
        title: 'نتيجة الامتحان',
        category: MessageCategory.exam,
        body: 'السلام عليكم ورحمة الله 🌷\n'
            'نتيجة {اسم_الطالب} في امتحان {التاريخ}: {الدرجة}.',
      ),
      MessageTemplate(
        title: 'مستوى الطالب',
        category: MessageCategory.level,
        body: 'السلام عليكم ورحمة الله 🌷\n'
            'مستوى {اسم_الطالب} هذا الشهر: {المستوى}.',
        levels: kDefaultLevels,
      ),
      MessageTemplate(
        title: 'رسالة عامة',
        category: MessageCategory.general,
        body: 'السلام عليكم ورحمة الله 🌷\n',
      ),
    ];
