import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';
import '../models/mood.dart';
import '../utils/moods.dart';

/// 로그인한 구성원 (없으면 null). main.dart에서 AuthController.member로 연결한다.
typedef MoodsCurrentMemberProvider = Future<Member?> Function();

/// 기분(이모지/이유) 데이터 경계. 화면 테스트에서 fake로 대체한다.
/// RN `frontend/services/moods.ts`에 대응. 순수 로직은 `utils/moods.dart`에 있다.
abstract class MoodsService {
  /// 오늘(로컬 날짜) 가족 전체 기분. note는 mood_notes RLS가 돌려준 것만 채워진다.
  Future<List<FamilyTodayMood>> fetchTodayMoods();

  /// [memberId]의 최근 7일(오늘 포함) 기분 기록.
  Future<List<MoodEntry>> fetchMyWeeklyMoods(String memberId);

  /// 로그인한 member 명의로 오늘 기분을 저장(재선택 시 upsert)한다.
  /// 아이가 슬픔/화남을 골라 본인 1:1방으로 보호자에게 알림을 보냈으면 true.
  Future<bool> saveMood(String emoji, {String? note});
}

/// Supabase 직접 호출 (ADR-004 "일상 데이터" 경로). 범위 제한은 RLS에 맡긴다 —
/// family_id/kid_member_id로 클라이언트가 재필터링하지 않는다.
///
/// 1:1방 알림은 `rooms_service.dart`를 import하지 않고 이 파일 안에서 직접 쿼리한다
/// (RN `services/moods.ts`와 같은 이유: 다른 작업이 rooms 서비스를 동시에 고칠 수 있어 결합을 피한다).
class SupabaseMoodsService implements MoodsService {
  SupabaseMoodsService(
    this._client, {
    required MoodsCurrentMemberProvider currentMember,
    DateTime Function()? now,
  })  : _currentMember = currentMember,
        _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final MoodsCurrentMemberProvider _currentMember;

  /// 로컬 시각. moods.date는 로컬 날짜 기준이다 (UTC로 바꾸면 한국 아침에 전날로 저장된다).
  final DateTime Function() _now;

  static const _moodColumns = 'id, member_id, date, emoji';

  @override
  Future<List<FamilyTodayMood>> fetchTodayMoods() async {
    final today = formatMoodDate(_now());
    final rows =
        await _client.from('moods').select(_moodColumns).eq('date', today);
    if (rows.isEmpty) return const [];

    final notes = await _fetchNotes(rows);
    return [
      for (final row in rows)
        FamilyTodayMood(
          memberId: row['member_id'] as String,
          date: row['date'] as String,
          emoji: row['emoji'] as String,
          note: notes[row['id']],
        ),
    ];
  }

  @override
  Future<List<MoodEntry>> fetchMyWeeklyMoods(String memberId) async {
    final now = _now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final rows = await _client
        .from('moods')
        .select(_moodColumns)
        .eq('member_id', memberId)
        .gte('date', formatMoodDate(start))
        .lte('date', formatMoodDate(now));
    if (rows.isEmpty) return const [];

    final notes = await _fetchNotes(rows);
    return [
      for (final row in rows)
        MoodEntry(
          id: row['id'] as String,
          memberId: row['member_id'] as String,
          date: row['date'] as String,
          emoji: row['emoji'] as String,
          note: notes[row['id']],
        ),
    ];
  }

  /// mood_id → note. RLS(mood_notes_select)가 본인/보호자가 아니면 행을 돌려주지 않으므로
  /// 빠진 mood는 note 없음(null)으로 처리한다 — 클라이언트가 다시 가리지 않는다.
  Future<Map<String, String>> _fetchNotes(
      List<Map<String, dynamic>> moodRows) async {
    final rows = await _client
        .from('mood_notes')
        .select('mood_id, note')
        .inFilter('mood_id', [for (final r in moodRows) r['id'] as String]);
    return {
      for (final row in rows) row['mood_id'] as String: row['note'] as String,
    };
  }

  @override
  Future<bool> saveMood(String emoji, {String? note}) async {
    final me = await _currentMember();
    if (me == null) throw StateError('로그인이 필요해요');

    final moodRow = await _client
        .from('moods')
        .upsert(
          {
            'member_id': me.id,
            'family_id': me.familyId,
            'date': formatMoodDate(_now()),
            'emoji': emoji,
          },
          onConflict: 'member_id,date',
        )
        .select('id')
        .single();

    final trimmedNote = note?.trim();
    final hasNote = trimmedNote != null && trimmedNote.isNotEmpty;
    if (hasNote) {
      await _client.from('mood_notes').upsert(
        {'mood_id': moodRow['id'] as String, 'note': trimmedNote},
        onConflict: 'mood_id',
      );
    }

    if (me.role == MemberRole.kid && shouldNotifyParent(emoji)) {
      return _notifyParentOfMood(me.id, emoji, hasNote ? trimmedNote : null);
    }
    return false;
  }

  /// 아이 본인의 1:1방에 기분 알림 텍스트 메시지를 보낸다. **kid 역할일 때만** 호출한다.
  /// rooms를 `type='kid'`로만 select하면 RLS(rooms_select)가 로그인한 아이 본인의 방만 돌려준다.
  Future<bool> _notifyParentOfMood(
      String memberId, String emoji, String? note) async {
    final rooms = await _client.from('rooms').select('id').eq('type', 'kid');
    if (rooms.isEmpty) return false;

    await _client.from('messages').insert({
      'room_id': rooms.first['id'] as String,
      'sender_id': memberId,
      'kind': 'text',
      'body': note == null ? '오늘 기분: $emoji' : '오늘 기분: $emoji — $note',
    });
    return true;
  }
}
