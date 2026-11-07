// lib/utils/receipt_message.dart
//
// نصوص واتساب لـ«إيصال الدفع» و«كشف الحساب» لولي الأمر. دوال صرفة؛ توقيع
// المعلم بيتضاف لوحده في launchGuardianWhatsapp.
import 'package:active_class/utils/student_statement.dart';

String buildReceiptMessage({
  required String studentName,
  String studentCode = '',
  String groupName = '',
  required double amount,
  required DateTime date,
  List<DateTime> months = const [],
  double? remaining,
  required String Function(double) money,
  required String Function(DateTime) monthLabel,
  required String Function(DateTime) dateLabel,
}) {
  final code = studentCode.trim();
  final b = StringBuffer()
    ..writeln('🧾 *إيصال دفع*')
    ..writeln('👤 $studentName${code.isEmpty ? '' : ' ($code)'}');
  if (groupName.trim().isNotEmpty && groupName.trim() != '-') {
    b.writeln('👥 ${groupName.trim()}');
  }
  b.writeln('💰 المبلغ المدفوع: ${money(amount)}');
  if (months.isNotEmpty) {
    b.writeln('📅 عن: ${months.map(monthLabel).join('، ')}');
  }
  b.writeln('🗓 التاريخ: ${dateLabel(date)}');
  if (remaining != null) {
    b.writeln(remaining > 0.5
        ? '⏳ المتبقي: ${money(remaining)}'
        : '✅ مفيش متبقي');
  }
  return b.toString().trimRight();
}

String buildStatementMessage({
  required String studentName,
  String studentCode = '',
  String groupName = '',
  required StudentStatement statement,
  required String Function(double) money,
  required String Function(DateTime) monthLabel,
  int maxUnpaidLines = 6,
}) {
  final code = studentCode.trim();
  final s = statement;
  final b = StringBuffer()
    ..writeln('📋 *كشف حساب*')
    ..writeln('👤 $studentName${code.isEmpty ? '' : ' ($code)'}');
  if (groupName.trim().isNotEmpty && groupName.trim() != '-') {
    b.writeln('👥 ${groupName.trim()}');
  }
  b
    ..writeln('💼 المستحق: ${money(s.totalDue)}')
    ..writeln('✅ المدفوع: ${money(s.totalPaid)}');
  if (s.totalWrittenOff > 0.5) {
    b.writeln('➖ مُسقَط: ${money(s.totalWrittenOff)}');
  }
  final bal = s.balance;
  if (bal > 0.5) {
    b.writeln('⏳ المتبقي: ${money(bal)}');
    final un = s.unpaidMonths;
    for (final m in un.take(maxUnpaidLines)) {
      b.writeln('   • ${monthLabel(m.month)}: ${money(m.remaining)}');
    }
    if (un.length > maxUnpaidLines) {
      b.writeln('   • و${un.length - maxUnpaidLines} شهور تانية');
    }
  } else if (s.advance > 0.5) {
    b.writeln('✅ مفيش متبقي — رصيد زيادة ${money(s.advance)}');
  } else {
    b.writeln('✅ مفيش متبقي');
  }
  return b.toString().trimRight();
}
