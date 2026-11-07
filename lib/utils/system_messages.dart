// lib/utils/system_messages.dart
//
// قوالب رسائل واتساب اللي البرنامج بيبعتها بنفسه (تنبيه غياب، تذكير دفع،
// إيصال، كشف حساب…). كل نوع له نص افتراضي (= نفس صياغة البرنامج الأصلية)
// وممكن المعلم يعدّله. لو مفيش تعديل، دوال البناء الأصلية بتشتغل زي ما هي؛
// ولو فيه تعديل، بيتعبّى بنفس المتغيّرات. منطق بحت (من غير UI/DB) عشان يتختبر.
import 'dart:convert';

/// وصف نوع رسالة من رسائل البرنامج.
class SystemMessageDef {
  final String id;
  final String title;
  final String description;

  /// المتغيّرات اللي النوع ده بيعبّيها.
  final List<String> vars;

  /// النص الافتراضي (قالب بمتغيّرات).
  final String defaultBody;

  /// قيم مثال للمعاينة.
  final Map<String, String> sample;

  const SystemMessageDef({
    required this.id,
    required this.title,
    required this.description,
    required this.vars,
    required this.defaultBody,
    required this.sample,
  });
}

const _common = {
  'اسم_الطالب': 'أحمد محمد',
  'الكود': 'AC1024',
  'المجموعة': 'أولى ثانوي',
  'التاريخ': '2026-11-07',
  'المعلم': 'أ/ محمود علي',
  'التخصص': 'رياضيات',
};

const List<SystemMessageDef> kSystemMessageDefs = [
  SystemMessageDef(
    id: 'absence',
    title: 'تنبيه غياب',
    description: 'بتتبعت لولي الأمر لما الطالب يغيب عن حصة.',
    vars: ['اسم_الطالب', 'الكود', 'المجموعة', 'التاريخ', 'المعلم', 'التخصص'],
    defaultBody: '⚠️ *تنبيه غياب*\n'
        '👤 {اسم_الطالب} ({الكود})\n'
        '👥 {المجموعة}\n'
        '📅 {التاريخ}\n'
        '👨‍🏫 {المعلم}\n'
        '📘 {التخصص}',
    sample: _common,
  ),
  SystemMessageDef(
    id: 'late',
    title: 'تنبيه تأخير',
    description: 'بتتبعت لولي الأمر لما الطالب يتأخر عن الحصة.',
    vars: ['اسم_الطالب', 'الكود', 'المجموعة', 'التاريخ', 'المعلم', 'التخصص'],
    defaultBody: '⚠️ *تنبيه تأخير*\n'
        '👤 {اسم_الطالب} ({الكود})\n'
        '👥 {المجموعة}\n'
        '📅 {التاريخ}\n'
        '👨‍🏫 {المعلم}\n'
        '📘 {التخصص}',
    sample: _common,
  ),
  SystemMessageDef(
    id: 'payment_reminder',
    title: 'تذكير بالدفع',
    description: 'تنبيه تأخر الدفع اللي بتبعته للمتأخرين.',
    vars: [
      'اسم_الطالب',
      'الكود',
      'المجموعة',
      'الشهر',
      'المتبقي',
      'المعلم',
      'التخصص'
    ],
    defaultBody: '⚠️ *تنبيه تأخر الدفع*\n'
        '👤 {اسم_الطالب} ({الكود})\n'
        '👥 {المجموعة}\n'
        '📅 اشتراك شهر {الشهر}\n'
        '💰 المتبقي من الاشتراك: {المتبقي}\n'
        '👨‍🏫 {المعلم}\n'
        '📘 {التخصص}',
    sample: {
      ..._common,
      'الشهر': 'نوفمبر 2026',
      'المتبقي': '300 ج.م',
    },
  ),
  SystemMessageDef(
    id: 'receipt',
    title: 'إيصال دفع',
    description: 'إيصال بيوصل لولي الأمر بعد كل دفعة.',
    vars: [
      'اسم_الطالب',
      'الكود',
      'المجموعة',
      'المبلغ',
      'الشهور',
      'التاريخ',
      'المتبقي'
    ],
    defaultBody: '🧾 *إيصال دفع*\n'
        '👤 {اسم_الطالب} ({الكود})\n'
        '👥 {المجموعة}\n'
        '💰 المبلغ المدفوع: {المبلغ}\n'
        '📅 عن: {الشهور}\n'
        '🗓 التاريخ: {التاريخ}\n'
        '⏳ المتبقي: {المتبقي}',
    sample: {
      ..._common,
      'المبلغ': '200 ج.م',
      'الشهور': 'نوفمبر 2026',
      'المتبقي': '100 ج.م',
    },
  ),
  SystemMessageDef(
    id: 'statement',
    title: 'كشف حساب',
    description: 'ملخص مستحق ومدفوع ومتبقي الطالب.',
    vars: [
      'اسم_الطالب',
      'الكود',
      'المجموعة',
      'المستحق',
      'المدفوع',
      'المُسقَط',
      'المتبقي',
      'تفاصيل_الشهور'
    ],
    defaultBody: '📋 *كشف حساب*\n'
        '👤 {اسم_الطالب} ({الكود})\n'
        '👥 {المجموعة}\n'
        '💼 المستحق: {المستحق}\n'
        '✅ المدفوع: {المدفوع}\n'
        '➖ مُسقَط: {المُسقَط}\n'
        '⏳ المتبقي: {المتبقي}\n'
        '{تفاصيل_الشهور}',
    sample: {
      ..._common,
      'المستحق': '900 ج.م',
      'المدفوع': '600 ج.م',
      'المُسقَط': '',
      'المتبقي': '300 ج.م',
      'تفاصيل_الشهور': '   • نوفمبر 2026: 300 ج.م',
    },
  ),
  SystemMessageDef(
    id: 'exam_result',
    title: 'نتيجة امتحان',
    description: 'نتيجة امتحان الطالب لولي الأمر (للي حضر الامتحان).',
    vars: [
      'اسم_الطالب',
      'الامتحان',
      'الدرجة',
      'الدرجة_العظمى',
      'الحالة',
      'ملاحظات',
      'المعلم',
      'التخصص'
    ],
    defaultBody: '📝 *نتيجة امتحان*\n'
        '👤 {اسم_الطالب}\n'
        '📝 امتحان "{الامتحان}"\n'
        '📊 الدرجة: {الدرجة} من {الدرجة_العظمى}\n'
        '{الحالة}\n'
        '📌 ملاحظات: {ملاحظات}\n'
        '👨‍🏫 {المعلم}\n'
        '📘 {التخصص}',
    sample: {
      ..._common,
      'الامتحان': 'امتحان الشهر',
      'الدرجة': '17',
      'الدرجة_العظمى': '20',
      'الحالة': '🟢 الحالة: ناجح',
      'ملاحظات': '',
    },
  ),
  SystemMessageDef(
    id: 'booklet_reminder',
    title: 'تذكير بمتبقي ملزمة',
    description: 'تذكير ولي الأمر بمتبقي سعر ملزمة.',
    vars: ['اسم_الطالب', 'الملزمة', 'السعر', 'المدفوع', 'المتبقي', 'المعلم'],
    defaultBody: 'السلام عليكم ورحمة الله\n'
        'تذكير بخصوص "{الملزمة}" للطالب/ة {اسم_الطالب}:\n'
        '• السعر: {السعر}\n'
        '• المدفوع: {المدفوع}\n'
        '• المتبقي: {المتبقي}\n'
        '\n'
        'برجاء السداد في أقرب وقت. شكرًا لحضراتكم.\n'
        '\n'
        '{المعلم}',
    sample: {
      'اسم_الطالب': 'أحمد محمد',
      'الملزمة': 'ملزمة الوحدة الأولى',
      'السعر': '50 ج.م',
      'المدفوع': '20 ج.م',
      'المتبقي': '30 ج.م',
      'المعلم': 'أ/ محمود علي',
    },
  ),
  SystemMessageDef(
    id: 'portal_invite',
    title: 'دعوة بوابة ولي الأمر',
    description: 'رابط متابعة الطالب وكوده لولي الأمر.',
    vars: ['اسم_الطالب', 'الرابط', 'الكود', 'تعليمة_الأمان'],
    defaultBody: '📲 *متابعة {اسم_الطالب}*\n'
        'تقدر تتابع حضوره ومدفوعاته وواجبه ودرجاته من الرابط ده:\n'
        '{الرابط}\n'
        '🔑 كود الطالب: {الكود}\n'
        '{تعليمة_الأمان}',
    sample: {
      'اسم_الطالب': 'أحمد محمد',
      'الرابط': 'https://active-class.online/p/xyz',
      'الكود': 'AC1024',
      'تعليمة_الأمان':
          '🔒 وبعدين اكتب آخر 4 أرقام من رقم تليفونك المسجّل عندنا.',
    },
  ),
];

SystemMessageDef? systemMessageDef(String id) {
  for (final d in kSystemMessageDefs) {
    if (d.id == id) return d;
  }
  return null;
}

final RegExp _sysVar = RegExp(r'\{([^{}\s][^{}]*)\}');

/// بيعبّي القالب: سطر كل متغيّراته فاضية بيتشال (عشان ما يظهرش «📘 » فاضي).
/// متغيّر مش موجود في [values] بيتساب زي ما هو.
String renderSystemBody(String body, Map<String, String> values) {
  final out = <String>[];
  for (final line in body.split('\n')) {
    final ms = _sysVar.allMatches(line).toList();
    if (ms.isNotEmpty &&
        ms.every((m) {
          final v = values[m.group(1)!.trim()];
          return v != null && v.trim().isEmpty;
        })) {
      continue;
    }
    out.add(line.replaceAllMapped(_sysVar, (m) {
      final v = values[m.group(1)!.trim()];
      return v == null ? m.group(0)! : v.trim();
    }));
  }
  return out.join('\n').trimRight();
}

/// المتغيّرات المكتوبة في النص ومش من متغيّرات النوع ده (غالبًا غلطة كتابة).
List<String> unknownVariables(SystemMessageDef def, String body) {
  final seen = <String>[];
  for (final m in _sysVar.allMatches(body)) {
    final v = m.group(1)!.trim();
    if (!def.vars.contains(v) && !seen.contains(v)) seen.add(v);
  }
  return seen;
}

const String kSystemMessagesPrefsKey = 'system_message_overrides';

/// التعديلات المحفوظة (id → نص). بتتحمّل مرة وقت بدء التطبيق، ودوال البناء
/// بتسأل عنها. من غير تعديل → null والدالة الأصلية تكمل.
class SystemMessages {
  SystemMessages._();

  static final Map<String, String> _overrides = {};

  static String? overrideFor(String id) {
    final v = _overrides[id];
    return (v == null || v.trim().isEmpty) ? null : v;
  }

  static bool isCustomized(String id) => overrideFor(id) != null;

  static void set(String id, String? body) {
    if (body == null || body.trim().isEmpty) {
      _overrides.remove(id);
    } else {
      _overrides[id] = body;
    }
  }

  static void clearAll() => _overrides.clear();

  static String encode() => jsonEncode(_overrides);

  static void decode(String? raw) {
    _overrides.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        for (final e in m.entries) {
          if (e.value is String) _overrides['${e.key}'] = e.value as String;
        }
      }
    } catch (_) {}
  }

  /// لو النوع معدّل: بيرجّع النص معبّى، وإلا null.
  static String? renderOverride(String id, Map<String, String> values) {
    final o = overrideFor(id);
    return o == null ? null : renderSystemBody(o, values);
  }
}
