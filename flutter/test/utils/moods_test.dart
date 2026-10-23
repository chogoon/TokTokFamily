import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/models/mood.dart';
import 'package:family_toktok/utils/moods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('moods 상수', () {
    test('이모지 5종을 프로토타입과 동일한 순서로 정의한다', () {
      expect(moods.map((m) => m.emoji), ['😆', '🙂', '😐', '😢', '😠']);
      expect(moods.map((m) => m.label), ['신나', '좋아', '그냥', '슬퍼', '화나']);
    });
  });

  group('shouldNotifyParent', () {
    test('슬픔(😢)/화남(😠)이면 true', () {
      expect(shouldNotifyParent('😢'), isTrue);
      expect(shouldNotifyParent('😠'), isTrue);
    });

    for (final emoji in ['😆', '🙂', '😐', '']) {
      test('"$emoji"는 false', () {
        expect(shouldNotifyParent(emoji), isFalse);
      });
    }
  });

  group('canSeeNote', () {
    test('보호자는 누구의 이유든 볼 수 있다', () {
      expect(canSeeNote(MemberRole.parent, 'p1', 'k1'), isTrue);
      expect(canSeeNote(MemberRole.parent, 'p1', 'k2'), isTrue);
      expect(canSeeNote(MemberRole.parent, 'p1', 'p2'), isTrue);
    });

    test('아이 본인의 이유는 볼 수 있다', () {
      expect(canSeeNote(MemberRole.kid, 'k1', 'k1'), isTrue);
    });

    test('아이는 다른 형제의 이유를 볼 수 없다', () {
      expect(canSeeNote(MemberRole.kid, 'k1', 'k2'), isFalse);
    });

    test('아이는 보호자의 이유도 볼 수 없다', () {
      expect(canSeeNote(MemberRole.kid, 'k1', 'p1'), isFalse);
    });
  });

  group('formatMoodDate', () {
    test('로컬 날짜를 YYYY-MM-DD로 0 채움 포맷한다', () {
      expect(formatMoodDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(formatMoodDate(DateTime(2026, 10, 22, 23, 59)), '2026-10-22');
    });
  });

  group('dayOfWeekLabel', () {
    test('일요일부터 토요일까지 한글 요일을 반환한다', () {
      // 2026-10-18은 일요일
      final labels = [
        for (var d = 18; d <= 24; d++) dayOfWeekLabel(DateTime(2026, 10, d)),
      ];
      expect(labels, ['일', '월', '화', '수', '목', '금', '토']);
    });
  });

  group('buildWeeklyMoodDays', () {
    final today = DateTime(2026, 10, 22, 15, 30); // 목요일 오후

    test('오늘을 포함해 7일치 배열을 만든다', () {
      expect(buildWeeklyMoodDays('k1', const {}, today), hasLength(7));
    });

    test('날짜는 과거->오늘 오름차순이고 마지막 칸만 오늘이다', () {
      final result = buildWeeklyMoodDays('k1', const {}, today);
      expect(result.first.date, '2026-10-16');
      expect(result.last.date, '2026-10-22');
      expect(result.last.isToday, isTrue);
      expect(result.take(6).every((d) => !d.isToday), isTrue);
    });

    test("오늘 칸의 dayLabel은 '오늘'이고 나머지는 요일이다", () {
      final result = buildWeeklyMoodDays('k1', const {}, today);
      expect(
          result.map((d) => d.dayLabel), ['금', '토', '일', '월', '화', '수', '오늘']);
    });

    test('7일 범위 밖(8일 전, 내일) 기록은 포함하지 않는다', () {
      final result = buildWeeklyMoodDays(
        'k1',
        const {
          '2026-10-15': {'k1': (emoji: '😆', note: null)},
          '2026-10-23': {'k1': (emoji: '😠', note: null)},
        },
        today,
      );
      expect(result.every((d) => d.emoji == null), isTrue);
    });

    test('월 경계를 넘어도 날짜가 올바르다', () {
      final result = buildWeeklyMoodDays('k1', const {}, DateTime(2026, 11, 2));
      expect(result.first.date, '2026-10-27');
      expect(result.last.date, '2026-11-02');
    });

    test('해당 날짜/멤버의 기분과 이유를 채운다', () {
      final result = buildWeeklyMoodDays(
        'k1',
        const {
          '2026-10-20': {
            'k1': (emoji: '😆', note: '놀이터'),
            'k2': (emoji: '😐', note: null),
          },
          '2026-10-22': {'k1': (emoji: '😢', note: null)},
        },
        today,
      );
      final oct20 = result.firstWhere((d) => d.date == '2026-10-20');
      expect(oct20.emoji, '😆');
      expect(oct20.note, '놀이터');
      expect(result.last.emoji, '😢');
      expect(result.last.note, isNull);
    });

    test('다른 멤버(형제)의 기록은 섞이지 않는다', () {
      final result = buildWeeklyMoodDays(
        'k1',
        const {
          '2026-10-22': {'k2': (emoji: '😠', note: '비밀')},
        },
        today,
      );
      expect(result.last.emoji, isNull);
      expect(result.last.note, isNull);
    });
  });

  group('groupMoodsByDate', () {
    test('MoodEntry 목록을 날짜 → 멤버 → (emoji, note) 맵으로 묶는다', () {
      final map = groupMoodsByDate(const [
        MoodEntry(
            id: 'm1',
            memberId: 'k1',
            date: '2026-10-22',
            emoji: '🙂',
            note: '좋아'),
        MoodEntry(
            id: 'm2',
            memberId: 'k2',
            date: '2026-10-22',
            emoji: '😐',
            note: null),
      ]);
      expect(map['2026-10-22']!['k1'], (emoji: '🙂', note: '좋아'));
      expect(map['2026-10-22']!['k2'], (emoji: '😐', note: null));
    });
  });
}
