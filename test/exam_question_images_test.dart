// test/exam_question_images_test.dart — spec 043
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/widgets/image_crop_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alignOptionImages', () {
    test('قائمة أقصر من options تتكمّل null', () {
      final r = alignOptionImages(['a'], 3);
      expect(r, ['a', null, null]);
    });

    test('قائمة أطول من options تُقص', () {
      final r = alignOptionImages(['a', 'b', 'c', 'd'], 2);
      expect(r, ['a', 'b']);
    });

    test('المدخل الأصلي لا يتغيّر', () {
      final input = ['a'];
      alignOptionImages(input, 3);
      expect(input, ['a']);
    });
  });

  group('addOptionImageSlot / removeOptionImageSlot', () {
    test('الإضافة تحط null في الآخر', () {
      final r = addOptionImageSlot(['x', null]);
      expect(r, ['x', null, null]);
    });

    test('الحذف بالـindex الصحيح', () {
      final r = removeOptionImageSlot(['a', 'b', 'c'], 1);
      expect(r, ['a', 'c']);
    });

    test('حذف index خارج النطاق لا يغيّر القائمة', () {
      final r = removeOptionImageSlot(['a', 'b'], 9);
      expect(r, ['a', 'b']);
    });
  });

  group('ExamQuestion — صور الاختيارات والشرح', () {
    test('toCloudMap يحتوي optionImageUrls لو فيه صورة واحدة على الأقل', () {
      final q = ExamQuestion(
        id: 1,
        examId: 1,
        position: 0,
        type: ExamQuestionType.mcq,
        text: 'سؤال',
        options: ['أ', 'ب', 'ج'],
        correctIndex: 0,
        optionImageUrls: [null, 'https://x/img.png', null],
        explanation: 'شرح',
        explanationImageUrl: 'https://x/expl.png',
      );
      final cloud = q.toCloudMap();
      expect(cloud['optionImageUrls'], [null, 'https://x/img.png', null]);
      expect(cloud.containsKey('explanationImageUrl'), isFalse,
          reason: 'صورة الشرح محلية فقط — مش في toCloudMap');
      expect(cloud.containsKey('explanation'), isFalse);
    });

    test('toCloudMap لا يضيف optionImageUrls لو كلها null', () {
      final q = ExamQuestion(
        id: 1,
        examId: 1,
        position: 0,
        type: ExamQuestionType.mcq,
        text: 'سؤال',
        options: ['أ', 'ب'],
        correctIndex: 0,
      );
      expect(q.toCloudMap().containsKey('optionImageUrls'), isFalse);
    });

    test('fromMap بعمود فاضي (سؤال قديم) يبني قائمة null بطول options', () {
      final q = ExamQuestion.fromMap({
        'id': 1,
        'exam_id': 1,
        'position': 0,
        'type': 'mcq',
        'text': 'سؤال',
        'options': '["أ","ب","ج"]',
        'correct_index': 0,
        'points': 1,
      });
      expect(q.optionImageUrls, [null, null, null]);
    });

    test('toMap/fromMap رحلة كاملة تحافظ على الصور', () {
      final q = ExamQuestion(
        id: 5,
        examId: 1,
        position: 0,
        type: ExamQuestionType.mcq,
        text: 'سؤال',
        options: ['أ', 'ب'],
        correctIndex: 0,
        optionImageUrls: ['u1', null],
        explanationImageUrl: 'eimg',
      );
      final back = ExamQuestion.fromMap(q.toMap());
      expect(back.optionImageUrls, ['u1', null]);
      expect(back.explanationImageUrl, 'eimg');
    });
  });
}
