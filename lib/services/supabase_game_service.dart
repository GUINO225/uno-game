import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> applyGameAction(
  Map<String, dynamic> gameState,
  Map<String, dynamic> action,
) {
  final Map<String, dynamic> next = Map<String, dynamic>.from(gameState);
  final List<String> players = List<String>.from(next['players'] as List? ?? const <String>[]);
  final Map<String, dynamic> hands = Map<String, dynamic>.from(next['hands'] as Map? ?? <String, dynamic>{});
  final List<String> drawPile = List<String>.from(next['drawPile'] as List? ?? const <String>[]);
  final List<String> discardPile = List<String>.from(next['discardPile'] as List? ?? const <String>[]);
  final String actorId = (action['actorId'] ?? action['playerId'] ?? action['by'] ?? '').toString();
  final String type = (action['type'] ?? '').toString();
  int pendingDrawCount = (next['pendingDrawCount'] as num?)?.toInt() ?? 0;
  String? requiredSuit = next['requiredSuit'] as String?;
  String currentTurn = (next['currentTurn'] ?? '').toString();
  String? winnerId = next['winnerId'] as String?;

  String nextPlayer({bool extraTurn = false}) {
    if (players.length < 2 || extraTurn) return actorId;
    final int idx = players.indexOf(actorId);
    if (idx < 0) return players.first;
    return players[(idx + 1) % players.length];
  }

  if (type == 'playCard') {
    final String cardId = (action['cardId'] ?? (action['payload'] as Map?)?['cardId'] ?? '').toString();
    final List<String> before = List<String>.from(hands[actorId] as List? ?? const <String>[]);
    debugPrint('[GAME_LOGIC] playCard before hand=$before');
    bool removed = false;
    final int idx = before.indexOf(cardId);
    if (idx >= 0) {
      before.removeAt(idx);
      removed = true;
    }
    hands[actorId] = before;
    debugPrint('[GAME_LOGIC] playCard removed=$removed after hand=$before');
    discardPile.add(cardId);
    next['topDiscard'] = cardId;
    debugPrint('[GAME_LOGIC] discardTop=$cardId');
    requiredSuit = null;
    final String rank = cardId.replaceAll(RegExp(r'[♥♠♦♣]'), '');
    if (rank == '2') pendingDrawCount += 2;
    if (rank == 'JK') pendingDrawCount += 8;
    if (rank == '8') requiredSuit = (action['chosenSuit'] ?? (action['payload'] as Map?)?['chosenSuit'])?.toString();
    final bool extraTurn = rank == '10' || rank == 'J';
    currentTurn = nextPlayer(extraTurn: extraTurn);
    if (before.isEmpty) winnerId = actorId;
    debugPrint('[GAME_LOGIC] nextTurn=$currentTurn');
  } else if (type == 'drawCard') {
    if (drawPile.isEmpty && discardPile.length > 1) {
      final String top = discardPile.removeLast();
      drawPile.addAll(discardPile);
      discardPile
        ..clear()
        ..add(top);
      drawPile.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
    }
    if (drawPile.isNotEmpty) {
      final String drawn = drawPile.removeLast();
      final List<String> hand = List<String>.from(hands[actorId] as List? ?? const <String>[])..add(drawn);
      hands[actorId] = hand;
      if (pendingDrawCount > 0) pendingDrawCount = (pendingDrawCount - 1).clamp(0, 999);
      if (pendingDrawCount == 0) currentTurn = nextPlayer();
    }
  } else if (type == 'passTurn') {
    currentTurn = nextPlayer();
  } else if (type == 'chooseSuit') {
    requiredSuit = (action['chosenSuit'] ?? (action['payload'] as Map?)?['chosenSuit'])?.toString();
    currentTurn = nextPlayer();
  }

  next['hands'] = hands;
  next['drawPile'] = drawPile;
  next['discardPile'] = discardPile;
  next['currentTurn'] = currentTurn;
  next['requiredSuit'] = requiredSuit;
  next['pendingDrawCount'] = pendingDrawCount;
  next['winnerId'] = winnerId;
  next['lastAction'] = action;
  next['revision'] = ((next['revision'] as num?)?.toInt() ?? 0) + 1;
  debugPrint('[GAME_LOGIC] revision=${next['revision']}');
  return next;
}

class SupabaseGameService {
  SupabaseGameService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Map<String, dynamic> _buildInitialDuelState({
    required String roomCode,
    required String creatorId,
    required String opponentId,
  }) {
    final List<String> suits = <String>['♥', '♠', '♦', '♣'];
    final List<String> ranks = <String>['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    final Random random = Random(roomCode.hashCode);
    final List<String> deck = <String>[
      for (final String suit in suits)
        for (final String rank in ranks) '$rank$suit',
      'JK♦',
      'JK♣',
    ]..shuffle(random);

    final List<String> player1Hand = <String>[];
    final List<String> player2Hand = <String>[];
    for (int i = 0; i < 7; i++) {
      player1Hand.add(deck.removeLast());
      player2Hand.add(deck.removeLast());
    }

    String top = deck.removeLast();
    while (top.startsWith('JK') || top.startsWith('8')) {
      deck.insert(0, top);
      top = deck.removeLast();
    }

    return <String, dynamic>{
      'player1Hand': player1Hand,
      'player2Hand': player2Hand,
      'drawPile': deck,
      'discardPile': <String>[top],
      'topDiscard': top,
      'deckInitialized': true,
      'revision': 1,
      'round': 1,
      'hands': <String, dynamic>{'player1': player1Hand, 'player2': player2Hand},
      'player1CardCount': player1Hand.length,
      'player2CardCount': player2Hand.length,
      'currentTurn': creatorId,
      'pendingDrawCount': 0,
      'forcedDrawInitial': 0,
      'requiredSuit': null,
      'requiredColorAfterJoker': null,
      'aceColorRequired': false,
      'players': <String>[creatorId, opponentId],
    };
  }

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
    debugPrint('[DUEL_SIMPLE] create room row=$inserted');

    return inserted['room_code'] as String;
  }

  Future<void> joinRoom({
    required String roomCode,
    required String opponentId,
    required String opponentPseudo,
  }) async {
    final Map<String, dynamic> room = await _client
        .from('duel_games')
        .select('mode')
        .eq('room_code', roomCode)
        .single();

    final String updatedRoomMode = (room['mode'] ?? 'duel').toString();
    final bool requiresBetting = updatedRoomMode == 'duel_pari';
    Map<String, dynamic>? initialDuelState;
    if (!requiresBetting) {
      final Map<String, dynamic> fullRoom = await _client
          .from('duel_games')
          .select('creator_id')
          .eq('room_code', roomCode)
          .single();
      final String creatorId = (fullRoom['creator_id'] ?? '').toString();
      debugPrint('[DUEL_SIMPLE] init board start');
      initialDuelState = _buildInitialDuelState(roomCode: roomCode, creatorId: creatorId, opponentId: opponentId);
    }

    final Map<String, dynamic> updated = await _client
        .from('duel_games')
        .update(<String, dynamic>{
          'opponent_id': opponentId,
          'opponent_pseudo': opponentPseudo,
          'status': requiresBetting ? 'betting' : 'round',
          if (!requiresBetting) 'current_turn': initialDuelState?['currentTurn'],
          if (!requiresBetting) 'game_state': initialDuelState,
          if (!requiresBetting) 'revision': 1,
          if (requiresBetting) 'stake_status': 'pending',
          if (requiresBetting) 'bet_flow_state': 'initialStakeProposed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('room_code', roomCode)
        .eq('status', 'waiting')
        .select()
        .single();
    debugPrint('[DUEL_SIMPLE] join room row=$updated');
    if (!requiresBetting) {
      debugPrint('[DUEL_SIMPLE] init board success');
    }

    debugPrint(
      '[SUPABASE_GAME] joinRoom updated room=${updated['room_code']} status=${updated['status']} mode=$updatedRoomMode bet_flow_state=${updated['bet_flow_state']}',
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
        debugPrint('[REALTIME] event received room=$roomCode source=initial status=${room['status']} mode=${room['mode']} creator_id=${room['creator_id']} opponent_id=${room['opponent_id']} stake_status=${room['stake_status']} bet_flow_state=${room['bet_flow_state']} active_stake_credits=${room['active_stake_credits']}');
        debugPrint('[GAME_FLOW] status=${room['status']} stakeStatus=${room['stake_status']} betFlowState=${room['bet_flow_state']} creator=${room['creator_id']} opponent=${room['opponent_id']} stake=${room['stake_amount']} proposedBy=${room['stake_proposed_by']} acceptedBy=${room['stake_accepted_by']} activeStake=${room['active_stake_credits']}');
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
            debugPrint('[REALTIME] event received room=$roomCode source=realtime');
            final dynamic row = payload.newRecord;
            if (row is Map) {
              final Map<String, dynamic> room = Map<String, dynamic>.from(row);
              debugPrint('[SUPABASE_GAME] listenRoom realtime creator_id=${room['creator_id']}');
              debugPrint('[SUPABASE_GAME] listenRoom realtime opponent_id=${room['opponent_id']}');
              debugPrint('[REALTIME] event received room=$roomCode status=${room['status']} mode=${room['mode']} creator_id=${room['creator_id']} opponent_id=${room['opponent_id']} stake_status=${room['stake_status']} bet_flow_state=${room['bet_flow_state']} active_stake_credits=${room['active_stake_credits']}');
              debugPrint('[GAME_FLOW] status=${room['status']} stakeStatus=${room['stake_status']} betFlowState=${room['bet_flow_state']} creator=${room['creator_id']} opponent=${room['opponent_id']} stake=${room['stake_amount']} proposedBy=${room['stake_proposed_by']} acceptedBy=${room['stake_accepted_by']} activeStake=${room['active_stake_credits']}');
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
                final Map<String, dynamic> room = Map<String, dynamic>.from(payload.newRecord);
                debugPrint('[REALTIME] event received revision=${room['revision']} room=$roomCode source=watchSession status=${room['status']} mode=${room['mode']} creator_id=${room['creator_id']} opponent_id=${room['opponent_id']} stake_status=${room['stake_status']} bet_flow_state=${room['bet_flow_state']} active_stake_credits=${room['active_stake_credits']}');
                debugPrint('[GAME_STATE] revision=${room['revision']} currentTurn=${room['current_turn'] ?? (room['game_state'] is Map ? (room['game_state'] as Map)['currentTurn'] : null)}');
                debugPrint('[GAME_FLOW] status=${room['status']} stakeStatus=${room['stake_status']} betFlowState=${room['bet_flow_state']} creator=${room['creator_id']} opponent=${room['opponent_id']} stake=${room['stake_amount']} proposedBy=${room['stake_proposed_by']} acceptedBy=${room['stake_accepted_by']} activeStake=${room['active_stake_credits']}');
                controller.add(room);
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
    debugPrint('[ACTION] push start room=$roomCode');
    final Map<String, dynamic> room = await fetchRoom(roomCode);
    final int currentRevision = (room['revision'] as num?)?.toInt() ?? 0;
    debugPrint('[ACTION_PUSH] oldRevision=$currentRevision');
    final Map<String, dynamic> oldState = Map<String, dynamic>.from(
      room['game_state'] as Map? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> action = Map<String, dynamic>.from(
      patch['last_action'] as Map? ?? oldState['lastAction'] as Map? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> gameState = applyGameAction(oldState, action);

    final Map<String, dynamic> updatePayload = <String, dynamic>{
      'game_state': gameState,
      'current_turn': gameState['currentTurn'] ?? room['current_turn'],
      'last_action': action.isEmpty ? null : action,
      'last_action_by': action['actorId'] ?? action['playerId'] ?? action['by'] ?? action['uid'],
      'winner_id': gameState['winnerId'],
      'status': gameState['winnerId'] != null ? 'finished' : 'round',
      'revision': gameState['revision'] ?? (currentRevision + 1),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('duel_games').update(updatePayload).eq('room_code', roomCode);
    final int localHandCount = (gameState['player1Hand'] as List?)?.length ?? ((gameState['hands'] is Map && (gameState['hands'] as Map)['player1'] is List) ? ((gameState['hands'] as Map)['player1'] as List).length : -1);
    debugPrint('[ACTION_PUSH] newRevision=${updatePayload['revision']}');
    debugPrint('[ACTION_PUSH] game_state updated handCount=$localHandCount');
    debugPrint('[ACTION] push success room=$roomCode revision=${currentRevision + 1} currentTurn=${updatePayload['current_turn']}');
  }

  Future<void> proposeStake({required String roomCode, required String proposedBy, required int amount}) async {
    await _client.from('duel_games').update({
      'stake_amount': amount,
      'stake_proposed_by': proposedBy,
      'stake_status': 'pending',
      'bet_flow_state': 'initialStakePendingResponse',
    }).eq('room_code', roomCode);
  }

  Future<void> respondToStake({required String roomCode, required String responderId, required bool accept, bool insufficientFunds = false}) async {
    if (accept) {
      final room = await fetchRoom(roomCode);
      final int amount = (room['stake_amount'] as num?)?.toInt() ?? 0;
      await _client.from('duel_games').update({
        'stake_accepted_by': responderId,
        'stake_status': 'accepted',
        'active_stake_credits': amount * 2,
        'status': 'round',
        'bet_flow_state': 'readyToStart',
      }).eq('room_code', roomCode);
      return;
    }
    await _client.from('duel_games').update({
      'stake_status': 'declined',
      'active_stake_credits': 0,
      'status': 'betting',
      'bet_flow_state': 'initialStakeRejected',
    }).eq('room_code', roomCode);
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

  Stream<List<Map<String, dynamic>>> watchActions(String roomCode) {
    return _client
        .from('duel_games')
        .stream(primaryKey: ['id'])
        .eq('room_code', roomCode)
        .map((rows) {
          if (rows.isEmpty) return <Map<String, dynamic>>[];
          final Map<String, dynamic> game = Map<String, dynamic>.from(rows.first);
          final dynamic lastAction = game['last_action'];
          if (lastAction is Map) {
            return <Map<String, dynamic>>[Map<String, dynamic>.from(lastAction)];
          }
          return <Map<String, dynamic>>[];
        });
  }

  Future<void> pushChatMessage({required String roomCode, required String senderId, required String senderName, required String text}) async {
    await _client.from('duel_chat_messages').insert({'game_id': roomCode, 'sender_id': senderId, 'sender_name': senderName, 'text': text});
  }
}
