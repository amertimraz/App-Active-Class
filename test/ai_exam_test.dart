// test/ai_exam_test.dart — spec 057: تحضير الصور، تحويل ردود الذكاء الاصطناعي لمسودات، ورسايل الأخطاء.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:active_class/models/ai_draft_question.dart';
import 'package:active_class/services/ai_exam_service.dart';
import 'package:active_class/utils/ai_exam_prepare.dart';

void main() {
  group('تحضير الصور', () {
    test('PNG كبير يتحوّل لـ JPEG بأقصى ضلع 1600', () {
      final png = img.encodePng(img.Image(width: 3000, height: 2000));
      final out = compressToJpegSync(Uint8List.fromList(png));
      expect(out[0], 0xFF); // بداية JPEG
      expect(out[1], 0xD8);
      final d = img.decodeJpg(out)!;
      expect(d.width, kAiMaxSide);
      expect(d.height, lessThan(kAiMaxSide));
    });

    test('صورة طويلة (رأسية) تتصغّر على الطول', () {
      final png = img.encodePng(img.Image(width: 1000, height: 3200));
      final d = img.decodeJpg(compressToJpegSync(Uint8List.fromList(png)))!;
      expect(d.height, kAiMaxSide);
    });

    test('صورة صغيرة ما تتكبّرش', () {
      final png = img.encodePng(img.Image(width: 400, height: 300));
      final d = img.decodeJpg(compressToJpegSync(Uint8List.fromList(png)))!;
      expect(d.width, 400);
    });

    test('ملف مش صورة يرمي خطأ', () {
      expect(() => compressToJpegSync(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<FormatException>()));
    });

    test('حدود الطلب: عدد الصور والحجم', () {
      expect(checkAiLimits(imageCount: 3, totalBytes: 1000).ok, isTrue);
      expect(checkAiLimits(imageCount: kAiMaxImages + 1, totalBytes: 1).ok, isFalse);
      expect(checkAiLimits(imageCount: 1, totalBytes: kAiMaxBytes + 1).ok, isFalse);
    });
  });

  group('مسودات الأسئلة', () {
    test('سؤال سليم بإجابة', () {
      final q = AiDraftQuestion.fromJson({
        'text': ' ما عاصمة مصر؟ ',
        'options': ['القاهرة', 'أسوان', ''],
        'correct_index': 0,
        'explanation': 'شرح',
        'needs_review': false,
        'source_page': 2,
      });
      expect(q.text, 'ما عاصمة مصر؟');
      expect(q.options, ['القاهرة', 'أسوان']); // الفاضي اتشال
      expect(q.hasAnswer, isTrue);
      expect(q.sourcePage, 2);
    });

    test('إجابة null أو خارج المدى = غير محددة (-1)', () {
      expect(AiDraftQuestion.fromJson({'text': 'س', 'options': ['أ', 'ب'], 'correct_index': null}).correctIndex, -1);
      expect(AiDraftQuestion.fromJson({'text': 'س', 'options': ['أ', 'ب'], 'correct_index': 5}).correctIndex, -1);
      expect(AiDraftQuestion.fromJson({'text': 'س', 'options': ['أ', 'ب'], 'correct_index': 1}).hasAnswer, isTrue);
    });

    test('صح/خطأ بيتعرّف عليه', () {
      expect(const AiDraftQuestion(text: 'س', options: ['صح', 'خطأ'], correctIndex: 0).looksTrueFalse, isTrue);
      expect(const AiDraftQuestion(text: 'س', options: ['صح', 'غلط'], correctIndex: 1).looksTrueFalse, isTrue);
      expect(const AiDraftQuestion(text: 'س', options: ['أ', 'ب'], correctIndex: 0).looksTrueFalse, isFalse);
    });

    test('type=true_false من الخدمة بيتعرّف عليه، والافتراضي mcq', () {
      final tf = AiDraftQuestion.fromJson({'text': 'عبارة', 'options': ['صح', 'خطأ'], 'correct_index': 1, 'type': 'true_false'});
      expect(tf.type, 'true_false');
      expect(tf.looksTrueFalse, isTrue);
      final m = AiDraftQuestion.fromJson({'text': 'س', 'options': ['أ', 'ب', 'ج', 'د'], 'correct_index': 2});
      expect(m.type, 'mcq');
      expect(m.looksTrueFalse, isFalse);
    });

    test('النتيجة: بتشيل الأسئلة الناقصة وبتعدّ المراجعة', () {
      final r = AiExamResult.fromJson({
        'questions': [
          {'text': 'سؤال 1', 'options': ['أ', 'ب'], 'correct_index': 0, 'needs_review': true},
          {'text': '', 'options': ['أ', 'ب']},
          {'text': 'سؤال ناقص', 'options': ['أ']},
          {'text': 'سؤال 2', 'options': ['أ', 'ب', 'ج'], 'correct_index': null, 'needs_review': true},
        ],
        'skipped': 2,
        'notes': ['المحتوى قليل'],
      });
      expect(r.questions.length, 2);
      expect(r.needsReviewCount, 2);
      expect(r.skipped, 2);
      expect(r.notes, ['المحتوى قليل']);
    });
  });

  group('رسايل الأخطاء', () {
    test('كل سبب له رسالة عربي، والمجهول له رسالة عامة', () {
      for (final r in ['unreadable', 'not_educational', 'quota', 'paused', 'busy', 'timeout', 'bad_output', 'too_large', 'login']) {
        expect(aiFailMessage(r).isNotEmpty, isTrue);
        expect(aiFailMessage(r), isNot(aiFailMessage('zzz')));
      }
      expect(aiFailMessage(null), aiFailMessage('zzz'));
    });
  });
}
