// lib/utils/leaderboard_share.dart
//
// spec 018 — نص مشاركة قائمة الأوائل (واتساب). أول 20، ميداليات للـ3
// الأوائل وأرقام للباقي.

import 'package:active_class/models/exam_grade_model.dart';

String buildLeaderboardShareText(
  List<LeaderboardEntry> entries, {
  required String filterLabel,
  String teacherLine = '',
}) {
  final top = entries.take(20).toList();
  final b = StringBuffer();
  b.writeln('🏆 قائمة الأوائل — $filterLabel');
  b.writeln('');
  for (var i = 0; i < top.length; i++) {
    final e = top[i];
    final medal = switch (i) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => '${i + 1}.',
    };
    b.writeln('$medal ${e.studentName} — ${e.percentage.toStringAsFixed(0)}%');
  }
  if (teacherLine.trim().isNotEmpty) {
    b.writeln('');
    b.writeln('— ${teacherLine.trim()}');
  }
  return b.toString().trimRight();
}
