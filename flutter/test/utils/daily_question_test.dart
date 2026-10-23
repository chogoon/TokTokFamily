import 'package:family_toktok/utils/daily_question.dart';
import 'package:flutter_test/flutter_test.dart';

// RN frontend/lib/dailyQuestion.test.ts 포팅.
void main() {
  test('질문은 7개다', () {
    expect(dailyQuestions, hasLength(7));
    expect(dailyQuestions.first, '오늘 학교에서 가장 재밌었던 일은?');
  });

  test('같은 날짜를 넣으면 같은 질문을 반환한다', () {
    expect(pickDailyQuestion(DateTime(2026, 10, 22)),
        pickDailyQuestion(DateTime(2026, 10, 22, 23, 59)));
  });

  test('날짜의 일(day) 값으로 로테이션한다', () {
    expect(pickDailyQuestion(DateTime(2026, 1, 1)),
        dailyQuestions[1 % dailyQuestions.length]);
    expect(pickDailyQuestion(DateTime(2026, 1, 2)),
        dailyQuestions[2 % dailyQuestions.length]);
    expect(pickDailyQuestion(DateTime(2026, 1, 7)), dailyQuestions[0]);
  });

  test('어떤 날짜를 넣어도 배열 범위 안의 질문을 반환한다', () {
    for (var day = 1; day <= 31; day++) {
      expect(
          dailyQuestions, contains(pickDailyQuestion(DateTime(2026, 1, day))));
    }
  });
}
