import 'package:supabase_flutter/supabase_flutter.dart';

/// 구독 해제 콜백. RN의 `subscribeTo*()`가 돌려주던 `() => void`에 대응.
typedef Unsubscribe = void Function();

/// postgres_changes 한 건. INSERT면 [newRecord], DELETE면 [oldRecord]가 채워진다.
typedef RealtimeChangeHandler = void Function(
  Map<String, dynamic> newRecord,
  Map<String, dynamic> oldRecord,
);

/// Supabase Realtime postgres_changes 구독 경계. 테스트에서 웹소켓 없이 이벤트를 흉내 낼 수 있도록 분리했다.
abstract class RealtimeGateway {
  Unsubscribe listen({
    required String channelName,
    required String table,
    required PostgresChangeEvent event,
    PostgresChangeFilter? filter,
    required RealtimeChangeHandler onChange,
  });
}

/// `supabase.channel(name).onPostgresChanges(...).subscribe()` 구현.
/// 서버는 RLS(messages/reactions select 정책)를 통과한 행만 보내준다.
class SupabaseRealtimeGateway implements RealtimeGateway {
  SupabaseRealtimeGateway(this._client);

  final SupabaseClient _client;

  @override
  Unsubscribe listen({
    required String channelName,
    required String table,
    required PostgresChangeEvent event,
    PostgresChangeFilter? filter,
    required RealtimeChangeHandler onChange,
  }) {
    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (payload) => onChange(payload.newRecord, payload.oldRecord),
        )
        .subscribe();
    return () {
      _client.removeChannel(channel);
    };
  }
}
