// lib/utils/pdf_text.dart
//
// حل عيب في عرض العربي داخل ملفات PDF (حزمة pdf + خط Cairo): حرف "ي" المنفصل
// (آخر الكلمة بعد حرف لا يتّصل بما بعده: ا د ذ ر ز و ة...) بيترسم متداخل مع
// الحرف اللي قبله، فاسم زي "عبد الهادي" بيطلع "عبد الهاه" ("هادي"، "نادي"،
// "شادي"، "وادي"...). الحرف FEF0 بيترسم صح بنفس الخط، فبنبدّل بيه بس
// في الحالة دي. باقي الحروف والأشكال ما بتتأثرش.

const int _yeh = 0x064A;
const int _isolatedYehSubstitute = 0xFEF0;

// حروف لا تتّصل بالحرف اللي بعدها.
const Set<int> _nonJoiners = {
  0x0621, // ء
  0x0622, 0x0623, 0x0624, 0x0625, 0x0627, // آ أ ؤ إ ا
  0x0629, // ة
  0x062F, 0x0630, 0x0631, 0x0632, // د ذ ر ز
  0x0648, // و
  0x0649, // ى
};

bool _isArabicLetterCode(int c) =>
    (c >= 0x0620 && c <= 0x064A) || (c >= 0x0671 && c <= 0x06D3);

bool _isDiacritic(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == 0x0670;

// "(100%)" بين أقواس بيترسم في PDF "(%100)" (عكس المطلوب)، فبنكتبها
// منطقيًا "(%100)" عشان تظهر صح.
final RegExp _parenPercent = RegExp(r'\((\d+(?:\.\d+)?)%\)');

/// يصلّح عيوب عرض العربي في PDF: "ي" المنفصلة + نسبة بين أقواس. بيرجّع
/// النص كما هو لو مفيش حاجة تتغيّر.
String fixArabicForPdf(String text) {
  text = text.replaceAllMapped(_parenPercent, (m) => '(%${m[1]})');
  if (!text.contains('ي')) return text;
  final runes = text.runes.toList();
  var changed = false;
  for (var i = 0; i < runes.length; i++) {
    if (runes[i] != _yeh) continue;

    // الحرف اللي قبلها (نتخطّى التشكيل).
    var p = i - 1;
    while (p >= 0 && _isDiacritic(runes[p])) {
      p--;
    }
    final joinsFromPrev =
        p >= 0 && _isArabicLetterCode(runes[p]) && !_nonJoiners.contains(runes[p]);

    // الحرف اللي بعدها (نتخطّى التشكيل).
    var n = i + 1;
    while (n < runes.length && _isDiacritic(runes[n])) {
      n++;
    }
    final joinsToNext = n < runes.length && _isArabicLetterCode(runes[n]);

    if (!joinsFromPrev && !joinsToNext) {
      runes[i] = _isolatedYehSubstitute;
      changed = true;
    }
  }
  return changed ? String.fromCharCodes(runes) : text;
}
