// lib/views/exams/exam_analytics_page.dart
//
// spec 023 — تحليل أسئلة امتحان إلكتروني بعد التصحيح: نسبة الصح لكل
// سؤال، توزيع الاختيارات، أبرز distractor، وعدد من لم يجب. التسليمات
// المُبطَلة مستبعدة (ExamAnalyticsService).
import 'package:flutter/material.dart';

import 'package:active_class/models/exam_analytics_model.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/exam_analytics_service.dart';

class ExamAnalyticsPage extends StatefulWidget {
  final Exam exam;
  const ExamAnalyticsPage({super.key, required this.exam});

  @override
  State<ExamAnalyticsPage> createState() => _ExamAnalyticsPageState();
}

class _ExamAnalyticsPageState extends State<ExamAnalyticsPage> {
  final _db = DatabaseService();
  late Future<List<QuestionAnalytics>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<QuestionAnalytics>> _load() async {
    final examId = widget.exam.id!;
    final questions = await _db.getQuestionsForExam(examId);
    final subs = await _db.getSubmissionsForExam(examId);
    return ExamAnalyticsService.compute(questions: questions, submissions: subs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحليل الأسئلة',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
        body: FutureBuilder<List<QuestionAnalytics>>(
          future: _future,
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;
            final analysed = data.isEmpty ? 0 : data.first.totalRespondents;
            if (data.isEmpty || analysed == 0) {
              return _empty(cs);
            }
            final weakest = [...data]
              ..sort((a, b) => a.correctRate.compareTo(b.correctRate));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _summary(cs, analysed, weakest.first),
                const SizedBox(height: 14),
                ...data.asMap().entries.map(
                    (e) => _card(cs, e.key + 1, e.value)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('لا توجد تسليمات كافية للتحليل',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.55))),
          ]),
        ),
      );

  Widget _summary(ColorScheme cs, int analysed, QuestionAnalytics weakest) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تحليل $analysed تسليم',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              'أضعف سؤال: «${weakest.questionText}» '
              '(${(weakest.correctRate * 100).round()}% صح)',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.7))),
        ]),
      );

  Widget _card(ColorScheme cs, int number, QuestionAnalytics a) {
    final pct = (a.correctRate * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$number. ',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(a.questionText,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: a.correctRate,
                minHeight: 7,
                backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(
                    pct >= 60 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$pct% صح (${a.correctCount}/${a.totalRespondents})',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ...a.options.asMap().entries.map((e) {
          final i = e.key;
          final isCorrect = i == a.correctIndex;
          final isDistractor = i == a.topDistractorIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : (isDistractor
                      ? const Color(0xFFEF4444).withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: isDistractor
                  ? Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(children: [
              if (isCorrect)
                const Icon(Icons.check_rounded,
                    size: 14, color: Color(0xFF059669))
              else
                const SizedBox(width: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(e.value,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight:
                            isCorrect ? FontWeight.w800 : FontWeight.w500)),
              ),
              Text('${a.optionCounts[i]}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.6))),
            ]),
          );
        }),
        const SizedBox(height: 4),
        Text('لم يجب: ${a.notAnsweredCount}',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                color: cs.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }
}
