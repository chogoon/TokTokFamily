import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';
import '../models/praise.dart';
import '../utils/praises.dart';
import 'members_service.dart';

/// 칭찬판 데이터 경계. 화면 테스트에서 fake로 대체한다.
/// RN `frontend/services/praises.ts`에 대응.
abstract class PraisesService {
  /// 해당 아이의 진행 중(active) 칭찬판 (없으면 null). RLS가 본인/보호자만 돌려준다.
  Future<PraiseBoard?> fetchActiveBoard(String kidMemberId);

  /// 해당 칭찬판의 기록을 최신순으로, 준 사람 이름을 채워 돌려준다.
  Future<List<PraiseEntry>> fetchPraises(String boardId);

  /// 보호자가 칭찬 1건을 추가하고 그 아이의 1:1방에 알린다.
  Future<void> addPraise(String boardId, String text);

  /// 보호자가 여러 아이에게 같은 칭찬을 추가하고 가족방에 한 건만 알린다.
  Future<void> addPraiseToAllKids(List<String> kidMemberIds, String text);

  /// 보상 알림 → 기존 판 done → 같은 목표/개수로 새 판 시작.
  Future<void> claimReward(PraiseBoard board);

  /// 칭찬판 목표 텍스트 수정 (보호자만 — RLS가 강제).
  Future<void> saveGoal(String boardId, String goalText);
}

/// Supabase 직접 호출 (ADR-004 "일상 데이터" 경로). 접근 범위는 RLS가 전적으로 제한한다
/// (praise_boards: 아이는 본인 것만 / 보호자는 전체, 수정은 보호자만). family_id 재필터링 없음.
///
/// CRITICAL: 1:1방/가족방 알림은 `rooms_service.dart`를 import하지 않고 이 파일 안에서 직접
/// 쿼리한다 (RN `services/praises.ts`와 같은 이유 — 대화 서비스와의 결합을 피해 동시 작업 충돌을 줄임).
class SupabasePraisesService implements PraisesService {
  SupabasePraisesService(
    this._client, {
    required MembersService members,
    required Future<Member?> Function() currentMember,
  })  : _members = members,
        _currentMember = currentMember;

  final SupabaseClient _client;
  final MembersService _members;
  final Future<Member?> Function() _currentMember;

  static const _boardColumns =
      'id, kid_member_id, family_id, goal_text, target_count, status';

  Future<Member> _requireMember() async {
    final me = await _currentMember();
    if (me == null) throw StateError('로그인이 필요해요');
    return me;
  }

  Future<Map<String, String>> _memberNames() async {
    final members = await _members.fetchFamilyMembers();
    return {for (final m in members) m.id: m.name};
  }

  @override
  Future<PraiseBoard?> fetchActiveBoard(String kidMemberId) async {
    final row = await _client
        .from('praise_boards')
        .select(_boardColumns)
        .eq('kid_member_id', kidMemberId)
        .eq('status', 'active')
        .maybeSingle();
    return row == null ? null : PraiseBoard.fromRow(row);
  }

  @override
  Future<List<PraiseEntry>> fetchPraises(String boardId) async {
    final rows = await _client
        .from('praises')
        .select('id, board_id, giver_id, text, created_at')
        .eq('board_id', boardId);
    if (rows.isEmpty) return const [];

    final names = await _memberNames();
    return sortPraisesByNewest([
      for (final row in rows)
        PraiseEntry.fromRow(row, giverName: names[row['giver_id']] ?? '가족'),
    ]);
  }

  /// 그 아이의 1:1방에 system 메시지를 보낸다. 방이 없으면 조용히 무시한다.
  Future<void> _notifyKidRoom(
      String kidMemberId, String body, String senderId) async {
    final room = await _client
        .from('rooms')
        .select('id')
        .eq('type', 'kid')
        .eq('kid_member_id', kidMemberId)
        .maybeSingle();
    if (room == null) return;
    await _insertSystemMessage(room['id'] as String, body, senderId);
  }

  /// 가족방(type='family')에 system 메시지를 보낸다. 가족방은 가족당 하나이고 RLS가 범위를 제한한다.
  Future<void> _notifyFamilyRoom(String body, String senderId) async {
    final room = await _client
        .from('rooms')
        .select('id')
        .eq('type', 'family')
        .maybeSingle();
    if (room == null) return;
    await _insertSystemMessage(room['id'] as String, body, senderId);
  }

  Future<void> _insertSystemMessage(
      String roomId, String body, String senderId) async {
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'kind': 'system',
      'body': body,
    });
  }

  @override
  Future<void> addPraise(String boardId, String text) async {
    final me = await _requireMember();

    final board = await _client
        .from('praise_boards')
        .select('kid_member_id')
        .eq('id', boardId)
        .maybeSingle();
    if (board == null) throw StateError('칭찬판을 찾을 수 없어요');

    await _client.from('praises').insert({
      'board_id': boardId,
      'giver_id': me.id,
      'text': text,
    });

    await _notifyKidRoom(
        board['kid_member_id'] as String, '⭐ 칭찬 스티커! "$text"', me.id);
  }

  @override
  Future<void> addPraiseToAllKids(
      List<String> kidMemberIds, String text) async {
    final me = await _requireMember();
    final names = await _memberNames();

    for (final kidMemberId in kidMemberIds) {
      final board = await fetchActiveBoard(kidMemberId);
      if (board == null) continue;
      await _client.from('praises').insert({
        'board_id': board.id,
        'giver_id': me.id,
        'text': text,
      });
    }

    final joined = kidMemberIds.map((id) => names[id] ?? '가족').join(', ');
    await _notifyFamilyRoom('⭐ $joined 모두 칭찬 스티커! "$text"', me.id);
  }

  @override
  Future<void> claimReward(PraiseBoard board) async {
    final me = await _requireMember();

    await _notifyKidRoom(
      board.kidMemberId,
      '🎁 약속한 "${board.goalText}" 지킬게! 새 칭찬판 시작이야',
      me.id,
    );

    await _client
        .from('praise_boards')
        .update({'status': 'done'}).eq('id', board.id);

    await _client.from('praise_boards').insert({
      'kid_member_id': board.kidMemberId,
      'family_id': board.familyId,
      'goal_text': board.goalText,
      'target_count': board.targetCount,
    });
  }

  @override
  Future<void> saveGoal(String boardId, String goalText) async {
    await _client
        .from('praise_boards')
        .update({'goal_text': goalText}).eq('id', boardId);
  }
}
