import 'package:flutter/foundation.dart';
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
    final Map<String, dynamic> updated = await _client
        .from('duel_games')
        .update(<String, dynamic>{
          'opponent_id': opponentId,
          'opponent_pseudo': opponentPseudo,
          'status': 'playing',
        })
        .eq('room_code', roomCode)
        .eq('status', 'waiting')
        .select()
        .single();

    debugPrint(
      '[SUPABASE_GAME] joinRoom updated room=${updated['room_code']} status=${updated['status']}',
    );
  }

  RealtimeChannel listenRoom({
    required String roomCode,
    required void Function(Map<String, dynamic> room) onRoomChanged,
  }) {
    Future<void>(() async {
      try {
        debugPrint('[SUPABASE_GAME] listenRoom initial fetch start code=$roomCode');

        final Map<String, dynamic> room = await _client
            .from('duel_games')
            .select()
            .eq('room_code', roomCode)
            .single();

        debugPrint('[SUPABASE_GAME] listenRoom initial fetch success code=$roomCode');
        debugPrint('[SUPABASE_GAME] listenRoom initial creator_id=${room['creator_id']}');
        debugPrint('[SUPABASE_GAME] listenRoom initial opponent_id=${room['opponent_id']}');
        debugPrint('[SUPABASE_GAME] listenRoom initial status=${room['status']}');
        onRoomChanged(room);
      } catch (e) {
        debugPrint('[SUPABASE_GAME] listenRoom initial fetch failed: $e');
      }
    });

    final RealtimeChannel channel = _client
        .channel('duel_games:$roomCode')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'duel_games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_code',
            value: roomCode,
          ),
          callback: (PostgresChangePayload payload) {
            debugPrint('[SUPABASE_GAME] listenRoom realtime event received code=$roomCode');
            final dynamic row = payload.newRecord;
            if (row is Map) {
              final Map<String, dynamic> room = Map<String, dynamic>.from(row);
              debugPrint('[SUPABASE_GAME] listenRoom realtime creator_id=${room['creator_id']}');
              debugPrint('[SUPABASE_GAME] listenRoom realtime opponent_id=${room['opponent_id']}');
              debugPrint('[SUPABASE_GAME] listenRoom realtime status=${room['status']}');
              onRoomChanged(room);
            }
          },
        )
        .subscribe();

    return channel;
  }
}
