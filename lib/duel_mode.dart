import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_logo.dart';
import 'app_sfx_service.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'game_popup_ui.dart';
import 'leaderboard_page.dart';
import 'player_profile.dart';
import 'player_side_panel.dart';
import 'premium_ui.dart';
import 'stats_service.dart';
import 'user_profile_service.dart';

enum DuelGameStatus { waiting, inProgress, finished }

enum DuelActionType { playCard, drawCard, resetRound }

enum DuelRematchDecision { pending, accepted, declined }

enum DuelChatDelivery { sending, sent, failed }

enum DuelRoomMode { duel, credits }

enum DuelStakeStatus { none, pending, accepted, declined, resolved, insufficientFunds }

enum DuelBetFlowState {
  idle,
  initialStakeProposed,
  initialStakePendingResponse,
  initialStakeRejected,
  invitedPlayerCanCounterPropose,
  counterStakePendingResponse,
  awaitingFundsValidation,
  readyToStart,
  matchFinished,
  rematchPendingFromLoser,
  rematchStakePendingWinnerResponse,
  rematchAccepted,
  rematchRejected,
  partyExited,
}

String _localizeUserError(Object error) {
  String message = error.toString().trim();
  message = message
      .replaceFirst(RegExp(r'^Bad state:\s*'), '')
      .replaceFirst(RegExp(r'^StateError:\s*'), '')
      .replaceFirst(RegExp(r'^Exception:\s*'), '');
  final String lowercase = message.toLowerCase();

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Erreur réseau. Vérifie ta connexion et réessaie.';
      case 'not-found':
        return 'Partie introuvable.';
      case 'permission-denied':
        return 'Connexion échouée. Accès refusé.';
      default:
        return 'Connexion échouée. Réessaie dans un instant.';
    }
  }

  if (lowercase.contains('partie introuvable') ||
      lowercase.contains('not found')) {
    return 'Partie introuvable.';
  }
  if (lowercase.contains('déjà complète') || lowercase.contains('full')) {
    return 'Impossible de rejoindre la partie : elle est déjà complète.';
  }
  if (lowercase.contains('compatible')) {
    return 'Code invalide pour ce mode de jeu.';
  }
  if (lowercase.contains('network') || lowercase.contains('socket')) {
    return 'Erreur réseau. Vérifie ta connexion et réessaie.';
  }
  if (lowercase.contains('permission')) {
    return 'Connexion échouée. Accès refusé.';
  }
  if (lowercase.contains('firebase non configuré') ||
      lowercase.contains('firebaseoptions')) {
    return 'Connexion échouée. Le service en ligne est indisponible.';
  }

  return message.isEmpty
      ? 'Une erreur est survenue. Veuillez réessayer.'
      : message;
}

class DuelStakeOffer {
  const DuelStakeOffer({
    this.proposedBy,
    this.acceptedBy,
    this.amount = 0,
    this.status = DuelStakeStatus.none,
    this.createdAt,
  });

  final String? proposedBy;
  final String? acceptedBy;
  final int amount;
  final DuelStakeStatus status;
  final DateTime? createdAt;

  bool get isPending => status == DuelStakeStatus.pending;
  bool get isAccepted => status == DuelStakeStatus.accepted;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'proposedBy': proposedBy,
      'acceptedBy': acceptedBy,
      'amount': amount,
      'status': status.name,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!.toUtc()),
    };
  }

  factory DuelStakeOffer.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const DuelStakeOffer();
    }
    return DuelStakeOffer(
      proposedBy: map['proposedBy'] as String?,
      acceptedBy: map['acceptedBy'] as String?,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      status: DuelStakeStatus.values.firstWhere(
        (DuelStakeStatus value) =>
            value.name == (map['status'] as String? ?? DuelStakeStatus.none.name),
        orElse: () => DuelStakeStatus.none,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class DuelAction {
  const DuelAction({
    required this.type,
    required this.actorId,
    required this.createdAt,
    this.payload = const <String, dynamic>{},
  });

  final DuelActionType type;
  final String actorId;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'actorId': actorId,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'payload': payload,
    };
  }

  factory DuelAction.fromMap(Map<String, dynamic> json) {
    return DuelAction(
      type: DuelActionType.values.firstWhere(
        (DuelActionType element) => element.name == json['type'],
      ),
      actorId: json['actorId'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? <String, dynamic>{}),
    );
  }
}

class DuelChatMessage {
  const DuelChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.delivery = DuelChatDelivery.sent,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final DuelChatDelivery delivery;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory DuelChatMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return DuelChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DuelSession {
  const DuelSession({
    required this.gameId,
    required this.hostId,
    required this.players,
    required this.playerNames,
    required this.currentTurn,
    required this.status,
    required this.scores,
    required this.round,
    this.mode = DuelRoomMode.duel,
    this.playerCredits = const <String, int>{},
    this.activeStakeCredits = 0,
    this.stakeOffer = const DuelStakeOffer(),
    this.lastAction,
    this.rematchRequestBy,
    this.rematchRequestedAt,
    this.rematchDecision = DuelRematchDecision.pending,
    this.rematchDecisionBy,
    this.betFlowState = DuelBetFlowState.idle,
    this.invitedRefusalCount = 0,
    this.exitedBy,
    this.lastInsufficientFundsPlayerId,
  });

  final String gameId;
  final String hostId;
  final List<String> players;
  final Map<String, String> playerNames;
  final String currentTurn;
  final DuelGameStatus status;
  final Map<String, int> scores;
  final int round;
  final DuelRoomMode mode;
  final Map<String, int> playerCredits;
  final int activeStakeCredits;
  final DuelStakeOffer stakeOffer;
  final DuelAction? lastAction;
  final String? rematchRequestBy;
  final DateTime? rematchRequestedAt;
  final DuelRematchDecision rematchDecision;
  final String? rematchDecisionBy;
  final DuelBetFlowState betFlowState;
  final int invitedRefusalCount;
  final String? exitedBy;
  final String? lastInsufficientFundsPlayerId;

  bool get canStart => players.length == 2;
  bool get isCreditsMode => mode == DuelRoomMode.credits;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'hostId': hostId,
      'players': players,
      'playerNames': playerNames,
      'currentTurn': currentTurn,
      'status': status.name,
      'scores': scores,
      'round': round,
      'mode': mode.name,
      'playerCredits': playerCredits,
      'activeStakeCredits': activeStakeCredits,
      'stakeOffer': stakeOffer.toMap(),
      'lastAction': lastAction?.toMap(),
      'rematchRequestBy': rematchRequestBy,
      'rematchRequestedAt': rematchRequestedAt == null
          ? null
          : Timestamp.fromDate(rematchRequestedAt!.toUtc()),
      'rematchDecision': rematchDecision.name,
      'rematchDecisionBy': rematchDecisionBy,
      'betFlowState': betFlowState.name,
      'invitedRefusalCount': invitedRefusalCount,
      'exitedBy': exitedBy,
      'lastInsufficientFundsPlayerId': lastInsufficientFundsPlayerId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory DuelSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> json = doc.data() ?? <String, dynamic>{};
    return DuelSession(
      gameId: doc.id,
      hostId: json['hostId'] as String? ?? '',
      players: List<String>.from(json['players'] as List? ?? const <String>[]),
      playerNames: Map<String, String>.from(
        json['playerNames'] as Map? ?? const <String, String>{},
      ),
      currentTurn: json['currentTurn'] as String? ?? '',
      status: DuelGameStatus.values.firstWhere(
        (DuelGameStatus s) => s.name == (json['status'] as String? ?? DuelGameStatus.waiting.name),
      ),
      scores: Map<String, int>.from(
        (json['scores'] as Map? ?? const <String, int>{}).map(
          (Object? key, Object? value) => MapEntry(
            key.toString(),
            (value as num?)?.toInt() ?? 0,
          ),
        ),
      ),
      round: (json['round'] as num?)?.toInt() ?? 1,
      mode: DuelRoomMode.values.firstWhere(
        (DuelRoomMode value) =>
            value.name == (json['mode'] as String? ?? DuelRoomMode.duel.name),
        orElse: () => DuelRoomMode.duel,
      ),
      playerCredits: Map<String, int>.from(
        (json['playerCredits'] as Map? ?? const <String, int>{}).map(
          (Object? key, Object? value) => MapEntry(
            key.toString(),
            (value as num?)?.toInt() ?? 0,
          ),
        ),
      ),
      activeStakeCredits: (json['activeStakeCredits'] as num?)?.toInt() ?? 0,
      stakeOffer: DuelStakeOffer.fromMap(
        (json['stakeOffer'] as Map?)?.cast<String, dynamic>(),
      ),
      lastAction: json['lastAction'] == null
          ? null
          : DuelAction.fromMap(Map<String, dynamic>.from(json['lastAction'] as Map)),
      rematchRequestBy: json['rematchRequestBy'] as String?,
      rematchRequestedAt: (json['rematchRequestedAt'] as Timestamp?)?.toDate(),
      rematchDecision: DuelRematchDecision.values.firstWhere(
        (DuelRematchDecision d) =>
            d.name == (json['rematchDecision'] as String? ?? DuelRematchDecision.pending.name),
        orElse: () => DuelRematchDecision.pending,
      ),
      rematchDecisionBy: json['rematchDecisionBy'] as String?,
      betFlowState: DuelBetFlowState.values.firstWhere(
        (DuelBetFlowState state) =>
            state.name == (json['betFlowState'] as String? ?? DuelBetFlowState.idle.name),
        orElse: () => DuelBetFlowState.idle,
      ),
      invitedRefusalCount: (json['invitedRefusalCount'] as num?)?.toInt() ?? 0,
      exitedBy: json['exitedBy'] as String?,
      lastInsufficientFundsPlayerId: json['lastInsufficientFundsPlayerId'] as String?,
    );
  }
}

/// Multiplayer transport only: game rules stay in existing GameEngine.
class GameService {
  GameService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<FirebaseFirestore> _resolveDb() async {
    if (_firestore != null) {
      return _firestore!;
    }

    if (Firebase.apps.isEmpty) {
      try {
        final FirebaseOptions? options =
            FirebaseConfig.optionsForCurrentPlatform();
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          throw StateError(
            'FirebaseOptions manquantes pour cette plateforme.',
          );
        }
      } catch (e) {
        throw StateError(
          'Firebase non configuré. Le mode duel nécessite Firebase.initializeApp(). Détail: $e',
        );
      }
    }

    return FirebaseFirestore.instance;
  }

  Future<CollectionReference<Map<String, dynamic>>> _games() async =>
      (await _resolveDb()).collection('duel_games');

  String _generateCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random();
    return List<String>.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> createGame({
    required String playerId,
    required String playerName,
    String? playerEmail,
    DuelRoomMode mode = DuelRoomMode.duel,
  }) async {
    int initialCredits = UserProfileService.defaultCredits;
    if (mode == DuelRoomMode.credits) {
      final PlayerProfile profile = await UserProfileService.instance.createUserProfileIfNeeded(
        uid: playerId,
        email: playerEmail,
        pseudo: playerName,
      );
      initialCredits = profile.credits;
    }
    final String code = _generateCode();
    final CollectionReference<Map<String, dynamic>> games = await _games();
    await games.doc(code).set(
      DuelSession(
        gameId: code,
        hostId: playerId,
        players: <String>[playerId],
        playerNames: <String, String>{playerId: playerName},
        currentTurn: playerId,
        status: DuelGameStatus.waiting,
        scores: <String, int>{playerId: 0},
        round: 1,
        mode: mode,
        playerCredits: mode == DuelRoomMode.credits
            ? <String, int>{playerId: initialCredits}
            : const <String, int>{},
        betFlowState: mode == DuelRoomMode.credits
            ? DuelBetFlowState.initialStakeProposed
            : DuelBetFlowState.idle,
      ).toMap(),
    );
    return code;
  }

  Future<void> joinGame({
    required String gameId,
    required String playerId,
    required String playerName,
    String? playerEmail,
    DuelRoomMode? expectedMode,
  }) async {
    int joiningPlayerCredits = UserProfileService.defaultCredits;
    if (expectedMode == DuelRoomMode.credits) {
      final PlayerProfile profile = await UserProfileService.instance.createUserProfileIfNeeded(
        uid: playerId,
        email: playerEmail,
        pseudo: playerName,
      );
      joiningPlayerCredits = profile.credits;
    }
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (expectedMode != null && session.mode != expectedMode) {
        throw StateError('Ce salon n\'est pas compatible avec ce mode.');
      }
      if (session.players.length >= 2 && !session.players.contains(playerId)) {
        throw StateError('Partie déjà complète');
      }
      final List<String> players = <String>{...session.players, playerId}.toList();
      tx.update(ref, <String, dynamic>{
        'players': players,
        'playerNames.$playerId': playerName,
        'scores.$playerId': session.scores[playerId] ?? 0,
        if (session.isCreditsMode)
          'playerCredits.$playerId':
              session.playerCredits[playerId] ?? joiningPlayerCredits,
        'status': players.length == 2
            ? (session.isCreditsMode
                ? DuelGameStatus.waiting.name
                : DuelGameStatus.inProgress.name)
            : DuelGameStatus.waiting.name,
      });
    });
  }

  Stream<DuelSession> watchSession(String gameId) async* {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    yield* games
        .doc(gameId)
        .snapshots()
        .where((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists)
        .map(DuelSession.fromDoc);
  }


  Stream<List<DuelAction>> watchActions(String gameId) async* {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    yield* games
        .doc(gameId)
        .collection('actions')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    DuelAction.fromMap(doc.data()),
              )
              .toList(),
        );
  }

  Stream<List<DuelChatMessage>> watchChatMessages(String gameId) async* {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    yield* games
        .doc(gameId)
        .collection('chat_messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(DuelChatMessage.fromDoc)
              .where((DuelChatMessage message) => message.text.trim().isNotEmpty)
              .toList(),
        );
  }

  Future<void> pushChatMessage({
    required String gameId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final String cleaned = text.trim();
    if (cleaned.isEmpty) {
      return;
    }
    final CollectionReference<Map<String, dynamic>> games = await _games();
    await games.doc(gameId).collection('chat_messages').add(
      DuelChatMessage(
        id: '',
        senderId: senderId,
        senderName: senderName,
        text: cleaned,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> pushAction({
    required String gameId,
    required DuelAction action,
    required String nextTurn,
    DuelGameStatus status = DuelGameStatus.inProgress,
    Map<String, dynamic> sessionPatch = const <String, dynamic>{},
  }) async {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    final DocumentReference<Map<String, dynamic>> gameRef = games.doc(gameId);
    await gameRef.update(<String, dynamic>{
      'currentTurn': nextTurn,
      'lastAction': action.toMap(),
      'status': status.name,
      ...sessionPatch,
    });
    await gameRef.collection('actions').add(action.toMap());
  }

  Future<void> startNewRound({
    required DuelSession current,
    required String requestedBy,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(current.gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      final int nextRound = session.round + 1;
      final String starter = session.players.contains(requestedBy)
          ? requestedBy
          : session.hostId;
      final DuelAction action = DuelAction(
        type: DuelActionType.resetRound,
        actorId: requestedBy,
        createdAt: DateTime.now(),
        payload: <String, dynamic>{
          'round': nextRound,
          'startingPlayerId': starter,
        },
      );
      tx.update(ref, <String, dynamic>{
        'status': session.isCreditsMode ? DuelGameStatus.waiting.name : DuelGameStatus.inProgress.name,
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'activeStakeCredits': 0,
        'stakeOffer': const DuelStakeOffer().toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'betFlowState': session.isCreditsMode
            ? DuelBetFlowState.initialStakeProposed.name
            : DuelBetFlowState.idle.name,
        'invitedRefusalCount': 0,
        'exitedBy': null,
        'lastInsufficientFundsPlayerId': null,
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
  }

  Future<void> requestRematch({
    required String gameId,
    required String requestedBy,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      final String? winnerId = session.lastAction?.payload['winnerId'] as String?;
      if (session.status != DuelGameStatus.finished ||
          winnerId == null ||
          winnerId.isEmpty ||
          winnerId == requestedBy ||
          !session.players.contains(requestedBy)) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'rematchRequestBy': requestedBy,
        'rematchRequestedAt': FieldValue.serverTimestamp(),
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        if (session.isCreditsMode) ...<String, dynamic>{
          'betFlowState': DuelBetFlowState.rematchPendingFromLoser.name,
          'stakeOffer': const DuelStakeOffer().toMap(),
          'activeStakeCredits': 0,
        },
      });
    });
  }

  Future<void> exitBetParty({
    required String gameId,
    required String playerId,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await ref.update(<String, dynamic>{
      'betFlowState': DuelBetFlowState.partyExited.name,
      'exitedBy': playerId,
      'stakeOffer': const DuelStakeOffer().toMap(),
      'activeStakeCredits': 0,
    });
  }

  Future<void> respondToRematch({
    required DuelSession current,
    required String responderId,
    required bool accept,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(current.gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.rematchRequestBy == null ||
          session.rematchRequestBy == responderId ||
          session.status != DuelGameStatus.finished ||
          session.rematchDecision != DuelRematchDecision.pending) {
        return;
      }
      if (!accept) {
        tx.update(ref, <String, dynamic>{
          'rematchDecision': DuelRematchDecision.declined.name,
          'rematchDecisionBy': responderId,
        });
        return;
      }
      if (session.isCreditsMode) {
        tx.update(ref, <String, dynamic>{
          'status': DuelGameStatus.finished.name,
          'activeStakeCredits': 0,
          'stakeOffer': const DuelStakeOffer().toMap(),
          'rematchDecision': DuelRematchDecision.accepted.name,
          'rematchDecisionBy': responderId,
        });
        return;
      }
      final int nextRound = session.round + 1;
      final String starter = session.players.contains(session.rematchRequestBy)
          ? session.rematchRequestBy!
          : session.hostId;
      final DuelAction action = DuelAction(
        type: DuelActionType.resetRound,
        actorId: responderId,
        createdAt: DateTime.now(),
        payload: <String, dynamic>{
          'round': nextRound,
          'startingPlayerId': starter,
        },
      );
      tx.update(ref, <String, dynamic>{
        'status': session.isCreditsMode ? DuelGameStatus.waiting.name : DuelGameStatus.inProgress.name,
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'activeStakeCredits': session.isCreditsMode ? session.activeStakeCredits : 0,
        'stakeOffer': session.isCreditsMode
            ? session.stakeOffer.toMap()
            : const DuelStakeOffer().toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.accepted.name,
        'rematchDecisionBy': responderId,
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
  }

  Future<void> proposeStake({
    required DuelSession current,
    required String proposedBy,
    required int amount,
  }) async {
    if (!current.isCreditsMode) {
      return;
    }
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(current.gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (!session.isCreditsMode ||
          session.players.length < 2 ||
          session.status == DuelGameStatus.inProgress) {
        return;
      }
      final bool isInitialStakeFlow =
          session.status == DuelGameStatus.waiting && session.rematchRequestBy == null;
      final bool isRematchStakeFlow =
          session.status == DuelGameStatus.finished && session.rematchRequestBy != null;
      if (!isInitialStakeFlow && !isRematchStakeFlow) {
        return;
      }
      final String invitedId = session.players.firstWhere(
        (String id) => id != session.hostId,
        orElse: () => '',
      );
      if (isInitialStakeFlow &&
          session.invitedRefusalCount < 2 &&
          proposedBy != session.hostId) {
        throw StateError('Seul le créateur peut proposer la première mise.');
      }
      if (isInitialStakeFlow &&
          session.invitedRefusalCount >= 2 &&
          proposedBy != session.hostId &&
          proposedBy != invitedId) {
        throw StateError('Proposition invalide.');
      }
      if (isRematchStakeFlow && proposedBy != session.rematchRequestBy) {
        throw StateError('Seul le perdant peut proposer la mise de revanche.');
      }
      if (session.stakeOffer.isPending) {
        throw StateError('Une proposition est déjà en attente.');
      }
      if (amount <= 0) {
        throw StateError('Pari invalide.');
      }
      final int balance = session.playerCredits[proposedBy] ?? 0;
      if (amount > balance) {
        throw StateError('Solde insuffisant pour cette proposition.');
      }
      final String opponentId = session.players.firstWhere(
        (String id) => id != proposedBy,
        orElse: () => '',
      );
      if (opponentId.isNotEmpty) {
        final int opponentBalance = session.playerCredits[opponentId] ?? 0;
        if (amount > opponentBalance) {
          throw StateError('Mise refusée: crédit adverse insuffisant.');
        }
      }
      tx.update(ref, <String, dynamic>{
        'playerCredits.$proposedBy': balance - amount,
        'stakeOffer': DuelStakeOffer(
          proposedBy: proposedBy,
          amount: amount,
          status: DuelStakeStatus.pending,
          createdAt: DateTime.now(),
        ).toMap(),
        'betFlowState': isRematchStakeFlow
            ? DuelBetFlowState.rematchStakePendingWinnerResponse.name
            : (session.invitedRefusalCount >= 2 && proposedBy != session.hostId
                ? DuelBetFlowState.counterStakePendingResponse.name
                : DuelBetFlowState.initialStakePendingResponse.name),
        'lastInsufficientFundsPlayerId': null,
      });
    });
  }

  Future<void> respondToStake({
    required DuelSession current,
    required String responderId,
    required bool accept,
    bool insufficientFunds = false,
  }) async {
    if (!current.isCreditsMode) {
      return;
    }
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(current.gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      final DuelStakeOffer offer = session.stakeOffer;
      if (!offer.isPending ||
          offer.proposedBy == null ||
          offer.proposedBy == responderId ||
          !session.players.contains(responderId)) {
        return;
      }
      if (!accept) {
        final int proposerCredits = session.playerCredits[offer.proposedBy!] ?? 0;
        final String invitedId = session.players.firstWhere(
          (String id) => id != session.hostId,
          orElse: () => '',
        );
        final bool invitedDeclinedHostInitial = session.rematchRequestBy == null &&
            offer.proposedBy == session.hostId &&
            responderId == invitedId;
        final int nextRefusalCount = invitedDeclinedHostInitial
            ? session.invitedRefusalCount + 1
            : session.invitedRefusalCount;
        tx.update(ref, <String, dynamic>{
          'playerCredits.${offer.proposedBy!}': proposerCredits + offer.amount,
          'activeStakeCredits': 0,
          'stakeOffer': DuelStakeOffer(
            proposedBy: offer.proposedBy,
            acceptedBy: responderId,
            amount: offer.amount,
            status: insufficientFunds
                ? DuelStakeStatus.insufficientFunds
                : DuelStakeStatus.declined,
            createdAt: offer.createdAt,
          ).toMap(),
          'invitedRefusalCount': nextRefusalCount,
          'betFlowState': insufficientFunds
              ? DuelBetFlowState.awaitingFundsValidation.name
              : (nextRefusalCount >= 2
                  ? DuelBetFlowState.invitedPlayerCanCounterPropose.name
                  : DuelBetFlowState.initialStakeRejected.name),
          'lastInsufficientFundsPlayerId': insufficientFunds ? responderId : null,
        });
        return;
      }
      final int responderCredits = session.playerCredits[responderId] ?? 0;
      // Le proposeur a déjà sa mise retenue lors de la proposition.
      // On ne doit donc refuser ici que si le répondant n'a pas assez de crédit.
      if (offer.amount > responderCredits) {
        final int proposerBalance = session.playerCredits[offer.proposedBy!] ?? 0;
        tx.update(ref, <String, dynamic>{
          'playerCredits.${offer.proposedBy!}': proposerBalance + offer.amount,
          'activeStakeCredits': 0,
          'stakeOffer': DuelStakeOffer(
            proposedBy: offer.proposedBy,
            acceptedBy: responderId,
            amount: offer.amount,
            status: DuelStakeStatus.insufficientFunds,
            createdAt: offer.createdAt,
          ).toMap(),
          'betFlowState': DuelBetFlowState.awaitingFundsValidation.name,
          'lastInsufficientFundsPlayerId': responderId,
        });
        return;
      }
      final DuelStakeOffer acceptedOffer = DuelStakeOffer(
        proposedBy: offer.proposedBy,
        acceptedBy: responderId,
        amount: offer.amount,
        status: DuelStakeStatus.accepted,
        createdAt: offer.createdAt ?? DateTime.now(),
      );
      if (session.status == DuelGameStatus.finished) {
        final int nextRound = session.round + 1;
        final String starter = session.players.contains(session.rematchRequestBy)
            ? session.rematchRequestBy!
            : (offer.proposedBy ?? session.hostId);
        final DuelAction action = DuelAction(
          type: DuelActionType.resetRound,
          actorId: responderId,
          createdAt: DateTime.now(),
          payload: <String, dynamic>{
            'round': nextRound,
            'startingPlayerId': starter,
          },
        );
        tx.update(ref, <String, dynamic>{
          'playerCredits.$responderId': responderCredits - offer.amount,
          'activeStakeCredits': offer.amount * 2,
          'status': DuelGameStatus.inProgress.name,
          'round': nextRound,
          'currentTurn': starter,
          'lastAction': action.toMap(),
          'stakeOffer': acceptedOffer.toMap(),
          'rematchRequestBy': null,
          'rematchRequestedAt': null,
          'rematchDecision': DuelRematchDecision.pending.name,
          'rematchDecisionBy': null,
          'betFlowState': DuelBetFlowState.rematchAccepted.name,
          'invitedRefusalCount': 0,
          'exitedBy': null,
          'lastInsufficientFundsPlayerId': null,
        });
        tx.set(ref.collection('actions').doc(), action.toMap());
        return;
      }
      tx.update(ref, <String, dynamic>{
        'playerCredits.$responderId': responderCredits - offer.amount,
        'activeStakeCredits': offer.amount * 2,
        'status': DuelGameStatus.inProgress.name,
        'stakeOffer': acceptedOffer.toMap(),
        'betFlowState': DuelBetFlowState.readyToStart.name,
        'lastInsufficientFundsPlayerId': null,
      });
    });
  }

  Future<void> resolveStakeAfterRound({
    required DuelSession current,
    required String winnerId,
  }) async {
    if (!current.isCreditsMode) {
      return;
    }
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(current.gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      final DuelStakeOffer offer = session.stakeOffer;
      final int amount = session.activeStakeCredits;
      if (!offer.isAccepted || amount <= 0 || !session.players.contains(winnerId)) {
        return;
      }
      final String loserId = session.players.firstWhere(
        (String id) => id != winnerId,
        orElse: () => '',
      );
      if (loserId.isEmpty) {
        return;
      }
      final int winnerBalance = session.playerCredits[winnerId] ?? 0;
      final int loserBalance = session.playerCredits[loserId] ?? 0;
      tx.update(ref, <String, dynamic>{
        'playerCredits.$winnerId': winnerBalance + amount,
        'playerCredits.$loserId': loserBalance,
        'activeStakeCredits': 0,
        'stakeOffer': DuelStakeOffer(
          proposedBy: offer.proposedBy,
          acceptedBy: offer.acceptedBy,
          amount: offer.amount,
          status: DuelStakeStatus.resolved,
          createdAt: offer.createdAt,
        ).toMap(),
        'betFlowState': DuelBetFlowState.matchFinished.name,
      });
    });
  }
}

class DuelController extends ChangeNotifier {
  DuelController({
    required this.service,
    required this.localPlayerId,
    required this.localPlayerName,
    this.localPlayerEmail,
    this.roomMode = DuelRoomMode.duel,
  });

  final GameService service;
  final String localPlayerId;
  final String localPlayerName;
  final String? localPlayerEmail;
  final DuelRoomMode roomMode;

  DuelSession? session;
  StreamSubscription<DuelSession>? _subscription;
  bool busy = false;
  String? error;

  Future<void> create() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final String id = await service.createGame(
        playerId: localPlayerId,
        playerName: localPlayerName,
        playerEmail: localPlayerEmail,
        mode: roomMode,
      );
      await attach(id);
    } catch (e) {
      error = _localizeUserError(e);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> join(String gameId) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.joinGame(
        gameId: gameId,
        playerId: localPlayerId,
        playerName: localPlayerName,
        playerEmail: localPlayerEmail,
        expectedMode: roomMode,
      );
      await attach(gameId);
    } catch (e) {
      error = _localizeUserError(e);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> attach(String gameId) async {
    await _subscription?.cancel();
    _subscription = service.watchSession(gameId).listen((DuelSession value) {
      session = value;
      notifyListeners();
    });
  }

  bool get isMyTurn => session?.currentTurn == localPlayerId;

  Future<void> sendAction(
    DuelActionType type, {
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? nextTurnOverride,
    DuelGameStatus? statusOverride,
    Map<String, dynamic> sessionPatch = const <String, dynamic>{},
  }) async {
    final DuelSession? current = session;
    if (current == null || !isMyTurn) {
      return;
    }

    final String nextTurn =
        nextTurnOverride ??
        (current.players.length < 2
            ? localPlayerId
            : current.players.firstWhere(
                (String id) => id != localPlayerId,
                orElse: () => localPlayerId,
              ));

    await service.pushAction(
      gameId: current.gameId,
      action: DuelAction(
        type: type,
        actorId: localPlayerId,
        createdAt: DateTime.now(),
        payload: payload,
      ),
      nextTurn: nextTurn,
      status: statusOverride ?? DuelGameStatus.inProgress,
      sessionPatch: sessionPatch,
    );
  }

  Future<void> startNewRound() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.startNewRound(current: current, requestedBy: localPlayerId);
  }

  Future<void> requestRematch() async {
    final DuelSession? current = session;
    if (current == null || current.status != DuelGameStatus.finished) {
      return;
    }
    await service.requestRematch(
      gameId: current.gameId,
      requestedBy: localPlayerId,
    );
  }

  Future<void> respondToRematch(bool accept) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.respondToRematch(
      current: current,
      responderId: localPlayerId,
      accept: accept,
    );
  }

  Future<void> sendChatMessage(String text) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.pushChatMessage(
      gameId: current.gameId,
      senderId: localPlayerId,
      senderName: localPlayerName,
      text: text,
    );
  }

  Future<void> proposeStake(int amount) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.proposeStake(
      current: current,
      proposedBy: localPlayerId,
      amount: amount,
    );
  }

  Future<void> respondToStake(bool accept, {bool insufficientFunds = false}) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.respondToStake(
      current: current,
      responderId: localPlayerId,
      accept: accept,
      insufficientFunds: insufficientFunds,
    );
  }

  Future<void> exitBetParty() async {
    final DuelSession? current = session;
    if (current == null || !current.isCreditsMode) {
      return;
    }
    await service.exitBetParty(gameId: current.gameId, playerId: localPlayerId);
  }

  Future<void> resolveStakeAfterRound(String winnerId) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.resolveStakeAfterRound(current: current, winnerId: winnerId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class DuelLobbyPage extends StatefulWidget {
  const DuelLobbyPage({super.key, this.mode = DuelRoomMode.duel});

  final DuelRoomMode mode;

  @override
  State<DuelLobbyPage> createState() => _DuelLobbyPageState();
}

class _DuelLobbyPageState extends State<DuelLobbyPage> {
  DuelController? _controller;
  final AppSfxService _sfx = AppSfxService.instance;
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _openedDuel = false;
  bool _googleBusy = false;
  String? _profileError;
  late final String _localPlayerId;
  String? _authenticatedPlayerId;
  PlayerProfile? _playerProfile;

  @override
  void initState() {
    super.initState();
    _localPlayerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
    unawaited(_hydrateExistingAuthSession());
    if (widget.mode == DuelRoomMode.credits) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureParisAccess());
      });
    }
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_onControllerChange)
      ..dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    final DuelSession? session = _controller?.session;
    if (!_openedDuel && session != null && session.players.length == 2 && mounted) {
      _openedDuel = true;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DuelPage(controller: _controller!, mode: widget.mode),
        ),
      );
    }
    setState(() {});
  }

  String? _validatePseudo() {
    if (widget.mode == DuelRoomMode.credits && _authenticatedPlayerId == null) {
      return 'Connectez-vous avec Google pour jouer en mode Paris.';
    }
    if (_authenticatedPlayerId != null) {
      return null;
    }
    final String cleaned = _nameController.text.trim();
    if (cleaned.isEmpty) {
      return 'Veuillez entrer un pseudonyme';
    }
    return null;
  }

  Future<void> _hydrateExistingAuthSession() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return;
    }
    await _upsertProfileFromGoogle(user);
  }

  Future<void> _upsertProfileFromGoogle(User user) async {
    final PlayerProfile profile = await _profileService.createOrUpdateFromGoogleUser(user);
    if (!mounted) {
      return;
    }
    setState(() {
      _authenticatedPlayerId = user.uid;
      _playerProfile = profile;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = profile.displayName;
      }
    });
  }

  Future<void> _continueWithGoogle() async {
    unawaited(_sfx.playClick());
    if (_googleBusy) {
      return;
    }
    setState(() {
      _googleBusy = true;
      _profileError = null;
    });
    final GoogleAuthResult result = await _authService.signInWithGoogle();
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      setState(() {
        _googleBusy = false;
        switch (result.failureReason) {
          case AuthFailureReason.cancelled:
            _profileError = 'Connexion Google annulée.';
            break;
          case AuthFailureReason.popupBlocked:
            _profileError =
                result.errorMessage ??
                'Popup bloquée. Autorisez les popups puis réessayez.';
            break;
          case AuthFailureReason.network:
            _profileError =
                result.errorMessage ??
                'Réseau indisponible. Vérifiez votre connexion.';
            break;
          case AuthFailureReason.providerNotEnabled:
            _profileError =
                result.errorMessage ??
                'Google Sign-In doit être activé dans Firebase Authentication.';
            break;
          case AuthFailureReason.invalidConfiguration:
            _profileError =
                result.errorMessage ??
                'Configuration Firebase/Google invalide.';
            break;
          case AuthFailureReason.unavailable:
          case AuthFailureReason.unknown:
          case null:
            _profileError = result.errorMessage ?? 'Connexion Google impossible.';
            break;
        }
      });
      return;
    }
    await _upsertProfileFromGoogle(result.user!);
    if (!mounted) {
      return;
    }
    setState(() {
      _googleBusy = false;
    });
  }

  Future<void> _ensureParisAccess() async {
    if (!mounted || _authService.currentUser != null) {
      return;
    }
    final bool shouldLogin = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Mode Paris'),
              content: const Text(
                'Connectez-vous avec Google pour jouer en mode Paris.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Retour'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Connexion Google'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!mounted) {
      return;
    }
    if (!shouldLogin) {
      Navigator.of(context).pop();
      return;
    }
    await _continueWithGoogle();
    if (!mounted) {
      return;
    }
    if (_authenticatedPlayerId == null) {
      Navigator.of(context).pop();
    }
  }

  String? _validateCodePartie() {
    final String cleaned = _codeController.text.trim().toUpperCase();
    if (cleaned.isEmpty) {
      return 'Veuillez entrer un code de partie';
    }
    if (cleaned.length != 6) {
      return 'Code invalide. Format attendu : 6 caractères.';
    }
    return null;
  }

  DuelController _buildController(String pseudo) {
    final DuelController? existing = _controller;
    if (existing != null) {
      existing.removeListener(_onControllerChange);
      existing.dispose();
    }
    final DuelController created = DuelController(
      service: GameService(),
      localPlayerId: _authenticatedPlayerId ?? _localPlayerId,
      localPlayerName: pseudo,
      localPlayerEmail: _authService.currentUser?.email,
      roomMode: widget.mode,
    )..addListener(_onControllerChange);
    _controller = created;
    return created;
  }

  String? _resolvePlayerName() {
    if (_authenticatedPlayerId != null) {
      final String profileName = _playerProfile?.displayName.trim() ?? '';
      if (profileName.isNotEmpty) {
        return profileName;
      }
      final String authDisplayName =
          _authService.currentUser?.displayName?.trim() ?? '';
      if (authDisplayName.isNotEmpty) {
        return authDisplayName;
      }
      return 'Joueur';
    }
    return _nameController.text.trim();
  }

  Future<void> _createGame() async {
    unawaited(_sfx.playClick());
    final String? pseudoError = _validatePseudo();
    if (pseudoError != null) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = pseudoError;
      });
      return;
    }
    final String pseudo = _resolvePlayerName()!;
    setState(() {
      _profileError = null;
    });
    final DuelController controller = (_controller != null &&
            _controller!.localPlayerName == pseudo)
        ? _controller!
        : _buildController(pseudo);
    await controller.create();
  }

  Future<void> _joinGame() async {
    unawaited(_sfx.playClick());
    final String? pseudoError = _validatePseudo();
    if (pseudoError != null) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = pseudoError;
      });
      return;
    }
    final String? codeError = _validateCodePartie();
    if (codeError != null) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = codeError;
      });
      return;
    }
    final String pseudo = _resolvePlayerName()!;
    final String code = _codeController.text.trim().toUpperCase();
    setState(() {
      _profileError = null;
    });
    final DuelController controller = (_controller != null &&
            _controller!.localPlayerName == pseudo)
        ? _controller!
        : _buildController(pseudo);
    await controller.join(code);
  }


  @override
  Widget build(BuildContext context) {
    final DuelSession? session = _controller?.session;
    final bool busy = _controller?.busy ?? false;
    final bool creditsMode = widget.mode == DuelRoomMode.credits;
    final bool isAuthenticated = _authenticatedPlayerId != null;
    final String title = creditsMode ? 'DUEL PARIS' : 'DUEL SIMPLE';
    return Scaffold(
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LeaderboardPage()),
          );
        },
      ),
      body: Stack(
        children: <Widget>[
          TableBackground(
            child: SafeArea(
              child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              Navigator.of(context).popUntil(
                                (Route<dynamic> route) => route.isFirst,
                              );
                            },
                            tooltip: 'Retour aux modes',
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          children: <Widget>[
                            const AppLogo(size: 88),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!creditsMode && !isAuthenticated) ...<Widget>[
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextField(
                              controller: _nameController,
                              onChanged: (_) {
                                if (_profileError != null) {
                                  setState(() {
                                    _profileError = null;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                hintText: 'Ton pseudo',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Créer une partie',
                            style: TextStyle(
                              color: PremiumColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: busy ? null : _createGame,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Créer maintenant'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PremiumColors.accentGreen,
                              foregroundColor: PremiumColors.textDark,
                            ),
                          ),
                          if (session != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PremiumColors.panelSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SelectableText(
                                    'Code de partie: ${session.gameId}',
                                    style: const TextStyle(
                                      color: PremiumColors.textDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        unawaited(_sfx.playClick());
                                        await Clipboard.setData(
                                          ClipboardData(text: session.gameId),
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Code de la partie copié'),
                                          ),
                                        );
                                        unawaited(_sfx.playNotif());
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      label: const Text('Copier le code'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: PremiumColors.textDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Joueurs: ${session.players.length}/2',
                                    style: const TextStyle(color: PremiumColors.textDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Rejoindre une partie',
                            style: TextStyle(
                              color: PremiumColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) {
                              if (_profileError != null) {
                                setState(() {
                                  _profileError = null;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'AB12CD',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: busy ? null : _joinGame,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Rejoindre'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PremiumColors.accentGreen,
                              foregroundColor: PremiumColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_profileError != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        _profileError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD4D4),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if ((_controller?.error) != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        _controller!.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD4D4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: GlobalMusicToggleButton(
                margin: EdgeInsets.only(right: 10, bottom: 10),
              ),
            ),
          ),
          SafeArea(
            child: Builder(
              builder: (BuildContext context) => const PlayerSidePanelButton(),
            ),
          ),
        ],
      ),
    );
  }
}

class DuelPage extends StatefulWidget {
  const DuelPage({
    super.key,
    required this.controller,
    this.mode = DuelRoomMode.duel,
  });

  final DuelController controller;
  final DuelRoomMode mode;

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  static const List<DuelCard> _avatarCardPool = <DuelCard>[
    DuelCard(suit: '♠', rank: 'A'),
    DuelCard(suit: '♥', rank: 'K'),
    DuelCard(suit: '♦', rank: 'Q'),
    DuelCard(suit: '♣', rank: 'J'),
    DuelCard(suit: '♠', rank: '9'),
    DuelCard(suit: '♥', rank: '8'),
    DuelCard(suit: '♦', rank: '7'),
    DuelCard(suit: '♣', rank: '10'),
  ];

  StreamSubscription<List<DuelAction>>? _actionsSubscription;
  StreamSubscription<List<DuelChatMessage>>? _chatSub;
  DuelBoardState? _board;
  String? _lastEightPopupKey;
  String? _lastForcedDrawPopupKey;
  String? _lastAcePopupKey;
  String? _lastRematchRequestKey;
  bool _rematchDialogOpen = false;
  bool _rematchActionBusy = false;
  bool _stakeActionBusy = false;
  bool _stakeDialogOpen = false;
  bool _stakeSelectionDialogOpen = false;
  bool _stakeRejectedDialogOpen = false;
  bool _winDialogOpen = false;
  String? _lastStakeOfferKey;
  String? _lastStakeRejectedKey;
  String? _lastMandatoryStakePromptKey;
  String? _lastWinPopupKey;
  String? _lastInsufficientFundsKey;
  String? _lastExitKey;
  bool _didNavigateHomeAfterDecline = false;
  final ValueNotifier<List<DuelChatMessage>> _chatMessagesNotifier =
      ValueNotifier<List<DuelChatMessage>>(const <DuelChatMessage>[]);
  final Set<String> _knownMessageIds = <String>{};
  bool _isChatOpen = false;
  bool _chatBootstrapped = false;
  int _unreadChatCount = 0;
  String? _chatError;
  String? _chatGameId;
  String? _pendingStakeOfferAfterVictoryKey;
  String? _pendingRematchAfterVictoryKey;
  final Queue<String> _chatPreviewQueue = Queue<String>();
  final StatsService _statsService = StatsService.instance;
  String? _activeChatPreview;
  Timer? _chatPreviewTimer;
  String? _lastOutcomeSfxKey;
  String? _lastStatsSyncKey;
  String? _lastOpponentActionSfxKey;
  final AppSfxService _sfx = AppSfxService.instance;

  static const List<String> _quickMessages = <String>[
    'Bien joué',
    'À toi',
    'J’arrive',
    'Attends',
    'Bravo',
    'Oups',
    'On recommence ?',
  ];

  DuelController get _controller => widget.controller;
  bool get _isCreditsMode => widget.mode == DuelRoomMode.credits;
  bool _isInitialStakePhase(DuelSession session) =>
      session.status == DuelGameStatus.waiting && session.rematchRequestBy == null;
  bool _isRematchStakePhase(DuelSession session) =>
      session.status == DuelGameStatus.finished && session.rematchRequestBy != null;
  bool _canSetStake(DuelSession session) {
    if (!_isCreditsMode || session.players.length != 2) {
      return false;
    }
    if (_isInitialStakePhase(session)) {
      if (session.invitedRefusalCount >= 2) {
        return true;
      }
      return _controller.localPlayerId == session.hostId;
    }
    if (_isRematchStakePhase(session)) {
      return _controller.localPlayerId == session.rematchRequestBy;
    }
    return false;
  }
  bool _requiresStake(DuelSession session) =>
      _isCreditsMode &&
      session.players.length == 2 &&
      session.status == DuelGameStatus.inProgress &&
      session.activeStakeCredits <= 0;
  bool _isBlockingDialogOpen() =>
      _rematchDialogOpen ||
      _stakeDialogOpen ||
      _stakeSelectionDialogOpen ||
      _stakeRejectedDialogOpen ||
      _winDialogOpen;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    _onControllerChange();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _actionsSubscription?.cancel();
    _chatSub?.cancel();
    _chatPreviewTimer?.cancel();
    _chatMessagesNotifier.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    final DuelSession? session = _controller.session;
    if (session == null || session.players.length < 2) {
      return;
    }
    if (_board == null || _board!.gameId != session.gameId || _board!.round != session.round) {
      final DuelBoardState initial = DuelBoardState.initial(
        gameId: session.gameId,
        players: session.players,
        round: session.round,
      );
      setState(() {
        _board = initial;
      });
      _actionsSubscription?.cancel();
      _actionsSubscription = _controller.service
          .watchActions(session.gameId)
          .listen((List<DuelAction> actions) {
            if (!mounted) {
              return;
            }
            setState(() {
              _board = initial.rebuildFromActions(actions);
            });
          });
    }
    _bindChatRealtime(session);
    _maybeShowCommandPopup(session);
    _maybeShowForcedDrawPopup(session);
    _maybeShowAceRequiredPopup(session);
    _maybePlayOpponentActionSfx(session);
    _maybeHandleStakeFlow(session);
    _maybeHandleStakeRejected(session);
    _maybeHandleInsufficientFunds(session);
    _maybeHandleRematchFlow(session);
    _maybeHandlePartyExit(session);
    _maybePromptMandatoryStake(session);
    _maybeShowWinPopup(session);
    _maybePlayRoundOutcomeSfx(session);
  }

  void _bindChatRealtime(DuelSession session) {
    if (_chatSub != null && _chatGameId == session.gameId) {
      return;
    }
    _chatSub?.cancel();
    _knownMessageIds.clear();
    _chatBootstrapped = false;
    _chatMessagesNotifier.value = const <DuelChatMessage>[];
    _chatError = null;
    _unreadChatCount = 0;
    _chatGameId = session.gameId;
    _chatSub = _controller.service
        .watchChatMessages(session.gameId)
        .listen(
          (List<DuelChatMessage> messages) {
            if (!mounted) {
              return;
            }
            final Map<String, DuelChatMessage> dedup = <String, DuelChatMessage>{
              for (final DuelChatMessage message in messages) message.id: message,
            };
            final List<DuelChatMessage> ordered = dedup.values.toList()
              ..sort((DuelChatMessage a, DuelChatMessage b) => a.createdAt.compareTo(b.createdAt));
            int unreadDelta = 0;
            final List<String> previews = <String>[];
            for (final DuelChatMessage message in ordered) {
              if (_knownMessageIds.contains(message.id)) {
                continue;
              }
              _knownMessageIds.add(message.id);
              if (_chatBootstrapped &&
                  !_isChatOpen &&
                  message.senderId != _controller.localPlayerId) {
                unreadDelta += 1;
                previews.add(message.text);
              }
            }
            setState(() {
              _chatMessagesNotifier.value = List<DuelChatMessage>.unmodifiable(ordered);
              _chatError = null;
              _unreadChatCount += unreadDelta;
            });
            if (previews.isNotEmpty) {
              _enqueueChatPreview(previews);
            }
            if (!_chatBootstrapped) {
              _chatBootstrapped = true;
            }
          },
          onError: (Object errorValue, StackTrace _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _chatError = _localizeUserError(errorValue);
            });
          },
        );
  }

  void _enqueueChatPreview(List<String> previews) {
    if (_isChatOpen) {
      return;
    }
    for (final String preview in previews) {
      final String trimmed = preview.trim();
      if (trimmed.isNotEmpty) {
        _chatPreviewQueue.add(trimmed);
      }
    }
    _showNextChatPreviewIfIdle();
  }

  void _showNextChatPreviewIfIdle() {
    if (!mounted || _activeChatPreview != null || _chatPreviewQueue.isEmpty || _isChatOpen) {
      return;
    }
    final String next = _chatPreviewQueue.removeFirst();
    setState(() {
      _activeChatPreview = next;
    });
    unawaited(_sfx.playChat());
    _chatPreviewTimer?.cancel();
    _chatPreviewTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeChatPreview = null;
      });
      _showNextChatPreviewIfIdle();
    });
  }

  Future<void> _onCardTap(DuelCard card) async {
    final DuelSession? session = _controller.session;
    final DuelBoardState? board = _board;
    if (session == null || board == null || !_controller.isMyTurn) {
      return;
    }
    if (_requiresStake(session)) {
      _showStakeRequiredMessage();
      return;
    }
    String? chosenSuit;
    if (card.rank == '8') {
      chosenSuit = await _showSuitChoice(context);
      if (chosenSuit == null) {
        return;
      }
    }
    final DuelMoveResult move = board.tryPlay(
      actorId: _controller.localPlayerId,
      card: card,
      chosenSuit: chosenSuit,
    );
    if (!move.accepted) {
      return;
    }
    unawaited(_sfx.playCard());
    await _controller.sendAction(
      DuelActionType.playCard,
      payload: move.payload,
      nextTurnOverride: move.nextTurn,
      statusOverride: move.payload.containsKey('winnerId')
          ? DuelGameStatus.finished
          : DuelGameStatus.inProgress,
      sessionPatch: move.payload.containsKey('winnerId')
          ? <String, dynamic>{
              'scores.${_controller.localPlayerId}': FieldValue.increment(1),
            }
          : const <String, dynamic>{},
    );
    final String? winnerId = move.payload['winnerId'] as String?;
    if (_isCreditsMode && winnerId != null && winnerId.isNotEmpty) {
      await _controller.resolveStakeAfterRound(winnerId);
    }
  }

  Future<String?> _showSuitChoice(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        const List<(String, String)> suits = <(String, String)>[
          ('♣', 'Trèfle'),
          ('♦', 'Carreau'),
          ('♠', 'Pique'),
          ('♥', 'Cœur'),
        ];
        return GamePopupDialog(
          title: 'TU COMMANDES ?',
          subtitle: 'Choisis une couleur',
          child: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: suits
                  .map(
                    ((String, String) suit) => InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(suit.$1),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x3320332B)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              suit.$1,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: _suitColor(suit.$1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suit.$2,
                              style: const TextStyle(
                                color: Color(0xFF1A342A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOpponentEightPopup({
    required String actorName,
    required String suit,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          }),
        );
        return GamePopupDialog(
          title: '8 SPÉCIAL',
          subtitle: actorName,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PremiumCardStack(count: 2, rankLabel: '8'),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'a commandé',
                    style: TextStyle(
                      color: Color(0xFF1A342A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    suit,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: _suitGlyphColor(suit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showForcedDrawPopup(int amount) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 2200), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          }),
        );
        return GamePopupDialog(
          title: 'CARTE SPÉCIALE',
          subtitle: 'Effet immédiat',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PremiumCardStack(count: 3, rankLabel: '2', suit: '♠'),
              const SizedBox(height: 12),
              Text(
                'PIOCHEZ $amount CARTES',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF13261D),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAceRequiredPopup() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 1800), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          }),
        );
        return const GamePopupDialog(
          title: 'AS EST CHAUD',
          subtitle: 'Réponse obligatoire',
          child: PremiumCardStack(count: 2, rankLabel: 'A', suit: '♠'),
        );
      },
    );
  }

  void _maybeShowCommandPopup(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null ||
        action.type != DuelActionType.playCard ||
        action.actorId == _controller.localPlayerId) {
      return;
    }
    final String? cardId = action.payload['cardId'] as String?;
    final String? chosenSuit = action.payload['chosenSuit'] as String?;
    if (cardId == null || !cardId.startsWith('8') || chosenSuit == null) {
      return;
    }
    final String key = '${action.actorId}_${action.createdAt.toIso8601String()}';
    if (_lastEightPopupKey == key) {
      return;
    }
    _lastEightPopupKey = key;
    final String actorName = _displayNameUpper(session, action.actorId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showOpponentEightPopup(actorName: actorName, suit: chosenSuit);
    });
  }

  void _maybeShowForcedDrawPopup(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null ||
        action.type != DuelActionType.playCard ||
        action.actorId == _controller.localPlayerId) {
      return;
    }
    final String? cardId = action.payload['cardId'] as String?;
    if (cardId == null) {
      return;
    }
    final DuelCard card = DuelCard.fromId(cardId);
    if (card.rank != '2' && !card.isJoker) {
      return;
    }
    final int amount = (_board?.pendingDraw ?? 0) > 0
        ? _board!.pendingDraw
        : (card.rank == '2' ? 3 : 8);
    final String key = '${action.actorId}_${action.createdAt.toIso8601String()}_$amount';
    if (_lastForcedDrawPopupKey == key) {
      return;
    }
    _lastForcedDrawPopupKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showForcedDrawPopup(amount);
    });
  }

  void _maybeShowAceRequiredPopup(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null ||
        action.type != DuelActionType.playCard ||
        action.actorId == _controller.localPlayerId ||
        !_controller.isMyTurn) {
      return;
    }
    final String? cardId = action.payload['cardId'] as String?;
    if (cardId == null || !cardId.startsWith('A') || !(_board?.aceColorRequired ?? false)) {
      return;
    }
    final String key = '${action.actorId}_${action.createdAt.toIso8601String()}_ace';
    if (_lastAcePopupKey == key) {
      return;
    }
    _lastAcePopupKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showAceRequiredPopup();
    });
  }

  void _maybePlayOpponentActionSfx(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null || action.actorId == _controller.localPlayerId) {
      return;
    }
    if (action.type != DuelActionType.playCard &&
        action.type != DuelActionType.drawCard) {
      return;
    }
    final String key =
        '${session.gameId}_${action.actorId}_${action.type.name}_${action.createdAt.toIso8601String()}';
    if (_lastOpponentActionSfxKey == key) {
      return;
    }
    _lastOpponentActionSfxKey = key;
    if (action.type == DuelActionType.playCard) {
      unawaited(_sfx.playCard());
      return;
    }
    unawaited(_sfx.playDraw());
  }

  Future<void> _onDrawTap() async {
    final DuelSession? session = _controller.session;
    final DuelBoardState? board = _board;
    if (session == null || board == null || !_controller.isMyTurn) {
      return;
    }
    if (_requiresStake(session)) {
      _showStakeRequiredMessage();
      return;
    }
    final DuelMoveResult move = board.tryDraw(actorId: _controller.localPlayerId);
    if (!move.accepted) {
      return;
    }
    unawaited(_sfx.playDraw());
    await _controller.sendAction(
      DuelActionType.drawCard,
      payload: move.payload,
      nextTurnOverride: move.nextTurn,
    );
  }

  String _resolveName(DuelSession session, String playerId) {
    final String? raw = session.playerNames[playerId]?.trim();
    return raw == null || raw.isEmpty ? playerId : raw;
  }

  String _displayNameUpper(DuelSession session, String playerId) =>
      _resolveName(session, playerId).toUpperCase();

  String? _winnerId(DuelSession session) =>
      session.lastAction?.payload['winnerId'] as String?;

  String? _loserId(DuelSession session) {
    final String? winnerId = _winnerId(session);
    if (winnerId == null || winnerId.isEmpty) {
      return null;
    }
    final String loserId = session.players.firstWhere(
      (String id) => id != winnerId,
      orElse: () => '',
    );
    return loserId.isEmpty ? null : loserId;
  }

  bool _isLocalWinner(DuelSession session) => _winnerId(session) == _controller.localPlayerId;
  bool _isLocalLoser(DuelSession session) => _loserId(session) == _controller.localPlayerId;

  void _maybePlayRoundOutcomeSfx(DuelSession session) {
    if (session.status != DuelGameStatus.finished) {
      return;
    }
    final String? winnerId = _winnerId(session);
    if (winnerId == null || winnerId.isEmpty) {
      return;
    }
    final String key =
        '${session.gameId}_${session.round}_${session.lastAction?.createdAt.toIso8601String() ?? ''}_$winnerId';
    if (_lastOutcomeSfxKey == key) {
      return;
    }
    _lastOutcomeSfxKey = key;
    if (winnerId == _controller.localPlayerId) {
      unawaited(_sfx.playWin());
    } else {
      unawaited(_sfx.playLose());
    }
    unawaited(_syncPersistentStats(session: session, winnerId: winnerId, key: key));
  }

  Future<void> _syncPersistentStats({
    required DuelSession session,
    required String winnerId,
    required String key,
  }) async {
    if (_lastStatsSyncKey == key) {
      return;
    }
    final String? loserId = _loserId(session);
    if (loserId == null || loserId.isEmpty) {
      return;
    }
    _lastStatsSyncKey = key;
    try {
      final int stakeAmount =
          session.isCreditsMode && session.stakeOffer.isAccepted
              ? session.stakeOffer.amount
              : 0;
      await _statsService.recordDuelResult(
        gameId: session.gameId,
        round: session.round,
        winnerId: winnerId,
        loserId: loserId,
        winnerCreditsDelta: stakeAmount,
        loserCreditsDelta: -stakeAmount,
        preventNegativeCredits: true,
      );
    } catch (error) {
      debugPrint('Stats sync failed: $error');
      _lastStatsSyncKey = null;
    }
  }

  bool _canPromptRematchStake(DuelSession session) {
    return _isCreditsMode &&
        _isRematchStakePhase(session) &&
        _controller.localPlayerId == session.rematchRequestBy &&
        session.activeStakeCredits <= 0 &&
        !session.stakeOffer.isPending;
  }

  int _creditsOf(DuelSession session, String playerId) =>
      session.playerCredits[playerId] ?? 1000;

  DuelCard _avatarCardForPlayer(String playerId) {
    if (playerId.isEmpty) {
      return _avatarCardPool.first;
    }
    final int index = playerId.runes.fold<int>(
          0,
          (int value, int rune) => value + rune,
        ) %
        _avatarCardPool.length;
    return _avatarCardPool[index];
  }

  DuelCard _avatarCardForOpponent({
    required String localPlayerId,
    required String opponentId,
  }) {
    final DuelCard localCard = _avatarCardForPlayer(localPlayerId);
    DuelCard opponentCard = _avatarCardForPlayer(opponentId);
    final bool sameCard = opponentCard.rank == localCard.rank &&
        opponentCard.suit == localCard.suit;
    if (sameCard) {
      final int index = _avatarCardPool.indexWhere(
        (DuelCard card) =>
            card.rank == opponentCard.rank && card.suit == opponentCard.suit,
      );
      final int nextIndex = index < 0 ? 1 : (index + 1) % _avatarCardPool.length;
      opponentCard = _avatarCardPool[nextIndex];
    }
    return opponentCard;
  }

  Future<void> _openStakeProposal(DuelSession session) async {
    if (!_canSetStake(session) || _stakeActionBusy) {
      return;
    }
    final int myCredits = _creditsOf(session, _controller.localPlayerId);
    final String opponentId = session.players.firstWhere(
      (String id) => id != _controller.localPlayerId,
      orElse: () => '',
    );
    final int? opponentCredits = opponentId.isEmpty
        ? null
        : _creditsOf(session, opponentId);
    final int? selected = await _showStakeSelectionDialog(
      myCredits: myCredits,
      opponentCredits: opponentCredits,
    );
    if (selected == null) {
      if (_requiresStake(session)) {
        _showStakeRequiredMessage();
      }
      return;
    }
    await _submitStakeProposal(session: session, amount: selected);
  }

  Future<int?> _showStakeSelectionDialog({
    required int myCredits,
    required int? opponentCredits,
  }) async {
    if (_stakeSelectionDialogOpen) {
      return null;
    }
    _stakeSelectionDialogOpen = true;
    final TextEditingController amountController = TextEditingController();
    int? selectedAmount;
    String? validationError;
    final List<int> options = <int>[100, 250, 500, 1000, 2000];
    final int? selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            String? validate(int? amount) => _stakeValidationError(
              amount: amount,
              myCredits: myCredits,
              opponentCredits: opponentCredits,
            );

            void selectAmount(int amount) {
              amountController.text = amount.toString();
              setModalState(() {
                selectedAmount = amount;
                validationError = validate(amount);
              });
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom + 14,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF142D22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Faire un pari',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solde disponible: $myCredits',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE8FFF3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (opponentCredits != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Crédit adverse: $opponentCredits',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFE9A8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((int amount) {
                          final bool disabled = amount > myCredits;
                          final bool exceedsOpponent = opponentCredits != null &&
                              amount > opponentCredits;
                          return ChoiceChip(
                            label: Text('$amount'),
                            selected: selectedAmount == amount,
                            onSelected: (disabled || exceedsOpponent)
                                ? null
                                : (_) => selectAmount(amount),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Montant du pari',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'Ex: 750',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (String value) {
                          final int? parsed = int.tryParse(value.trim());
                          setModalState(() {
                            selectedAmount = parsed;
                            validationError = validate(parsed);
                          });
                        },
                      ),
                      if (validationError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          validationError!,
                          style: const TextStyle(
                            color: Color(0xFFFFC9C9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: validationError != null
                                  ? null
                                  : () {
                                      final int? parsed = int.tryParse(
                                        amountController.text.trim(),
                                      );
                                      final String? error = validate(parsed);
                                      if (error != null) {
                                        setModalState(() {
                                          selectedAmount = parsed;
                                          validationError = error;
                                        });
                                        return;
                                      }
                                      Navigator.of(context).pop(parsed);
                                    },
                              icon: const Icon(Icons.lock_rounded),
                              label: const Text('Valider'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(_exitPartyFlow());
                        },
                        child: const Text('Quitter la partie'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    _stakeSelectionDialogOpen = false;
    amountController.dispose();
    return selected;
  }

  Future<bool> _submitStakeProposal({
    required DuelSession session,
    required int amount,
  }) async {
    final int myCredits = _creditsOf(session, _controller.localPlayerId);
    final String opponentId = session.players.firstWhere(
      (String id) => id != _controller.localPlayerId,
      orElse: () => '',
    );
    final int? opponentCredits = opponentId.isEmpty
        ? null
        : _creditsOf(session, opponentId);
    final String? validationError = _stakeValidationError(
      amount: amount,
      myCredits: myCredits,
      opponentCredits: opponentCredits,
    );
    if (validationError != null) {
      _showStakeRequiredMessage(
        validationError,
      );
      return false;
    }
    setState(() {
      _stakeActionBusy = true;
    });
    try {
      await _controller.proposeStake(amount);
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      unawaited(_sfx.playError());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposition impossible pour le moment.')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _stakeActionBusy = false;
        });
      }
    }
  }

  void _showStakeRequiredMessage([
    String message = 'Un pari valide est obligatoire pour lancer la partie.',
  ]) {
    if (!mounted) {
      return;
    }
    unawaited(_sfx.playError());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _stakeValidationError({
    required int? amount,
    required int myCredits,
    int? opponentCredits,
  }) {
    if (amount == null) {
      return 'Choisissez un pari valide.';
    }
    if (amount <= 0) {
      return 'Le montant doit être supérieur à 0.';
    }
    if (amount > myCredits) {
      return 'Solde insuffisant pour ce pari.';
    }
    if (opponentCredits != null && amount > opponentCredits) {
      return 'Mise refusée: le crédit adverse est insuffisant.';
    }
    return null;
  }

  Future<void> _showStakeDecisionDialog(DuelSession session) async {
    final DuelStakeOffer offer = session.stakeOffer;
    final String proposer = _displayNameUpper(session, offer.proposedBy ?? '');
    final bool isRematchOffer = session.status == DuelGameStatus.finished;
    final bool isCounterProposal =
        session.invitedRefusalCount >= 2 &&
        offer.proposedBy != session.hostId &&
        session.status == DuelGameStatus.waiting;
    final int myCredits = _creditsOf(session, _controller.localPlayerId);
    final bool insufficient = myCredits < offer.amount;
    _stakeDialogOpen = true;
    final String? decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return GamePopupDialog(
          title: isCounterProposal ? 'CONTRE-PROPOSITION' : 'PROPOSITION',
          subtitle: isRematchOffer
              ? '$proposer veut prendre sa revanche avec une mise de ${offer.amount}'
              : (isCounterProposal
                  ? '$proposer veut plutôt parier ${offer.amount}'
                  : '$proposer propose une mise de ${offer.amount}'),
          child: const PremiumCardStack(count: 2, rankLabel: '8'),
          actions: <Widget>[
            GamePopupButton(
              label: 'QUITTER',
              onPressed: () => Navigator.of(dialogContext).pop('quit'),
              expanded: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: GamePopupButton(
                    label: 'REFUSER',
                    onPressed: () => Navigator.of(dialogContext).pop('refuse'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GamePopupButton(
                    label: 'ACCEPTER',
                    onPressed: insufficient ? null : () => Navigator.of(dialogContext).pop('accept'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    _stakeDialogOpen = false;
    if (decision == 'quit') {
      await _exitPartyFlow();
      return;
    }
    if (decision == null || _stakeActionBusy) {
      if (insufficient) {
        _showStakeRequiredMessage('Solde insuffisant');
      }
      return;
    }
    if (decision == 'refuse' && insufficient) {
      _showStakeRequiredMessage('Solde insuffisant');
      await _controller.respondToStake(false, insufficientFunds: true);
      return;
    }
    final bool accepted = decision == 'accept';
    setState(() {
      _stakeActionBusy = true;
    });
    try {
      await _controller.respondToStake(accepted);
    } finally {
      if (mounted) {
        setState(() {
          _stakeActionBusy = false;
        });
      }
    }
    if (!accepted && mounted && _isLocalLoser(session)) {
      await _openStakeProposal(session);
    }
  }

  void _maybeHandleStakeFlow(DuelSession session) {
    if (!_isCreditsMode || !session.isCreditsMode) {
      return;
    }
    final DuelStakeOffer offer = session.stakeOffer;
    if (!offer.isPending || offer.proposedBy == _controller.localPlayerId) {
      return;
    }
    final String key =
        '${offer.proposedBy}_${offer.amount}_${offer.createdAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastStakeOfferKey == key) {
      return;
    }
    if (_winDialogOpen) {
      _pendingStakeOfferAfterVictoryKey = key;
      return;
    }
    if (_isBlockingDialogOpen()) {
      return;
    }
    _lastStakeOfferKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showStakeDecisionDialog(session);
    });
  }

  Future<void> _showStakeRejectedDialog(DuelSession session) async {
    final DuelStakeOffer offer = session.stakeOffer;
    final String proposerId = offer.proposedBy ?? '';
    if (proposerId.isEmpty) {
      return;
    }
    final String rejecterId = session.players.firstWhere(
      (String id) => id != proposerId,
      orElse: () => '',
    );
    final String rejecterName = rejecterId.isEmpty
        ? 'Votre adversaire'
        : _displayNameUpper(session, rejecterId);
    _stakeRejectedDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return GamePopupDialog(
          title: 'MISE REFUSÉE',
          subtitle: '$rejecterName a refusé cette mise.',
          child: const PremiumCardStack(count: 2, rankLabel: '2'),
          actions: <Widget>[
            GamePopupButton(
              label: 'QUITTER',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_exitPartyFlow());
              },
              expanded: true,
            ),
            const SizedBox(height: 8),
            GamePopupButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
              expanded: true,
            ),
          ],
        );
      },
    );
    _stakeRejectedDialogOpen = false;
  }

  void _maybeHandleStakeRejected(DuelSession session) {
    if (!_isCreditsMode || _isBlockingDialogOpen()) {
      return;
    }
    final DuelStakeOffer offer = session.stakeOffer;
    if (offer.status != DuelStakeStatus.declined ||
        offer.proposedBy != _controller.localPlayerId) {
      return;
    }
    final String key =
        '${offer.proposedBy}_${offer.amount}_${offer.createdAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastStakeRejectedKey == key) {
      return;
    }
    _lastStakeRejectedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showStakeRejectedDialog(session);
    });
  }

  void _maybeHandleInsufficientFunds(DuelSession session) {
    if (!_isCreditsMode || _isBlockingDialogOpen()) {
      return;
    }
    final DuelStakeOffer offer = session.stakeOffer;
    if (offer.status != DuelStakeStatus.insufficientFunds ||
        offer.proposedBy != _controller.localPlayerId) {
      return;
    }
    final String insufficientId = session.lastInsufficientFundsPlayerId ?? offer.acceptedBy ?? '';
    final String key =
        '${offer.proposedBy}_${offer.amount}_${offer.createdAt?.millisecondsSinceEpoch ?? 0}_$insufficientId';
    if (_lastInsufficientFundsKey == key) {
      return;
    }
    _lastInsufficientFundsKey = key;
    final String playerName = insufficientId.isEmpty
        ? 'Votre adversaire'
        : _displayNameUpper(session, insufficientId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_sfx.playError());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$playerName n’a pas cette somme.')),
      );
    });
  }

  void _maybePromptMandatoryStake(DuelSession session) {
    final bool shouldPromptInInitial = session.status == DuelGameStatus.waiting &&
        session.activeStakeCredits <= 0 &&
        !session.stakeOffer.isPending &&
        ((session.invitedRefusalCount < 2 && _controller.localPlayerId == session.hostId) ||
            (session.invitedRefusalCount >= 2 && _controller.localPlayerId != session.hostId));
    final bool shouldPrompt =
        shouldPromptInInitial || _requiresStake(session) || _canPromptRematchStake(session);
    if (!shouldPrompt ||
        _stakeActionBusy ||
        _isBlockingDialogOpen() ||
        session.stakeOffer.isPending) {
      return;
    }
    final String promptKey = '${session.round}_${session.rematchRequestedAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastMandatoryStakePromptKey == promptKey) {
      return;
    }
    _lastMandatoryStakePromptKey = promptKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _openStakeProposal(session);
    });
  }

  Future<void> _onReplayTap() async {
    if (_rematchActionBusy) {
      return;
    }
    final DuelSession? session = _controller.session;
    if (session == null ||
        session.status != DuelGameStatus.finished ||
        !_isLocalLoser(session)) {
      return;
    }
    if (session.rematchRequestBy == _controller.localPlayerId) {
      return;
    }
    setState(() {
      _rematchActionBusy = true;
    });
    try {
      await _controller.requestRematch();
      final DuelSession? latest = _controller.session;
      if (latest != null) {
        await _openStakeProposal(latest);
      }
    } finally {
      if (mounted) {
        setState(() {
          _rematchActionBusy = false;
        });
      }
    }
  }

  Future<void> _exitPartyFlow() async {
    final DuelSession? session = _controller.session;
    if (session == null || !_isCreditsMode) {
      return;
    }
    await _controller.exitBetParty();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> _showRematchConfirmDialog({
    required DuelSession session,
    required String requesterId,
  }) async {
    final String requester = _displayNameUpper(session, requesterId);
    _rematchDialogOpen = true;
    final bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return GamePopupDialog(
          title: 'REJOUER ?',
          subtitle: '$requester veut prendre sa revanche',
          child: const PremiumCardStack(count: 2, rankLabel: '8'),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: GamePopupButton(
                    label: 'NON',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GamePopupButton(
                    label: 'OUI',
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    _rematchDialogOpen = false;
    if (accepted == null || _rematchActionBusy) {
      return;
    }
    setState(() {
      _rematchActionBusy = true;
    });
    try {
      await _controller.respondToRematch(accepted);
    } finally {
      if (mounted) {
        setState(() {
          _rematchActionBusy = false;
        });
      }
    }
  }

  void _maybeHandleRematchFlow(DuelSession session) {
    if (_isCreditsMode) {
      return;
    }
    if (_didNavigateHomeAfterDecline) {
      return;
    }
    if (session.rematchDecision == DuelRematchDecision.declined) {
      _didNavigateHomeAfterDecline = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      });
      return;
    }
    final String? requesterId = session.rematchRequestBy;
    if (requesterId == null ||
        requesterId.isEmpty ||
        requesterId == _controller.localPlayerId ||
        session.status != DuelGameStatus.finished ||
        _isBlockingDialogOpen()) {
      return;
    }
    final String requestKey = '${requesterId}_${session.rematchRequestedAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastRematchRequestKey == requestKey) {
      return;
    }
    if (_winDialogOpen) {
      _pendingRematchAfterVictoryKey = requestKey;
      return;
    }
    if (_isBlockingDialogOpen()) {
      return;
    }
    _lastRematchRequestKey = requestKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showRematchConfirmDialog(session: session, requesterId: requesterId);
    });
  }

  void _maybeHandlePartyExit(DuelSession session) {
    if (!_isCreditsMode || session.betFlowState != DuelBetFlowState.partyExited) {
      return;
    }
    final String key = '${session.round}_${session.exitedBy ?? ''}';
    if (_lastExitKey == key) {
      return;
    }
    _lastExitKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    });
  }

  Future<void> _showWinPopup({required int gainAmount}) async {
    _winDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return GamePopupDialog(
          title: 'VICTOIRE',
          subtitle: 'Vous avez gagné $gainAmount',
          child: const PremiumCardStack(count: 3, rankLabel: 'A', suit: '♠'),
          actions: <Widget>[
            GamePopupButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
              expanded: true,
            ),
          ],
        );
      },
    );
    _winDialogOpen = false;
    _drainDialogsAfterVictory();
  }

  void _drainDialogsAfterVictory() {
    if (!mounted) {
      return;
    }
    final DuelSession? session = _controller.session;
    if (session == null || _isBlockingDialogOpen()) {
      return;
    }
    if (_pendingStakeOfferAfterVictoryKey != null) {
      _pendingStakeOfferAfterVictoryKey = null;
      _maybeHandleStakeFlow(session);
      return;
    }
    if (_pendingRematchAfterVictoryKey != null) {
      _pendingRematchAfterVictoryKey = null;
      _maybeHandleRematchFlow(session);
    }
  }

  void _maybeShowWinPopup(DuelSession session) {
    if (!_isCreditsMode ||
        session.status != DuelGameStatus.finished ||
        !_isLocalWinner(session) ||
        _isBlockingDialogOpen()) {
      return;
    }
    final String? winnerId = _winnerId(session);
    final String key =
        '${session.gameId}_${session.round}_${session.lastAction?.createdAt.toIso8601String() ?? ''}_$winnerId';
    if (_lastWinPopupKey == key) {
      return;
    }
    _lastWinPopupKey = key;
    final int gainAmount = session.stakeOffer.amount * 2;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _showWinPopup(gainAmount: gainAmount);
    });
  }

  ({String status, String overlay}) _personalizedTexts(
    DuelSession session,
    DuelBoardState board,
  ) {
    final DuelAction? action = session.lastAction;
    if (session.status == DuelGameStatus.finished) {
      final String? winnerId = action?.payload['winnerId'] as String?;
      if (winnerId == _controller.localPlayerId) {
        return (status: 'vous avez gagné', overlay: 'vous avez gagné');
      }
      if (winnerId != null && winnerId.isNotEmpty) {
        return (status: 'vous avez perdu', overlay: 'vous avez perdu');
      }
    }
    if (action == null) {
      return (status: board.status, overlay: board.overlay);
    }
    if (action.type == DuelActionType.resetRound) {
      return (status: '', overlay: '');
    }
    if (action.type == DuelActionType.drawCard) {
      final bool isForcedDraw = action.payload['forcedDraw'] == true;
      if (isForcedDraw && action.actorId == _controller.localPlayerId && board.pendingDraw > 0) {
        final String reminder = _forcedDrawReminder(board.pendingDraw);
        return (status: reminder, overlay: reminder);
      }
      if (isForcedDraw && action.actorId != _controller.localPlayerId) {
        final String actorName = _displayNameUpper(session, action.actorId);
        final int forcedTotal = (action.payload['forcedTotal'] as num?)?.toInt() ?? 0;
        if (board.pendingDraw > 0) {
          final String reminder = _forcedDrawReminder(board.pendingDraw).toLowerCase();
          final String text = '$actorName a pioché — $reminder';
          return (status: text, overlay: text);
        }
        final String finished = forcedTotal > 1
            ? '$actorName a fini de piocher ses $forcedTotal cartes'
            : '$actorName a fini de piocher sa carte';
        return (status: finished, overlay: finished);
      }
      if (action.actorId == _controller.localPlayerId) {
        return (status: 'vous avez pioché', overlay: 'vous avez pioché');
      }
      final String actorName = _displayNameUpper(session, action.actorId);
      return (status: '$actorName a pioché', overlay: '$actorName a pioché');
    }
    final DuelCard? card = (action.payload['cardId'] as String?) != null
        ? DuelCard.fromId(action.payload['cardId'] as String)
        : null;
    final bool isMe = action.actorId == _controller.localPlayerId;
    if (card == null) {
      return (status: board.status, overlay: board.overlay);
    }
    if (card.rank == '8') {
      final String suit = action.payload['chosenSuit'] as String? ?? '';
      return isMe
          ? (
              status: suit.isEmpty ? 'vous avez commandé' : 'vous avez commandé $suit',
              overlay: suit.isEmpty ? 'vous avez commandé' : 'vous avez commandé $suit',
            )
          : (
              status: suit.isEmpty
                  ? '${_displayNameUpper(session, action.actorId)} a commandé'
                  : '${_displayNameUpper(session, action.actorId)} a commandé $suit',
              overlay: suit.isEmpty
                  ? '${_displayNameUpper(session, action.actorId)} a commandé'
                  : '${_displayNameUpper(session, action.actorId)} a commandé $suit',
            );
    }
    if (card.rank == '2' || card.isJoker) {
      final int forcedAmount = board.pendingDraw;
      if (_controller.isMyTurn && !isMe && forcedAmount > 0) {
        final String forcedText = _forcedDrawReminder(forcedAmount);
        return (status: 'vous devez piocher $forcedAmount cartes', overlay: forcedText);
      }
    }
    if (isMe) {
      return (status: 'vous avez joué ${card.label}', overlay: 'vous avez joué ${card.label}');
    }
    final String actorName = _displayNameUpper(session, action.actorId);
    return (status: '$actorName a joué ${card.label}', overlay: '$actorName a joué ${card.label}');
  }

  String _forcedDrawReminder(int remaining) {
    if (remaining <= 1) {
      return 'Encore 1 carte à piocher';
    }
    return 'Encore $remaining cartes à piocher';
  }

  Color _suitColor(String suit) {
    return _suitGlyphColor(suit);
  }

  String _suitToName(String suit) {
    switch (suit) {
      case '♣':
        return 'Trèfle';
      case '♦':
        return 'Carreau';
      case '♠':
        return 'Pique';
      case '♥':
        return 'Cœur';
      default:
        return suit;
    }
  }

  Future<void> _openChatPanel(DuelSession session) async {
    unawaited(_sfx.playPopup());
    setState(() {
      _isChatOpen = true;
      _unreadChatCount = 0;
      _activeChatPreview = null;
    });
    _chatPreviewQueue.clear();
    _chatPreviewTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DuelChatPanel(
          messagesListenable: _chatMessagesNotifier,
          localPlayerId: _controller.localPlayerId,
          chatEnabled: session.players.length == 2,
          errorText: _chatError,
          quickMessages: _quickMessages,
          onSend: _handleSendChatMessage,
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isChatOpen = false;
    });
  }

  Future<void> _handleSendChatMessage(String text) async {
    final DuelSession? session = _controller.session;
    if (session == null || session.players.length < 2) {
      return;
    }
    try {
      await _controller.sendChatMessage(text);
    } catch (_) {
      if (!mounted) {
        return;
      }
      unawaited(_sfx.playError());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message non envoyé. Réessaie.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final DuelSession? session = _controller.session;
        final DuelBoardState? board = _board;
        if (session == null || board == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final String opponentId = session.players.firstWhere(
          (String id) => id != _controller.localPlayerId,
          orElse: () => '',
        );
        final String opponentName = opponentId.isEmpty
            ? 'JOUEUR 2'
            : _displayNameUpper(session, opponentId);
        final String localName = _displayNameUpper(
          session,
          _controller.localPlayerId,
        );
        final int myScore = session.scores[_controller.localPlayerId] ?? 0;
        final int opponentScore = session.scores[opponentId] ?? 0;
        final int myCredits = _creditsOf(session, _controller.localPlayerId);
        final DuelCard localAvatarCard = _avatarCardForPlayer(
          _controller.localPlayerId,
        );
        final DuelCard opponentAvatarCard = opponentId.isEmpty
            ? _avatarCardForPlayer(opponentId)
            : _avatarCardForOpponent(
                localPlayerId: _controller.localPlayerId,
                opponentId: opponentId,
              );
        final DuelStakeOffer stakeOffer = session.stakeOffer;
        final bool myTurn = _controller.isMyTurn &&
            session.status == DuelGameStatus.inProgress &&
            !_requiresStake(session);
        final ({String status, String overlay}) texts = _personalizedTexts(session, board);
        final double topInset = MediaQuery.paddingOf(context).top;
        return Scaffold(
          backgroundColor: PremiumColors.tableGreenDark,
          body: Stack(
            children: <Widget>[
              TableBackground(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, topInset + 2, 12, 10),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              Navigator.of(context).popUntil(
                                (Route<dynamic> route) => route.isFirst,
                              );
                            },
                            tooltip: 'Retour aux modes',
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const AppLogo(size: 74),
                                const SizedBox(height: 1),
                                Text(
                                  _isCreditsMode ? 'Duel Paris' : 'Duel',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              DuelChatButton(
                                unreadCount: _unreadChatCount,
                                enabled: session.players.length == 2,
                                onPressed: () {
                                  unawaited(_sfx.playClick());
                                  _openChatPanel(session);
                                },
                              ),
                              if (_activeChatPreview != null)
                                Positioned(
                                  right: 54,
                                  top: 0,
                                  child: _DuelChatPreviewBubble(text: _activeChatPreview!),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_isCreditsMode) ...<Widget>[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    size: 16,
                                    color: Color(0xFFFFD45F),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$myCredits',
                                    style: const TextStyle(
                                      color: Color(0xFFFFE8A0),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      _DuelStatusBanner(
                        opponentName: opponentName,
                        myScore: myScore,
                        opponentScore: opponentScore,
                        round: session.round,
                      ),
                      if (_isCreditsMode) ...<Widget>[
                        const SizedBox(height: 6),
                        _CreditsStakeBanner(
                          activeStakeCredits: session.activeStakeCredits,
                          playerStakeCredits: session.stakeOffer.amount,
                          stakeText: _requiresStake(session)
                              ? switch (stakeOffer.status) {
                                  DuelStakeStatus.pending =>
                                    'Proposition en attente : ${stakeOffer.amount}',
                                  DuelStakeStatus.declined =>
                                    'Proposition refusée. Faites un nouveau pari.',
                                  DuelStakeStatus.insufficientFunds =>
                                    'Solde insuffisant détecté. Proposez une autre mise.',
                                  DuelStakeStatus.none ||
                                  DuelStakeStatus.accepted ||
                                  DuelStakeStatus.resolved =>
                                    'Pari obligatoire avant de jouer.',
                                }
                              : null,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _OpponentRow(
                        name: opponentName,
                        count: board.handOf(opponentId).length,
                        wins: opponentScore,
                        losses: myScore,
                        fallbackInitial: opponentName.isNotEmpty ? opponentName[0] : '?',
                        avatarCard: opponentAvatarCard,
                      ),
                      const SizedBox(height: 8),
                      _CenterArea(
                        discard: board.discardTop,
                        drawCount: board.drawPile.length,
                        canDraw: myTurn && board.canDraw(_controller.localPlayerId),
                        onDrawTap: _onDrawTap,
                        overlay: texts.overlay,
                        requiredSuit: board.requiredSuit,
                        mustDraw: myTurn && board.pendingDraw > 0,
                      ),
                      const SizedBox(height: 8),
                      _MyHandRow(
                        cards: board.handOf(_controller.localPlayerId),
                        canInteract: myTurn,
                        onCardTap: _onCardTap,
                        playable: (DuelCard card) =>
                            myTurn && board.canPlay(_controller.localPlayerId, card),
                        profileName: localName,
                        wins: myScore,
                        losses: opponentScore,
                        credits: null,
                        fallbackInitial: localName.isNotEmpty ? localName[0] : '?',
                        avatarCard: localAvatarCard,
                      ),
                      const SizedBox(height: 6),
                      _ActionMessageCard(
                        session: session,
                        localPlayerId: _controller.localPlayerId,
                      ),
                      if (_isCreditsMode &&
                          session.status == DuelGameStatus.waiting &&
                          session.players.length == 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: _stakeActionBusy ||
                                    stakeOffer.isPending ||
                                    !_canSetStake(session)
                                ? null
                                : () => _openStakeProposal(session),
                            icon: const Icon(Icons.local_offer_outlined),
                            label: const Text('Faire un pari'),
                          ),
                        ),
                      if (session.status == DuelGameStatus.finished &&
                          _isLocalLoser(session) &&
                          session.rematchDecision != DuelRematchDecision.accepted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              _onReplayTap();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              session.rematchRequestBy == _controller.localPlayerId &&
                                      session.rematchDecision ==
                                          DuelRematchDecision.pending
                                  ? 'EN ATTENTE...'
                                  : 'PRENDRE SA REVANCHE',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: GlobalMusicToggleButton(
                    margin: EdgeInsets.only(right: 10, bottom: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DuelChatButton extends StatelessWidget {
  const DuelChatButton({
    super.key,
    required this.onPressed,
    required this.unreadCount,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final int unreadCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color base = Colors.white.withOpacity(enabled ? 0.22 : 0.12);
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 48,
        height: 42,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Center(
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -5,
                top: -5,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 180),
                  tween: Tween<double>(begin: 0.92, end: 1),
                  curve: Curves.easeOut,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D5A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white70, width: 1),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuelChatPreviewBubble extends StatelessWidget {
  const _DuelChatPreviewBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final String preview = text.length > 46 ? '${text.substring(0, 43)}…' : text;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      tween: Tween<double>(begin: 0.96, end: 1),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(scale: value, alignment: Alignment.topRight, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xE2263F36),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: 12,
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xE2263F36),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DuelChatPanel extends StatefulWidget {
  const DuelChatPanel({
    super.key,
    required this.messagesListenable,
    required this.localPlayerId,
    required this.chatEnabled,
    required this.onSend,
    required this.quickMessages,
    this.errorText,
  });

  final ValueListenable<List<DuelChatMessage>> messagesListenable;
  final String localPlayerId;
  final bool chatEnabled;
  final Future<void> Function(String text) onSend;
  final List<String> quickMessages;
  final String? errorText;

  @override
  State<DuelChatPanel> createState() => _DuelChatPanelState();
}

class _DuelChatPanelState extends State<DuelChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  int _lastRenderedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoScroll(animated: false));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText([String? value]) async {
    if (_sending || !widget.chatEnabled) {
      return;
    }
    final String text = (value ?? _inputController.text).trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
    });
    _inputController.clear();
    try {
      await widget.onSend(text);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scheduleAutoScroll({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final double target = _scrollController.position.maxScrollExtent + 80;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
        return;
      }
      _scrollController.jumpTo(target);
    });
  }

  List<DuelChatMessage> _normalizeMessages(List<DuelChatMessage> raw) {
    final Map<String, DuelChatMessage> dedup = <String, DuelChatMessage>{
      for (final DuelChatMessage message in raw) message.id: message,
    };
    final List<DuelChatMessage> ordered = dedup.values.toList()
      ..sort((DuelChatMessage a, DuelChatMessage b) => a.createdAt.compareTo(b.createdAt));
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets keyboard = EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: keyboard,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 470),
          decoration: const BoxDecoration(
            color: Color(0xFF0D3C31),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                child: Row(
                  children: <Widget>[
                    const Text(
                      'Chat duel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (widget.errorText != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Chat indisponible pour le moment.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              Expanded(
                child: ValueListenableBuilder<List<DuelChatMessage>>(
                  valueListenable: widget.messagesListenable,
                  builder: (
                    BuildContext context,
                    List<DuelChatMessage> rawMessages,
                    Widget? _,
                  ) {
                    final List<DuelChatMessage> messages = _normalizeMessages(rawMessages);
                    final int currentCount = messages.length;
                    if (currentCount > _lastRenderedMessageCount) {
                      _scheduleAutoScroll(animated: true);
                    }
                    _lastRenderedMessageCount = currentCount;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      itemCount: messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final DuelChatMessage message = messages[index];
                        return ChatMessageBubble(
                          message: message,
                          isMine: message.senderId == widget.localPlayerId,
                        );
                      },
                    );
                  },
                ),
              ),
              QuickMessageBar(
                messages: widget.quickMessages,
                enabled: widget.chatEnabled && !_sending,
                onSelect: (String value) => _sendText(value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendText(),
                        enabled: widget.chatEnabled && !_sending,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: widget.chatEnabled
                              ? 'Écrire un message...'
                              : 'Chat indisponible',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          hintStyle: const TextStyle(color: Colors.white60),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: widget.chatEnabled && !_sending ? () => _sendText() : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2BC991),
                        foregroundColor: const Color(0xFF093024),
                        minimumSize: const Size(48, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final DuelChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment alignment =
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final Color bubbleColor =
        isMine ? const Color(0xFFBDF2D5) : Colors.white.withOpacity(0.12);
    final Color textColor = isMine ? const Color(0xFF083729) : Colors.white;
    final String minute = message.createdAt.minute.toString().padLeft(2, '0');
    final String hour = message.createdAt.hour.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: alignment,
            children: <Widget>[
              if (!isMine && message.senderName.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
          child: Text(
            '$hour:$minute',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class QuickMessageBar extends StatelessWidget {
  const QuickMessageBar({
    super.key,
    required this.messages,
    required this.onSelect,
    required this.enabled,
  });

  final List<String> messages;
  final ValueChanged<String> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final String value = messages[index];
          return ActionChip(
            onPressed: enabled ? () => onSelect(value) : null,
            backgroundColor: Colors.white.withOpacity(0.08),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: messages.length,
      ),
    );
  }
}

class DuelCard {
  const DuelCard({required this.suit, required this.rank});

  final String suit;
  final String rank;

  bool get isJoker => rank == 'JK';

  bool get canFinishGame => rank != '10' && rank != 'J';

  String get id => '$rank$suit';

  bool get isRed => suit == '♥' || suit == '♦';

  bool isSameColorAsSuit(String suitRef) {
    final bool refIsRed = suitRef == '♥' || suitRef == '♦';
    return isRed == refIsRed;
  }

  bool matches(DuelCard other) {
    if (isJoker || other.isJoker) {
      return true;
    }
    return suit == other.suit || rank == other.rank;
  }

  String get label => isJoker ? 'Joker ${isRed ? 'rouge' : 'noir'}' : '$rank$suit';

  static DuelCard fromId(String value) {
    if (value.startsWith('JK')) {
      return DuelCard(suit: value.substring(2), rank: 'JK');
    }
    return DuelCard(suit: value.substring(value.length - 1), rank: value.substring(0, value.length - 1));
  }

  static DuelCard fromMap(Map<String, dynamic> json) {
    final String? rank = json['rank'] as String?;
    final String? suit = json['suit'] as String?;
    final String? cardId = json['id'] as String?;
    if (rank != null && suit != null) {
      return DuelCard(rank: rank, suit: suit);
    }
    if (cardId != null && cardId.isNotEmpty) {
      return DuelCard.fromId(cardId);
    }
    throw ArgumentError('Carte de duel invalide : $json');
  }
}

class DuelMoveResult {
  const DuelMoveResult({
    required this.accepted,
    this.payload = const <String, dynamic>{},
    this.nextTurn,
  });

  final bool accepted;
  final Map<String, dynamic> payload;
  final String? nextTurn;
}

class DuelBoardState {
  DuelBoardState._({
    required this.gameId,
    required this.players,
    required this.drawPile,
    required this.discardPile,
    required this.hands,
    required this.discardTop,
    required this.requiredSuit,
    required this.pendingDraw,
    required this.forcedDrawInitial,
    required this.aceColorRequired,
    required this.overlay,
    required this.status,
    required this.round,
  });

  final String gameId;
  final List<String> players;
  final List<DuelCard> drawPile;
  final List<DuelCard> discardPile;
  final Map<String, List<DuelCard>> hands;
  final DuelCard discardTop;
  final String? requiredSuit;
  final int pendingDraw;
  final int forcedDrawInitial;
  final bool aceColorRequired;
  final String overlay;
  final String status;
  final int round;

  factory DuelBoardState.initial({
    required String gameId,
    required List<String> players,
    required int round,
  }) {
    final Random random = Random('$gameId#$round'.hashCode);
    final List<DuelCard> deck = <DuelCard>[
      for (final String suit in <String>['♥', '♠', '♦', '♣'])
        for (int rank = 1; rank <= 13; rank++)
          DuelCard(suit: suit, rank: _rankToLabel(rank)),
      const DuelCard(suit: '♦', rank: 'JK'),
      const DuelCard(suit: '♣', rank: 'JK'),
    ]..shuffle(random);

    final Map<String, List<DuelCard>> hands = <String, List<DuelCard>>{
      for (final String player in players) player: <DuelCard>[],
    };
    for (int i = 0; i < 7; i++) {
      for (final String player in players) {
        hands[player]!.add(deck.removeLast());
      }
    }

    DuelCard top = deck.removeLast();
    while (top.rank == '8' || top.rank == 'JK') {
      deck.insert(0, top);
      top = deck.removeLast();
    }

    return DuelBoardState._(
      gameId: gameId,
      players: players,
      drawPile: deck,
      discardPile: <DuelCard>[top],
      hands: hands,
      discardTop: top,
      requiredSuit: null,
      pendingDraw: 0,
      forcedDrawInitial: 0,
      aceColorRequired: false,
      overlay: '',
      status: '',
      round: round,
    );
  }

  DuelBoardState rebuildFromActions(List<DuelAction> actions) {
    DuelBoardState state = this;
    for (final DuelAction action in actions) {
      state = state._apply(action);
    }
    return state;
  }

  List<DuelCard> handOf(String playerId) => hands[playerId] ?? <DuelCard>[];

  bool canPlay(String actorId, DuelCard card) {
    if (!handOf(actorId).any((DuelCard c) => c.id == card.id)) {
      return false;
    }
    if (pendingDraw > 0) {
      return false;
    }
    if (aceColorRequired) {
      return card.rank == 'A' || (card.isJoker && card.isSameColor(discardTop));
    }
    if (card.rank == '8') {
      return true;
    }
    if (card.isJoker) {
      final String colorRefSuit = requiredSuit ?? discardTop.suit;
      if (requiredSuit != null) {
        return false;
      }
      return card.isSameColorAsSuit(colorRefSuit);
    }
    if (requiredSuit != null) {
      return card.suit == requiredSuit || (card.rank == discardTop.rank && card.rank != 'JK');
    }
    return card.matches(discardTop);
  }

  bool canDraw(String actorId) => drawPile.isNotEmpty || discardPile.length > 1;

  DuelMoveResult tryPlay({
    required String actorId,
    required DuelCard card,
    String? chosenSuit,
  }) {
    if (!canPlay(actorId, card)) {
      return const DuelMoveResult(accepted: false);
    }
    final String? suitChoice = card.rank == '8' ? chosenSuit : null;
    final List<DuelCard> actorHand = handOf(actorId);
    final bool triesToFinish = actorHand.length == 1;
    if (triesToFinish && !card.canFinishGame) {
      return const DuelMoveResult(accepted: false);
    }
    final bool winsNow = triesToFinish && card.canFinishGame;
    final String next = winsNow
        ? actorId
        : _nextPlayer(actorId, skip: card.rank == '10' || card.rank == 'J');
    return DuelMoveResult(
      accepted: true,
      nextTurn: next,
      payload: <String, dynamic>{
        'cardId': card.id,
        if (suitChoice != null) 'chosenSuit': suitChoice,
        if (winsNow) 'winnerId': actorId,
      },
    );
  }

  DuelMoveResult tryDraw({required String actorId}) {
    if (!canDraw(actorId)) {
      return const DuelMoveResult(accepted: false);
    }
    final bool forced = pendingDraw > 0;
    final int count = 1;
    final int remainingAfterDraw = forced ? max(0, pendingDraw - count) : 0;
    final int forcedTotal = forced ? (forcedDrawInitial > 0 ? forcedDrawInitial : pendingDraw) : 0;
    return DuelMoveResult(
      accepted: true,
      nextTurn: forced && remainingAfterDraw > 0 ? actorId : _nextPlayer(actorId),
      payload: <String, dynamic>{
        'count': count,
        if (forced) 'forcedDraw': true,
        if (forced) 'forcedTotal': forcedTotal,
      },
    );
  }

  DuelBoardState _apply(DuelAction action) {
    final Map<String, List<DuelCard>> newHands = <String, List<DuelCard>>{
      for (final MapEntry<String, List<DuelCard>> e in hands.entries)
        e.key: List<DuelCard>.from(e.value),
    };
    final List<DuelCard> newPile = List<DuelCard>.from(drawPile);
    final List<DuelCard> newDiscardPile = List<DuelCard>.from(discardPile);
    DuelCard newTop = discardTop;
    String? newRequiredSuit = requiredSuit;
    int newPendingDraw = pendingDraw;
    int newForcedDrawInitial = forcedDrawInitial;
    bool newAceRequired = aceColorRequired;
    String newOverlay = overlay;
    String newStatus = status;
    final int reshuffleSeedBase = Object.hash(
      action.type.name,
      action.actorId,
      action.createdAt.microsecondsSinceEpoch,
    );

    if (action.type == DuelActionType.drawCard) {
      final int count = (action.payload['count'] as int?) ?? 1;
      final int amount = count.clamp(1, 9);
      if (newPile.isEmpty) {
        _rebuildDrawPile(newPile, newDiscardPile, reshuffleSeedBase);
      }
      for (int i = 0; i < amount && newPile.isNotEmpty; i++) {
        newHands[action.actorId]?.add(newPile.removeLast());
        if (newPile.isEmpty && i < amount - 1) {
          _rebuildDrawPile(
            newPile,
            newDiscardPile,
            Object.hash(reshuffleSeedBase, i),
          );
        }
      }
      if (newPendingDraw > 0) {
        newPendingDraw = max(0, newPendingDraw - amount);
        if (newPendingDraw == 0) {
          newForcedDrawInitial = 0;
        }
      }
      newAceRequired = false;
      newOverlay = '${action.actorId} pioche';
      newStatus = newPendingDraw > 0
          ? '$newPendingDraw cartes à piocher'
          : '${action.actorId} a pioché.';
    }

    if (action.type == DuelActionType.playCard) {
      final DuelCard card = DuelCard.fromId(action.payload['cardId'] as String);
      newHands[action.actorId]?.removeWhere((DuelCard c) => c.id == card.id);
      newTop = card;
      newDiscardPile.add(card);
      newRequiredSuit = null;
      newOverlay = '${action.actorId} a joué ${card.label}';
      newStatus = newOverlay;

      if (card.rank == '8') {
        newRequiredSuit = action.payload['chosenSuit'] as String? ?? '♥';
        newOverlay = '${action.actorId} a commandé $newRequiredSuit';
        newStatus = 'Couleur demandée: $newRequiredSuit';
      } else if (card.rank == '2') {
        newPendingDraw += 3;
        newForcedDrawInitial = newPendingDraw;
        newOverlay = '+3';
        newStatus = '$newPendingDraw cartes à piocher';
      } else if (card.isJoker) {
        newPendingDraw += 8;
        newForcedDrawInitial = newPendingDraw;
        newOverlay = '+8';
        newStatus = '$newPendingDraw cartes à piocher';
      } else if (card.rank == 'A') {
        newAceRequired = !aceColorRequired;
        newOverlay = newAceRequired
            ? 'As joué: réponse As obligatoire'
            : 'Réponse As validée';
        newStatus = newOverlay;
      } else if (card.rank == '10' || card.rank == 'J') {
        newAceRequired = false;
        newOverlay = 'Tour sauté';
      } else {
        newAceRequired = false;
      }
    }

    if (action.type == DuelActionType.resetRound) {
      final int nextRound = (action.payload['round'] as num?)?.toInt() ?? (round + 1);
      return DuelBoardState.initial(
        gameId: gameId,
        players: players,
        round: nextRound,
      );
    }

    final String? winnerId = action.payload['winnerId'] as String?;
    if (winnerId != null && winnerId.isNotEmpty) {
      newPendingDraw = 0;
      newForcedDrawInitial = 0;
      newAceRequired = false;
      newRequiredSuit = null;
      newOverlay = '$winnerId a gagné';
      newStatus = '$winnerId a gagné';
    }

    return DuelBoardState._(
      gameId: gameId,
      players: players,
      drawPile: newPile,
      discardPile: newDiscardPile,
      hands: newHands,
      discardTop: newTop,
      requiredSuit: newRequiredSuit,
      pendingDraw: newPendingDraw,
      forcedDrawInitial: newForcedDrawInitial,
      aceColorRequired: newAceRequired,
      overlay: newOverlay,
      status: newStatus,
      round: round,
    );
  }

  String _nextPlayer(String actorId, {bool skip = false}) {
    if (players.length < 2) {
      return actorId;
    }
    final int idx = players.indexOf(actorId);
    if (idx == -1) {
      return players.first;
    }
    int next = (idx + 1) % players.length;
    if (skip) {
      next = (next + 1) % players.length;
    }
    return players[next];
  }

  void _rebuildDrawPile(
    List<DuelCard> pile,
    List<DuelCard> discard,
    int seed,
  ) {
    if (discard.length <= 1) {
      return;
    }
    final DuelCard topCard = discard.removeLast();
    pile.addAll(discard);
    discard
      ..clear()
      ..add(topCard);
    pile.shuffle(Random(seed));
  }
}

String _rankToLabel(int rank) {
  switch (rank) {
    case 1:
      return 'A';
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    default:
      return '$rank';
  }
}

class _DuelStatusBanner extends StatelessWidget {
  const _DuelStatusBanner({
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.round,
  });

  final String opponentName;
  final int myScore;
  final int opponentScore;
  final int round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: RichText(
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(
                      text: 'VOUS  ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '$myScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    const TextSpan(
                      text: '   :   ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    TextSpan(
                      text: '$opponentName  ',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '$opponentScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'MANCHE $round',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsStakeBanner extends StatelessWidget {
  const _CreditsStakeBanner({
    required this.activeStakeCredits,
    required this.playerStakeCredits,
    this.stakeText,
  });

  final int activeStakeCredits;
  final int playerStakeCredits;
  final String? stakeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _StakeInfoChip(
                  label: 'Mise',
                  icon: Icons.workspace_premium_rounded,
                  value: playerStakeCredits > 0 ? playerStakeCredits : 0,
                  highlighted: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StakeInfoChip(
                  label: 'Coffre',
                  icon: Icons.inventory_2_rounded,
                  value: activeStakeCredits > 0 ? activeStakeCredits : 0,
                  highlighted: true,
                ),
              ),
            ],
          ),
          if (stakeText != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              stakeText!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StakeInfoChip extends StatelessWidget {
  const _StakeInfoChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final IconData icon;
  final int value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = highlighted ? const Color(0xFF2B3E25) : Colors.white.withOpacity(0.1);
    final Color borderColor =
        highlighted ? const Color(0xAAE8C65D) : Colors.white.withOpacity(0.24);
    final Color textColor = highlighted ? const Color(0xFFFFE9A9) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({
    required this.name,
    required this.count,
    required this.wins,
    required this.losses,
    required this.fallbackInitial,
    required this.avatarCard,
  });

  final String name;
  final int count;
  final int wins;
  final int losses;
  final String fallbackInitial;
  final DuelCard avatarCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: <Widget>[
          _ProfileBlock(
            name: name,
            wins: wins,
            losses: losses,
            fallbackInitial: fallbackInitial,
            compact: true,
            avatarCard: avatarCard,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        count,
                        (int _) => const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: _DuelCardBack(width: 28, height: 40),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: _DrawCountBadge(count: count),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.name,
    required this.wins,
    required this.losses,
    required this.fallbackInitial,
    required this.avatarCard,
    this.credits,
    this.compact = false,
  });

  final String name;
  final int wins;
  final int losses;
  final int? credits;
  final String fallbackInitial;
  final DuelCard avatarCard;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double avatarSize = compact ? 34 : 42;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            child: _AvatarCardCircle(
              card: avatarCard,
              size: avatarSize,
              fallbackInitial: fallbackInitial,
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 116 : 148),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'V $wins   D $losses',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
                if (credits != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    'Crédit $credits',
                    style: TextStyle(
                      color: const Color(0xFFFFE8A0).withOpacity(0.96),
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 10 : 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCardCircle extends StatelessWidget {
  const _AvatarCardCircle({
    required this.card,
    required this.size,
    required this.fallbackInitial,
  });

  final DuelCard card;
  final double size;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final bool red = card.isRed;
    final Color ink = red ? const Color(0xFFC62828) : const Color(0xFF161616);
    final String rank = card.isJoker ? 'JK' : card.rank;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white60, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${rank.isEmpty ? fallbackInitial : rank}${card.suit}',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.32,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterArea extends StatelessWidget {
  const _CenterArea({
    required this.discard,
    required this.drawCount,
    required this.canDraw,
    required this.onDrawTap,
    required this.overlay,
    required this.requiredSuit,
    required this.mustDraw,
  });

  final DuelCard discard;
  final int drawCount;
  final bool canDraw;
  final VoidCallback onDrawTap;
  final String overlay;
  final String? requiredSuit;
  final bool mustDraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: canDraw ? onDrawTap : null,
              child: _BlinkingDrawCard(
                enabled: mustDraw,
                child: Opacity(
                  opacity: canDraw ? 1 : 0.45,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Transform.translate(
                        offset: const Offset(-4, 3),
                        child: Transform.rotate(
                          angle: -0.08,
                          child: Opacity(
                            opacity: 0.9,
                            child: const _DuelCardBack(width: 64, height: 92),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: 0.05,
                        child: const _DuelCardBack(width: 64, height: 92),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: _DrawCountBadge(count: drawCount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              children: <Widget>[
                _FaceCard(card: discard),
              ],
            ),
          ],
        ),
        if (overlay.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: _SuitOverlayText(message: overlay),
          ),
      ],
    );
  }
}


class _MyHandRow extends StatelessWidget {
  const _MyHandRow({
    required this.cards,
    required this.canInteract,
    required this.onCardTap,
    required this.playable,
    required this.profileName,
    required this.wins,
    required this.losses,
    this.credits,
    required this.fallbackInitial,
    required this.avatarCard,
  });

  final List<DuelCard> cards;
  final bool canInteract;
  final ValueChanged<DuelCard> onCardTap;
  final bool Function(DuelCard) playable;
  final String profileName;
  final int wins;
  final int losses;
  final int? credits;
  final String fallbackInitial;
  final DuelCard avatarCard;
  static const int _maxCardsPerRow = 5;
  static const double _cardGap = 6;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _ProfileBlock(
                        name: profileName,
                        wins: wins,
                        losses: losses,
                        credits: credits,
                        fallbackInitial: fallbackInitial,
                        compact: true,
                        avatarCard: avatarCard,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _TurnStateBadge(
                            text: canInteract ? 'À VOTRE TOUR' : 'PATIENTEZ',
                            blink: canInteract,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        if (cards.isEmpty) {
                          return const SizedBox.expand();
                        }

                        final double maxRowWidth =
                            (_FaceCard.width * _maxCardsPerRow) +
                            (_cardGap * (_maxCardsPerRow - 1));
                        final double wrapWidth = min(
                          constraints.maxWidth - 8,
                          maxRowWidth,
                        );

                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: wrapWidth,
                              child: Wrap(
                                spacing: _cardGap,
                                runSpacing: _cardGap,
                                children: List<Widget>.generate(cards.length, (int index) {
                                  final DuelCard card = cards[index];
                                  final bool isPlayable = playable(card);
                                  return SizedBox(
                                    width: _FaceCard.width,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: canInteract && isPlayable ? () => onCardTap(card) : null,
                                      child: Opacity(
                                        opacity: canInteract && !isPlayable ? 0.45 : 1,
                                        child: _FaceCard(card: card),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: _DrawCountBadge(count: cards.length),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionMessageCard extends StatelessWidget {
  const _ActionMessageCard({
    required this.session,
    required this.localPlayerId,
  });

  final DuelSession session;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    final DuelAction? action = session.lastAction;
    if (action == null || action.type != DuelActionType.playCard) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic>? rawCard = (action.payload['card'] as Map?)?.cast<String, dynamic>();
    if (rawCard == null) {
      return const SizedBox.shrink();
    }

    final DuelCard card = DuelCard.fromMap(rawCard);
    final bool isMe = action.actorId == localPlayerId;
    final String actorName = session.playerNames[action.actorId]?.toUpperCase() ?? 'JOUEUR';
    final String prefix = isMe ? 'Vous avez joué' : '$actorName a joué';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              prefix,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _PlayedCardMini(card: card),
        ],
      ),
    );
  }
}

class _PlayedCardMini extends StatelessWidget {
  const _PlayedCardMini({required this.card});

  final DuelCard card;

  @override
  Widget build(BuildContext context) {
    final bool red = card.isRed;
    final Color ink = red ? const Color(0xFFC62828) : const Color(0xFF1B1B1B);
    final String rank = card.isJoker ? 'JK' : card.rank;
    final String suit = card.suit;

    return SizedBox(
      width: 40,
      height: 58,
      child: DecoratedBox(
        decoration: PremiumCardEffects.bevelFace(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: card.isJoker
              ? Center(
                  child: Text(
                    'JK',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                )
              : Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            rank,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              height: 1,
                            ),
                          ),
                          _SuitGlyph(suit: suit, color: ink, size: 8),
                        ],
                      ),
                    ),
                    Center(
                      child: _SuitGlyph(suit: suit, color: ink, size: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TurnStateBadge extends StatelessWidget {
  const _TurnStateBadge({required this.text, required this.blink});

  final String text;
  final bool blink;

  @override
  Widget build(BuildContext context) {
    return _BlinkingDrawCard(
      enabled: blink,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: blink ? const Color(0x2237D66A) : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: blink ? const Color(0xFF56E17E) : const Color(0x66FFFFFF),
            width: blink ? 1.5 : 1.1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: blink ? const Color(0xFFC9FFD7) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _DrawCountBadge extends StatelessWidget {
  const _DrawCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD50000),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _BlinkingDrawCard extends StatefulWidget {
  const _BlinkingDrawCard({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_BlinkingDrawCard> createState() => _BlinkingDrawCardState();
}

class _BlinkingDrawCardState extends State<_BlinkingDrawCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant _BlinkingDrawCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBlink();
  }

  void _syncBlink() {
    if (widget.enabled) {
      _controller.repeat(reverse: true);
      return;
    }
    _controller.stop();
    _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

class _FaceCard extends StatelessWidget {
  const _FaceCard({required this.card});

  final DuelCard card;
  static const double width = 64;
  static const double height = 92;

  @override
  Widget build(BuildContext context) {
    final bool red = card.isRed;
    final Color ink = red ? const Color(0xFFC62828) : const Color(0xFF1B1B1B);
    final String rank = card.isJoker ? 'JK' : card.rank;
    final String suit = card.suit;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: PremiumCardEffects.bevelFace(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: card.isJoker
              ? Center(
                  child: Text(
                    'JOKER',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                )
              : Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(rank, style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 16, height: 1)),
                          _SuitGlyph(suit: suit, color: ink, size: 14),
                        ],
                      ),
                    ),
                    Center(
                      child: _SuitGlyph(suit: suit, color: ink, size: 34),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: RotatedBox(
                        quarterTurns: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              rank,
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1,
                              ),
                            ),
                            _SuitGlyph(suit: suit, color: ink, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SuitGlyph extends StatelessWidget {
  const _SuitGlyph({
    required this.suit,
    required this.color,
    required this.size,
  });

  final String suit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double scale = switch (suit) {
      '♥' => 0.88,
      '♦' => 0.94,
      '♣' => 0.92,
      '♠' => 0.96,
      _ => 1,
    };
    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: Text(
        suit,
        strutStyle: const StrutStyle(forceStrutHeight: true, height: 1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1,
        ),
      ),
    );
  }
}


class _SuitOverlayText extends StatelessWidget {
  const _SuitOverlayText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    final String lastChar = message.substring(message.length - 1);
    if (!const <String>{'♣', '♦', '♥', '♠'}.contains(lastChar)) {
      return Text(message, style: const TextStyle(color: Colors.white));
    }
    final String text = message.substring(0, message.length - lastChar.length).trimRight();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          lastChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

Color _suitGlyphColor(String suit) {
  switch (suit) {
    case '♥':
    case '♦':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF0B2B1E);
  }
}

String _duelStatusLabel(DuelGameStatus status) {
  switch (status) {
    case DuelGameStatus.waiting:
      return 'en attente';
    case DuelGameStatus.inProgress:
      return 'en cours';
    case DuelGameStatus.finished:
      return 'terminée';
  }
}

class _DuelCardBack extends StatelessWidget {
  const _DuelCardBack({this.width = 52, this.height = 74});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: PremiumCardEffects.bevelBack(
        borderRadius: BorderRadius.circular(10),
        image: const DecorationImage(
          image: AssetImage('assets/img/card_back.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
