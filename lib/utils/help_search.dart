// lib/utils/help_search.dart
//
// بحث مركز المساعدة: صرف (بلا Flutter/GetX)، أوفلاين. بيفهم الكلام العامّي
// ("إزاي أسجل دفعة؟") بشيل كلمات الربط وتطبيع العربي، ويرتّب النتايج بنقاط:
// العنوان > الكلمات المفتاحية > الملخص > الخطوات والنصايح.
import 'package:active_class/help/help_content.dart';
import 'package:active_class/utils/arabic_normalize.dart';

const _stop = <String>{
  'ازاي', 'كيف', 'عايز', 'عاوز', 'اعمل', 'اسجل', 'ايه', 'اي', 'هل', 'ممكن',
  'في', 'من', 'علي', 'على', 'عن', 'الي', 'لو', 'انا', 'عشان', 'علشان', 'ده',
  'دي', 'مع', 'او', 'و', 'بيه', 'ليه', 'فين', 'امتي', 'طيب',
};

// كلمات بتدل إن السؤال عن مشكلة — وقتها مواضيع "حلول سريعة" تتقدّم.
const _problem = <String>{
  'مش', 'مشكله', 'حل', 'عطل', 'خطا', 'مقفول', 'فشل', 'بيفتح', 'ظاهر',
  'شايف', 'بيظهر', 'مسجل',
};

/// كلمات البحث بعد التطبيع وشيل كلمات الربط وعلامات الترقيم.
List<String> helpQueryTokens(String query) {
  final n = normalizeArabic(query).replaceAll(RegExp(r'[؟?!.,،:؛"()]'), ' ');
  return n
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1 && !_stop.contains(w))
      .toList();
}

String _flat(HelpTopic t, Iterable<String> parts) =>
    normalizeArabic(parts.join(' ').replaceAll('**', ''));

int _score(HelpTopic t, List<String> tokens) {
  final title = normalizeArabic(t.title);
  final keys = _flat(t, t.keywords);
  final summary = _flat(t, [t.summary]);
  final body = _flat(t, [...t.steps, ...t.tips]);
  var score = 0;
  var matched = 0;
  for (final w in tokens) {
    var hit = 0;
    if (title.contains(w)) hit += 10;
    if (keys.contains(w)) hit += 6;
    if (summary.contains(w)) hit += 3;
    if (body.contains(w)) hit += 1;
    if (hit > 0) matched++;
    score += hit;
  }
  // كل الكلمات موجودة = أولوية، ونتيجة بكلمة واحدة من كتير ضعيفة.
  if (matched == tokens.length) score += 5;
  // مواضيع الحلول ما تسبقش شرح الميزة نفسها إلا لو السؤال عن مشكلة.
  if (t.category == HelpCategory.fixes &&
      !tokens.any(_problem.contains) &&
      score > 0) {
    score = (score - 25).clamp(1, 1 << 20);
  }
  return score;
}

/// المواضيع المطابقة مرتبة بالأقرب أولًا. بحث فاضي → الكل بترتيبه.
List<HelpTopic> searchHelp(String query, {List<HelpTopic> topics = kHelpTopics}) {
  final tokens = helpQueryTokens(query);
  if (tokens.isEmpty) return List.of(topics);
  final scored = <(HelpTopic, int)>[];
  for (final t in topics) {
    final s = _score(t, tokens);
    if (s > 0) scored.add((t, s));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.map((e) => e.$1).toList();
}
