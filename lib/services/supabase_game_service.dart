import 'dart:async';
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

  Future<Map<String, dynamic>> fetchRoom(String roomCode) {
    return _client.from('duel_games').select().eq('room_code', roomCode).single();
  }

  Stream<Map<String, dynamic>> watchRoom(String roomCode) {
    late final StreamController<Map<String, dynamic>> controller;
    RealtimeChannel? channel;
    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () async {
        try {
          controller.add(await fetchRoom(roomCode));
        } catch (_) {}
        channel = _client
            .channel('duel_games:watch:$roomCode')
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
                controller.add(Map<String, dynamic>.from(payload.newRecord));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  Future<void> pushAction({required String roomCode, required Map<String, dynamic> patch}) async {
    await _client.from('duel_games').update(patch).eq('room_code', roomCode);
  }

  Future<void> proposeStake({required String roomCode, required String proposedBy, required int amount}) async {
    try {
      await _client.rpc('propose_duel_stake', params: {'p_room_code': roomCode, 'p_proposed_by': proposedBy, 'p_amount': amount});
    } catch (_) {
      await _client.from('duel_games').update({'stake_amount': amount, 'stake_proposed_by': proposedBy, 'stake_status': 'pending', 'bet_flow_state': 'initialStakePendingResponse', 'stake_accepted_by': null, 'active_stake_credits': 0}).eq('room_code', roomCode);
    }
  }

  Future<void> respondToStake({required String roomCode, required String responderId, required bool accept, bool insufficientFunds = false}) async {
    if (!accept || insufficientFunds) {
      try {
        await _client.rpc('reject_duel_stake', params: {'p_room_code': roomCode, 'p_responder_id': responderId, 'p_insufficient_funds': insufficientFunds});
      } catch (_) {
        await _client.from('duel_games').update({'stake_status': insufficientFunds ? 'insufficientFunds' : 'declined', 'bet_flow_state': insufficientFunds ? 'awaitingFundsValidation' : 'initialStakeRejected'}).eq('room_code', roomCode);
      }
      return;
    }
    try {
      await _client.rpc('accept_duel_stake', params: {'p_room_code': roomCode, 'p_responder_id': responderId});
    } catch (_) {
      final room = await fetchRoom(roomCode);
      final int amount = (room['stake_amount'] as num?)?.toInt() ?? 0;
      await _client.from('duel_games').update({'stake_accepted_by': responderId, 'stake_status': 'accepted', 'bet_flow_state': 'readyToStart', 'active_stake_credits': amount, 'status': 'playing'}).eq('room_code', roomCode);
    }
  }

  Future<void> resolveStakeAfterRound({required String roomCode, required String winnerId}) async {
    try {
      await _client.rpc('resolve_duel_stake', params: {'p_room_code': roomCode, 'p_winner_id': winnerId});
    } catch (_) {
      await _client.from('duel_games').update({'stake_status': 'resolved', 'bet_flow_state': 'matchFinished', 'active_stake_credits': 0}).eq('room_code', roomCode);
    }
  }

  Stream<List<Map<String, dynamic>>> watchChatMessages(String roomCode) {
    return _client
        .from('duel_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('game_id', roomCode)
        .order('created_at')
        .map((rows) => rows.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  Future<void> pushChatMessage({required String roomCode, required String senderId, required String senderName, required String text}) async {
    await _client.from('duel_chat_messages').insert({'game_id': roomCode, 'sender_id': senderId, 'sender_name': senderName, 'text': text});
  }
}
