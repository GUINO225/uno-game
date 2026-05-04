import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseGameService {
  SupabaseGameService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> createRoom({
    required String roomCode,
    required String creatorId,
    required String creatorPseudo,
    required String mode,
  }) async {
    final Map<String, dynamic> inserted = await _client
        .from('duel_games')
        .insert(<String, dynamic>{
          'id': roomCode,
          'room_code': roomCode,
          'creator_id': creatorId,
          'creator_pseudo': creatorPseudo,
          'status': 'waiting',
          'mode': mode,
        })
        .select()
        .single();

    return inserted['room_code'] as String;
  }

  Future<void> joinRoom({
    required String roomCode,
    required String opponentId,
    required String opponentPseudo,
  }) async {
    await _client.from('duel_games').update(<String, dynamic>{
      'opponent_id': opponentId,
      'opponent_pseudo': opponentPseudo,
      'status': 'playing',
    }).eq('id', roomCode).eq('status', 'waiting');
  }

  RealtimeChannel listenRoom({
    required String roomCode,
    required void Function(Map<String, dynamic> room) onRoomChanged,
  }) {
    final RealtimeChannel channel = _client
        .channel('duel_games:$roomCode')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'duel_games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomCode,
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
