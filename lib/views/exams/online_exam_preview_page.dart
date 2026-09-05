// lib/views/exams/online_exam_preview_page.dart
//
// spec 023 — معاينة الامتحان الإلكتروني كما يراه الطالب: شاشة عرض
// للقراءة فقط. بلا إجابة صحيحة، بلا شرح، بلا أي زر اختيار/تسليم.
import 'package:flutter/material.dart';

import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_question_model.dart';

class OnlineExamPreviewPage extends StatelessWidget {
  final Exam exam;
  final List<ExamQuestion> questions;
  const OnlineExamPreviewPage({
    super.key,
    required this.exam,
    required this.questions,
  });

  double get _totalPoints =>
      questions.fold<double>(0, (s, q) => s + q.points);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('معاينة الامتحان',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _header(cs),
            const SizedBox(height: 10),
            _previewBanner(cs),
            const SizedBox(height: 14),
            ...questions.asMap().entries.map((e) => _questionCard(cs, e.key + 1, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.name.trim().isEmpty ? 'امتحان بدون اسم' : exam.name.trim(),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(cs, Icons.help_outline_rounded, '${questions.length} سؤال'),
                _chip(cs, Icons.star_border_rounded,
                    'الدرجة الكلية: ${_fmt(_totalPoints)}'),
                _chip(
                    cs,
                    Icons.timer_outlined,
                    'المدة: ${exam.durationMinutes != null ? '${exam.durationMinutes} دقيقة' : '—'}'),
              ],
            ),
          ],
        ),
      );

  Widget _chip(ColorScheme cs, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _previewBanner(ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.visibility_outlined, size: 16, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'معاينة — لو الخلط مفعّل، ترتيب الأسئلة والاختيارات عند الطالب ممكن يختلف.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309)),
            ),
          ),
        ]),
      );

  Widget _questionCard(ColorScheme cs, int number, ExamQuestion q) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$number',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cs.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(q.text,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.4)),
                ),
                const SizedBox(width: 8),
                Text('${_fmt(q.points)} د',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  q.imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (ctx, err, st) => Container(
                    height: 90,
                    alignment: Alignment.center,
                    color: cs.onSurface.withValues(alpha: 0.05),
                    child: Text('تعذّر تحميل صورة السؤال',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...q.options.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(opt,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
