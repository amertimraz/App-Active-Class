import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/services/online_game_service.dart';
import 'package:active_class/views/exams/games/game_leaderboard_page.dart';
import 'package:active_class/views/exams/games/online_game_editor_page.dart';

GameQuestion q(String text, {int correct = 0, List<String>? options}) =>
    GameQuestion(
        text: text, options: options ?? ['أ', 'ب', 'ج'], correctIndex: correct);

GameScore s(String code, int score, int timeMs) => GameScore(
    code: code, name: code, score: score, correct: 1, total: 3, timeMs: timeMs);

void main() {
  group('gameQuestionPoints', () {
    test('الغلط = صفر مهما كانت السرعة', () {
      for (final t in OnlineGameType.values) {
        expect(
            gameQuestionPoints(type: t, correct: false, remainingFraction: 1),
            0);
      }
    });
    test('سباق الأسئلة: من 500 (آخر ثانية) لـ1000 (فوري)', () {
      expect(
          gameQuestionPoints(
              type: OnlineGameType.race, correct: true, remainingFraction: 0),
          500);
      expect(
          gameQuestionPoints(
              type: OnlineGameType.race, correct: true, remainingFraction: 1),
          1000);
      expect(
          gameQuestionPoints(
              type: OnlineGameType.race, correct: true, remainingFraction: .5),
          750);
    });
    test('صح ولا غلط: من 100 لـ150', () {
      expect(
          gameQuestionPoints(
              type: OnlineGameType.trueFalse,
              correct: true,
              remainingFraction: 0),
          100);
      expect(
          gameQuestionPoints(
              type: OnlineGameType.trueFalse,
              correct: true,
              remainingFraction: 1),
          150);
    });
    test('نسبة الوقت برا 0..1 بتتقصّ', () {
      expect(
          gameQuestionPoints(
              type: OnlineGameType.race, correct: true, remainingFraction: 2),
          1000);
      expect(
          gameQuestionPoints(
              type: OnlineGameType.race, correct: true, remainingFraction: -1),
          500);
    });
  });

  group('GameScore.ranked', () {
    test('النقاط تنازليًا، والأسرع أولًا عند التساوي', () {
      final r = GameScore.ranked([
        s('A', 500, 9000),
        s('B', 900, 20000),
        s('C', 500, 4000),
      ]);
      expect(r.map((e) => e.code).toList(), ['B', 'C', 'A']);
    });
  });

  group('OnlineGame cloud', () {
    test('toCloudMap/fromCloudMap بيحافظوا على السؤال والإجابة والصور', () {
      const original = GameQuestion(
        text: 'س؟',
        options: ['x', 'y'],
        correctIndex: 1,
        imageUrl: 'http://i/1.png',
        explanation: 'شرح',
        optionImageUrls: [null, 'http://i/o.png'],
      );
      final back = GameQuestion.fromCloudMap(original.toCloudMap());
      expect(back.text, 'س؟');
      expect(back.correctIndex, 1);
      expect(back.imageUrl, 'http://i/1.png');
      expect(back.explanation, 'شرح');
      expect(back.optionImageUrls, [null, 'http://i/o.png']);
    });

    test('المحتوى المنشور بيحمل النوع وعدد الأسئلة والمجموعات', () {
      final m = OnlineGame.cloudContent(
        title: 'مراجعة',
        type: OnlineGameType.trueFalse,
        secondsPerQuestion: 10,
        allowedGroupNames: ['أ'],
        questions: [q('1'), q('2')],
      );
      expect(m['gameType'], 'true_false');
      expect(m['questionCount'], 2);
      expect(m['allowedGroupNames'], ['أ']);
      final game = OnlineGame.fromCloud('g1', {...m, 'status': 'closed'});
      expect(game.type, OnlineGameType.trueFalse);
      expect(game.open, isFalse);
      expect(game.questions.length, 2);
    });

    test('نوع مجهول أو ناقص = سباق، وغياب status = مفتوحة', () {
      final game = OnlineGame.fromCloud('g', {'title': 't'});
      expect(game.type, OnlineGameType.race);
      expect(game.open, isTrue);
      expect(game.secondsPerQuestion, OnlineGameType.race.defaultSeconds);
    });
  });

  group('mergeGameQuestions', () {
    test('بيتجاهل المكرّر وغير الصالح', () {
      final out = mergeGameQuestions([
        q('أ')
      ], [
        q('أ'), // مكرّر
        q('ب'),
        const GameQuestion(text: '', options: ['x', 'y'], correctIndex: 0),
        q('ج', correct: 9), // فهرس غلط
      ]);
      expect(out.map((e) => e.text).toList(), ['أ', 'ب']);
    });

    test('بيوقف عند الحد الأقصى', () {
      final many = [for (var i = 0; i < 80; i++) q('س$i')];
      expect(mergeGameQuestions([], many).length, kGameMaxQuestions);
    });
  });

  test('رابط اللعبة', () {
    expect(OnlineGameService.linkFor('abc', 'g1'),
        'active-class.online/game/?s=abc&g=g1');
  });

  test('نص مشاركة الترتيب', () {
    final text = gameLeaderboardShareText(
        'مراجعة', GameScore.ranked([s('A', 100, 1), s('B', 300, 1)]));
    expect(text.split('\n'), [
      '🏆 ترتيب لعبة «مراجعة»',
      '🥇 B — 300 نقطة',
      '🥈 A — 100 نقطة',
    ]);
  });
}
