// 기분 탭의 순수 로직(네트워크 없음). RN `frontend/lib/moods.ts` + `lib/formatDate.ts`에 대응.
import '../models/member.dart';
import '../models/mood.dart';

/// family-sns.html의 MOODS 배열(이모지 5종 + 라벨) 그대로.
const moods = <({String emoji, String label})>[
  (emoji: '😆', label: '신나'),
  (emoji: '🙂', label: '좋아'),
  (emoji: '😐', label: '그냥'),
  (emoji: '😢', label: '슬퍼'),
  (emoji: '😠', label: '화나'),
];

const _sadOrAngryEmojis = {'😢', '😠'};

const _dayOfWeekLabels = ['일', '월', '화', '수', '목', '금', '토'];

/// 날짜별 → 멤버별 기분 맵의 한 칸.
typedef MoodCell = ({String emoji, String? note});

/// 아이가 슬프거나 화난 기분을 고르면 보호자에게(본인 1:1방으로) 알려야 한다.
bool shouldNotifyParent(String emoji) => _sadOrAngryEmojis.contains(emoji);

/// 기분 이유(note)는 작성한 본인이거나 보호자만 볼 수 있다. 다른 형제는 볼 수 없다.
bool canSeeNote(
  MemberRole viewerRole,
  String viewerMemberId,
  String moodOwnerMemberId,
) =>
    viewerRole == MemberRole.parent || viewerMemberId == moodOwnerMemberId;

/// 로컬 날짜를 `YYYY-MM-DD`로 만든다 (moods.date 컬럼 형식).
String formatMoodDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 날짜의 요일 레이블(일~토). Dart weekday는 월=1..일=7이다.
String dayOfWeekLabel(DateTime date) => _dayOfWeekLabels[date.weekday % 7];

/// [today]를 포함한 최근 7일을 날짜 오름차순(과거 → 오늘)으로 만든다.
/// 오늘 칸은 dayLabel이 "오늘"이고, 그 외는 요일(일~토)로 표시한다.
/// [targetMemberId]의 기록만 채우므로 다른 멤버(형제)의 기록은 섞이지 않는다.
List<WeeklyMoodDay> buildWeeklyMoodDays(
  String targetMemberId,
  Map<String, Map<String, MoodCell>> moodsByDate,
  DateTime today,
) {
  return [
    for (var i = 6; i >= 0; i--)
      () {
        // DateTime 생성자로 일 단위 이동 — DST에서도 Duration 빼기보다 안전하다.
        final date = DateTime(today.year, today.month, today.day - i);
        final key = formatMoodDate(date);
        final entry = moodsByDate[key]?[targetMemberId];
        final isToday = i == 0;
        return WeeklyMoodDay(
          date: key,
          dayLabel: isToday ? '오늘' : dayOfWeekLabel(date),
          emoji: entry?.emoji,
          note: entry?.note,
          isToday: isToday,
        );
      }(),
  ];
}

/// [MoodEntry] 목록을 `buildWeeklyMoodDays`가 쓰는 날짜 → 멤버 → 칸 맵으로 묶는다.
Map<String, Map<String, MoodCell>> groupMoodsByDate(List<MoodEntry> entries) {
  final result = <String, Map<String, MoodCell>>{};
  for (final e in entries) {
    (result[e.date] ??= {})[e.memberId] = (emoji: e.emoji, note: e.note);
  }
  return result;
}
