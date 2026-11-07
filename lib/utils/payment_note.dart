// lib/utils/payment_note.dart
//
// ترميز/فك ترميز ملاحظة الدفعة. الدفعة بتخزّن أشهرها في `note` بصيغة:
//   months=2026-09,2026-10;custom=1;note=نص حر;siblings=3
// كل المكان اللي بيقرا أو بيكتب الصيغة دي لازم يعدّي من هنا (بدل ما كل شاشة
// تعمل split بنفسها)، وفيه كمان فحص منطقية الشهور.

class PaymentNote {
  /// الشهور المدفوعة (أول يوم في كل شهر)، بالترتيب المكتوب.
  final List<DateTime> months;
  final bool custom;
  final String? text;
  final int? siblings;
  final int? sessions;

  const PaymentNote({
    this.months = const [],
    this.custom = false,
    this.text,
    this.siblings,
    this.sessions,
  });

  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// يفك الملاحظة. أي ملاحظة مش بالصيغة دي (حرة/فاضية/إسقاط) بترجع بلا شهور.
  static PaymentNote parse(String? note) {
    if (note == null || note.trim().isEmpty) return const PaymentNote();
    final months = <DateTime>[];
    var custom = false;
    String? text;
    int? siblings;
    int? sessions;
    for (final part in note.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final k = part.substring(0, i).trim();
      final v = part.substring(i + 1);
      switch (k) {
        case 'months':
          for (final raw in v.split(',')) {
            final m = _parseMonth(raw.trim());
            if (m != null) months.add(m);
          }
        case 'custom':
          custom = v.trim() == '1';
        case 'note':
          text = v;
        case 'siblings':
          siblings = int.tryParse(v.trim());
        case 'sessions':
          sessions = int.tryParse(v.trim());
      }
    }
    return PaymentNote(
        months: months,
        custom: custom,
        text: text,
        siblings: siblings,
        sessions: sessions);
  }

  static DateTime? _parseMonth(String s) {
    final parts = s.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12 || y < 2000 || y > 2100) {
      return null;
    }
    return DateTime(y, m);
  }

  /// يبني الملاحظة. بلا شهور وبلا إضافات → null.
  static String? encode({
    required List<DateTime> months,
    bool custom = false,
    String? text,
    int? siblings,
    int? sessions,
  }) {
    final extra = [
      if (custom) 'custom=1',
      if (text != null && text.isNotEmpty) 'note=$text',
      if (siblings != null) 'siblings=$siblings',
      if (sessions != null) 'sessions=$sessions',
    ];
    final head = months.isEmpty ? null : 'months=${months.map(monthKey).join(',')}';
    final all = [if (head != null) head, ...extra];
    return all.isEmpty ? null : all.join(';');
  }

  /// آخر شهر مكتوب (أو null).
  DateTime? get lastMonth => months.isEmpty ? null : months.last;

  bool coversMonth(DateTime d) =>
      months.any((m) => m.year == d.year && m.month == d.month);

  /// أقصى عدد شهور قدّام مسموح بيه.
  static const int maxMonthsAhead = 12;

  /// شهر مش منطقي: بعد [maxMonthsAhead] شهر من [now]، أو قبل شهر بداية
  /// الطالب ([earliest]) بأكتر من سنة.
  static bool isImplausibleMonth(DateTime month, DateTime now,
      {DateTime? earliest}) {
    final nowIdx = now.year * 12 + now.month;
    final idx = month.year * 12 + month.month;
    if (idx > nowIdx + maxMonthsAhead) return true;
    if (earliest != null && idx < earliest.year * 12 + earliest.month - 12) {
      return true;
    }
    return false;
  }

  /// الشهور المش منطقية في الملاحظة دي.
  List<DateTime> implausibleMonths(DateTime now, {DateTime? earliest}) => [
        for (final m in months)
          if (isImplausibleMonth(m, now, earliest: earliest)) m
      ];
}
