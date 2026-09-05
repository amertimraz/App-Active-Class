// spec 023 — يفرض إن toCloudMap() (المستند العام اللي الطالب بيقرأه
// أثناء الحل) يفضل بلا أي مفتاح تصحيح: لا correctIndex، لا points، ولا
// explanation. القيد ده جاي من spec 016 FR-034 وامتدّ في spec 023.
import 'package:active_class/models/exam_question_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toCloudMap لا يحتوي correctIndex / points / explanation', () {
    const q = ExamQuestion(
      id: 7,
      examId: 1,
      position: 0,
      type: ExamQuestionType.mcq,
      text: 'ما ناتج ٢ + ٢؟',
      options: ['٣', '٤', '٥'],
      correctIndex: 1,
      points: 3,
      imageUrl: 'https://example.com/q.png',
      explanation: 'لأن ٢ + ٢ = ٤ بالجمع',
    );

    final cloud = q.toCloudMap();

    expect(cloud.keys.toSet(),
        {'id', 'type', 'text', 'options', 'imageUrl'});
    expect(cloud.containsKey('correctIndex'), isFalse);
    expect(cloud.containsKey('correct_index'), isFalse);
    expect(cloud.containsKey('points'), isFalse);
    expect(cloud.containsKey('explanation'), isFalse);
    expect(cloud.toString().contains('لأن'), isFalse);
  });

  test('toCloudMap بدون صورة لا يضيف مفتاح imageUrl', () {
    const q = ExamQuestion(
      id: 3,
      examId: 1,
      position: 0,
      type: ExamQuestionType.trueFalse,
      text: 'السماء زرقاء',
      options: ['صح', 'خطأ'],
      correctIndex: 0,
      explanation: 'شرح',
    );
    expect(q.toCloudMap().keys.toSet(), {'id', 'type', 'text', 'options'});
  });
}
