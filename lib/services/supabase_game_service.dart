import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseGameService {
  SupabaseGameService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> createRoom({required String hostUserId}) async {
    final Map<String, dynamic> inserted = await _client
        .from('duel_games')
        .insert(<String, dynamic>{
          'host_user_id': hostUserId,
          'status': 'waiting',
        })
        .select()
        .single();

    return inserted['id'] as String;
  }

  Future<void> joinRoom({required String roomId, required String guestUserId}) async {
    await _client.from('duel_games').update(<String, dynamic>{
      'guest_user_id': guestUserId,
      'status': 'playing',
    }).eq('id', roomId);
  }

  RealtimeChannel listenRoom({
    required String roomId,
    required void Function(Map<String, dynamic> room) onRoomChanged,
  }) {
    final RealtimeChannel channel = _client
        .channel('duel_games:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'duel_games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (PostgresChangePayload payload) {
            final dynamic row = payload.newRecord;
            if (row is Map<String, dynamic>) {
              onRoomChanged(row);
            }
          },
        )
        .subscribe();

    return channel;
  }
}
