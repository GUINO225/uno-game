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
import 'credit_coins_icon.dart';
import 'firebase_config.dart';
import 'game_history_page.dart';
import 'leaderboard_page.dart';
import 'player_profile.dart';
import 'player_side_panel.dart';
import 'premium_ui.dart';
import 'stats_service.dart';
import 'user_profile_service.dart';
import 'widgets/bouncy_card_entry.dart';
import 'widgets/funny_game_toast.dart';
import 'widgets/gino_popups.dart';
import 'web_page_lifecycle_stub.dart'
    if (dart.library.html) 'web_page_lifecycle_web.dart';

enum DuelGameStatus { waiting, inProgress, finished }

enum DuelActionType { playCard, drawCard, resetRound, forfeit }

enum DuelRematchDecision { pending, accepted, declined }

enum DuelChatDelivery { sending, sent, failed }

enum DuelRoomMode { duel, credits }

const Duration _presenceGracePeriod = Duration(seconds: 20);
const Duration _connectionWarningTimeout = Duration(seconds: 25);
const Duration _abandonTimeout = Duration(seconds: 45);
const Duration _presenceHeartbeatInterval = Duration(seconds: 8);

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

const Duration _kRematchRequestTimeout = Duration(seconds: 45);

enum DuelRematchUiState {
  idle,
  waitingForOpponentResponse,
  rematchRequestReceived,
  rematchAcceptedStarting,
  rematchRejected,
  rematchError,
}

enum ComicMessageTrigger {
  mustDraw,
  strongActionAgainstPlayer,
  heavyDraw,
  tooManyCards,
  playedJoker,
  playedTwo,
  aceForced,
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

class DuelPlayerPresence {
  const DuelPlayerPresence({
    this.state = 'offline',
    this.lastSeenAt,
    this.leftAt,
  });

  final String state;
  final DateTime? lastSeenAt;
  final DateTime? leftAt;

  bool get isOffline => state == 'offline';

  factory DuelPlayerPresence.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const DuelPlayerPresence();
    }
    return DuelPlayerPresence(
      state: map['state'] as String? ?? 'offline',
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate(),
      leftAt: (map['leftAt'] as Timestamp?)?.toDate(),
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
    this.payoutDone = false,
    this.abandonedBy,
    this.exitBothPlayers = false,
    this.payoutWinnerId,
    this.payoutAmount = 0,
    this.payoutAt,
    this.player1Hand = const <String>[],
    this.player2Hand = const <String>[],
    this.drawPile = const <String>[],
    this.discardPile = const <String>[],
    this.topDiscard,
    this.player1CardCount = 0,
    this.player2CardCount = 0,
    this.deckSeed,
    this.revision = 0,
    this.lastActionId,
    this.lastActionBy,
    this.deckInitialized = false,
    this.integrityError,
    this.repairLock,
    this.pendingDrawCount = 0,
    this.forcedDrawInitial = 0,
    this.requiredSuit,
    this.requiredColorAfterJoker,
    this.aceColorRequired = false,
    this.gameStartedAt,
    this.roundStartedAt,
    this.presenceGraceUntil,
    this.presence = const <String, DuelPlayerPresence>{},
    this.roomStatus = 'open',
    this.closeReason,
    this.resultProcessed = false,
    this.endedAt,
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
  final bool payoutDone;
  final String? abandonedBy;
  final bool exitBothPlayers;
  final String? payoutWinnerId;
  final int payoutAmount;
  final DateTime? payoutAt;
  final List<String> player1Hand;
  final List<String> player2Hand;
  final List<String> drawPile;
  final List<String> discardPile;
  final String? topDiscard;
  final int player1CardCount;
  final int player2CardCount;
  final String? deckSeed;
  final int revision;
  final String? lastActionId;
  final String? lastActionBy;
  final bool deckInitialized;
  final Map<String, dynamic>? integrityError;
  final Map<String, dynamic>? repairLock;
  final int pendingDrawCount;
  final int forcedDrawInitial;
  final String? requiredSuit;
  final String? requiredColorAfterJoker;
  final bool aceColorRequired;
  final DateTime? gameStartedAt;
  final DateTime? roundStartedAt;
  final DateTime? presenceGraceUntil;
  final Map<String, DuelPlayerPresence> presence;
  final String roomStatus;
  final String? closeReason;
  final bool resultProcessed;
  final DateTime? endedAt;

  bool get canStart => players.length == 2;
  bool get isCreditsMode => mode == DuelRoomMode.credits;
  String get player1Id => players.isNotEmpty ? players.first : '';
  String get player2Id => players.length > 1 ? players[1] : '';
  List<String> handForPlayer(String playerId) {
    if (playerId == player1Id) {
      return player1Hand;
    }
    if (playerId == player2Id) {
      return player2Hand;
    }
    return const <String>[];
  }

  bool get hasPendingRematchRequest =>
      rematchRequestBy != null &&
      rematchRequestBy!.isNotEmpty &&
      rematchDecision == DuelRematchDecision.pending;

  bool isRematchRequestExpired({Duration timeout = _kRematchRequestTimeout}) {
    if (!hasPendingRematchRequest) {
      return false;
    }
    final DateTime? requestedAt = rematchRequestedAt;
    if (requestedAt == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(requestedAt.toUtc()) >= timeout;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'hostId': hostId,
      'players': players,
      'playerNames': playerNames,
      'currentTurn': currentTurn,
      'status': status.name,
      'roundStatus': status == DuelGameStatus.inProgress ? 'playing' : 'roundFinished',
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
      'rematchStatus': rematchRequestBy == null ? 'none' : 'requested',
      'rematchDecisionBy': rematchDecisionBy,
      'betFlowState': betFlowState.name,
      'invitedRefusalCount': invitedRefusalCount,
      'exitedBy': exitedBy,
      'lastInsufficientFundsPlayerId': lastInsufficientFundsPlayerId,
      'payoutDone': payoutDone,
      'abandonedBy': abandonedBy,
      'exitBothPlayers': exitBothPlayers,
      'payoutWinnerId': payoutWinnerId,
      'payoutAmount': payoutAmount,
      'payoutAt': payoutAt == null ? null : Timestamp.fromDate(payoutAt!.toUtc()),
      'player1Hand': player1Hand,
      'player2Hand': player2Hand,
      'drawPile': drawPile,
      'discardPile': discardPile,
      'topDiscard': topDiscard,
      'player1CardCount': player1CardCount,
      'player2CardCount': player2CardCount,
      'deckSeed': deckSeed,
      'revision': revision,
      'lastActionId': lastActionId,
      'lastActionBy': lastActionBy,
      'deckInitialized': deckInitialized,
      'integrityError': integrityError,
      'repairLock': repairLock,
      'pendingDrawCount': pendingDrawCount,
      'forcedDrawInitial': forcedDrawInitial,
      'requiredSuit': requiredSuit,
      'requiredColorAfterJoker': requiredColorAfterJoker,
      'aceColorRequired': aceColorRequired,
      'gameStartedAt': gameStartedAt == null ? null : Timestamp.fromDate(gameStartedAt!.toUtc()),
      'roundStartedAt':
          roundStartedAt == null ? null : Timestamp.fromDate(roundStartedAt!.toUtc()),
      'presenceGraceUntil': presenceGraceUntil == null
          ? null
          : Timestamp.fromDate(presenceGraceUntil!.toUtc()),
      'presence': presence.map(
        (String playerId, DuelPlayerPresence value) => MapEntry(
          playerId,
          <String, dynamic>{
            'state': value.state,
            'lastSeenAt': value.lastSeenAt == null
                ? null
                : Timestamp.fromDate(value.lastSeenAt!.toUtc()),
            'leftAt': value.leftAt == null
                ? null
                : Timestamp.fromDate(value.leftAt!.toUtc()),
          },
        ),
      ),
      'roomStatus': roomStatus,
      'closeReason': closeReason,
      'resultProcessed': resultProcessed,
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!.toUtc()),
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
      payoutDone: json['payoutDone'] as bool? ?? false,
      abandonedBy: json['abandonedBy'] as String?,
      exitBothPlayers: json['exitBothPlayers'] as bool? ?? false,
      payoutWinnerId: json['payoutWinnerId'] as String?,
      payoutAmount: (json['payoutAmount'] as num?)?.toInt() ?? 0,
      payoutAt: (json['payoutAt'] as Timestamp?)?.toDate(),
      player1Hand: List<String>.from(json['player1Hand'] as List? ?? const <String>[]),
      player2Hand: List<String>.from(json['player2Hand'] as List? ?? const <String>[]),
      drawPile: List<String>.from(json['drawPile'] as List? ?? const <String>[]),
      discardPile: List<String>.from(json['discardPile'] as List? ?? const <String>[]),
      topDiscard: json['topDiscard'] as String?,
      player1CardCount: (json['player1CardCount'] as num?)?.toInt() ?? 0,
      player2CardCount: (json['player2CardCount'] as num?)?.toInt() ?? 0,
      deckSeed: json['deckSeed'] as String?,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      lastActionId: json['lastActionId'] as String?,
      lastActionBy: json['lastActionBy'] as String?,
      deckInitialized: json['deckInitialized'] as bool? ?? false,
      integrityError: (json['integrityError'] as Map?)?.cast<String, dynamic>(),
      repairLock: (json['repairLock'] as Map?)?.cast<String, dynamic>(),
      pendingDrawCount: (json['pendingDrawCount'] as num?)?.toInt() ?? 0,
      forcedDrawInitial: (json['forcedDrawInitial'] as num?)?.toInt() ?? 0,
      requiredSuit: json['requiredSuit'] as String?,
      requiredColorAfterJoker: json['requiredColorAfterJoker'] as String?,
      aceColorRequired: json['aceColorRequired'] as bool? ?? false,
      gameStartedAt: (json['gameStartedAt'] as Timestamp?)?.toDate(),
      roundStartedAt: (json['roundStartedAt'] as Timestamp?)?.toDate(),
      presenceGraceUntil: (json['presenceGraceUntil'] as Timestamp?)?.toDate(),
      presence: (json['presence'] as Map? ?? const <String, dynamic>{}).map(
        (Object? key, Object? value) => MapEntry(
          key.toString(),
          DuelPlayerPresence.fromMap((value as Map?)?.cast<String, dynamic>()),
        ),
      ),
      roomStatus: json['roomStatus'] as String? ?? 'open',
      closeReason: json['closeReason'] as String?,
      resultProcessed: json['resultProcessed'] as bool? ?? false,
      endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Multiplayer transport only: game rules stay in existing GameEngine.
class GameService {
  GameService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  DateTime _presenceGraceDeadline() => DateTime.now().toUtc().add(_presenceGracePeriod);

  Future<int> _readCreditsFromProfileTx({
    required Transaction tx,
    required FirebaseFirestore db,
    required String playerId,
    String? displayName,
  }) async {
    final DocumentReference<Map<String, dynamic>> profileRef = _userProfileRef(db, playerId);
    final DocumentSnapshot<Map<String, dynamic>> profileSnap = await tx.get(profileRef);
    if (!profileSnap.exists) {
      tx.set(profileRef, <String, dynamic>{
        'uid': playerId,
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName,
        'credits': 1000,
        'wins': 0,
        'losses': 0,
        'gamesPlayed': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return 1000;
    }
    final int credits = (profileSnap.data()?['credits'] as num?)?.toInt() ?? 0;
    if (!(profileSnap.data()?.containsKey('credits') ?? false)) {
      tx.set(profileRef, <String, dynamic>{
        'credits': credits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return credits;
  }

  Map<String, dynamic> _presenceOnlinePatch(String playerId) {
    return <String, dynamic>{
      'presence.$playerId.state': 'online',
      'presence.$playerId.lastSeenAt': FieldValue.serverTimestamp(),
      'presence.$playerId.leftAt': null,
    };
  }

  Map<String, dynamic> _presenceOfflinePatch(String playerId) {
    return <String, dynamic>{
      'presence.$playerId.state': 'offline',
      'presence.$playerId.leftAt': FieldValue.serverTimestamp(),
      'presence.$playerId.lastSeenAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _presenceStatePatch({
    required String playerId,
    required String state,
  }) {
    return <String, dynamic>{
      'presence.$playerId.state': state,
      'presence.$playerId.lastSeenAt': FieldValue.serverTimestamp(),
      if (state != 'offline') 'presence.$playerId.leftAt': null,
      if (state == 'offline') 'presence.$playerId.leftAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _ensureSignedInForFirestore() async {
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('[GameService] Anonymous sign-in created for Firestore.');
    } catch (e) {
      throw StateError(
        'Authentification Firebase requise pour le mode duel. Détail: $e',
      );
    }
  }

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
          debugPrint(
            '[GameService] Firebase initialized in duel mode: projectId=${options.projectId}, appId=${options.appId}',
          );
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

    await _ensureSignedInForFirestore();
    return FirebaseFirestore.instance;
  }

  Future<CollectionReference<Map<String, dynamic>>> _games() async =>
      (await _resolveDb()).collection('duel_games');

  DocumentReference<Map<String, dynamic>> _userProfileRef(
    FirebaseFirestore db,
    String uid,
  ) {
    return db.collection('user_profiles').doc(uid);
  }

  String _generateCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random();
    return List<String>.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _buildDeckSeed(String gameId, int round) => '$gameId-$round';

  Map<String, dynamic> _boardInitPatch({
    required String gameId,
    required List<String> players,
    required int round,
  }) {
    final DuelBoardState board = DuelBoardState.initial(
      gameId: gameId,
      players: players,
      round: round,
    );
    return <String, dynamic>{
      ...board.toFirestoreFields(),
      'deckSeed': _buildDeckSeed(gameId, round),
      'integrityError': null,
      'repairLock': null,
    };
  }

  Future<String> createGame({
    required String playerId,
    required String playerName,
    DuelRoomMode mode = DuelRoomMode.duel,
  }) async {
    final String code = _generateCode();
    final CollectionReference<Map<String, dynamic>> games = await _games();
    int initialCredits = 1000;
    if (mode == DuelRoomMode.credits) {
      final FirebaseFirestore db = await _resolveDb();
      final DocumentReference<Map<String, dynamic>> profileRef = _userProfileRef(db, playerId);
      await db.runTransaction((Transaction tx) async {
        initialCredits = await _readCreditsFromProfileTx(
          tx: tx,
          db: db,
          playerId: playerId,
          displayName: playerName,
        );
      });
      if (initialCredits <= 0) {
        throw StateError('Crédit insuffisant pour accéder au mode Pari.');
      }
    }
    debugPrint('[GameService] createGame requested by $playerId in mode=${mode.name}.');
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
        presence: <String, DuelPlayerPresence>{
          playerId: const DuelPlayerPresence(state: 'online'),
        },
        presenceGraceUntil: _presenceGraceDeadline(),
        roomStatus: 'open',
      ).toMap()
        ..addAll(_presenceOnlinePatch(playerId)),
    );
    return code;
  }

  Future<void> joinGame({
    required String gameId,
    required String playerId,
    required String playerName,
    DuelRoomMode? expectedMode,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    debugPrint('[GameService] joinGame requested by $playerId for game=$gameId.');
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
      final bool activatesNow = players.length == 2 && !session.isCreditsMode;
      int joiningPlayerCredits = session.playerCredits[playerId] ?? 1000;
      if (session.isCreditsMode) {
        joiningPlayerCredits = await _readCreditsFromProfileTx(
          tx: tx,
          db: db,
          playerId: playerId,
          displayName: playerName,
        );
        if (joiningPlayerCredits <= 0) {
          throw StateError('Crédit insuffisant pour accéder au mode Pari.');
        }
      }
      tx.update(ref, <String, dynamic>{
        'players': players,
        'playerNames.$playerId': playerName,
        'scores.$playerId': session.scores[playerId] ?? 0,
        if (session.isCreditsMode)
          'playerCredits.$playerId': joiningPlayerCredits,
        'status': players.length == 2
            ? (session.isCreditsMode
                ? DuelGameStatus.waiting.name
                : DuelGameStatus.inProgress.name)
            : DuelGameStatus.waiting.name,
        if (activatesNow && !session.deckInitialized)
          ..._boardInitPatch(
            gameId: session.gameId,
            players: players,
            round: session.round,
          ),
        if (players.length == 2 && session.gameStartedAt == null)
          'gameStartedAt': FieldValue.serverTimestamp(),
        if (players.length == 2) 'roundStartedAt': FieldValue.serverTimestamp(),
        if (players.length == 2) 'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
        if (activatesNow && !session.deckInitialized) 'revision': session.revision + 1,
        ..._presenceOnlinePatch(playerId),
        ...players
            .where((String id) => id != playerId)
            .fold<Map<String, dynamic>>(<String, dynamic>{}, (Map<String, dynamic> acc, String id) {
          acc['presence.$id.state'] = 'online';
          acc['presence.$id.lastSeenAt'] = FieldValue.serverTimestamp();
          acc['presence.$id.leftAt'] = null;
          return acc;
        }),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updatePresenceHeartbeat({
    required String gameId,
    required String playerId,
  }) async {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    debugPrint('[Presence] heartbeat sent player=$playerId');
    await games.doc(gameId).update(<String, dynamic>{
      ..._presenceOnlinePatch(playerId),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPlayerPresenceState({
    required String gameId,
    required String playerId,
    required String state,
  }) async {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    if (state == 'maybeOffline' || state == 'leaving') {
      debugPrint('[Presence] beforeunload detected, marking maybeOffline only');
    }
    await games.doc(gameId).update(<String, dynamic>{
      ..._presenceStatePatch(playerId: playerId, state: state),
      'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> repairGameStateIfNeeded({
    required String gameId,
    required String requestedBy,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        return;
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.hostId != requestedBy || !session.deckInitialized) {
        return;
      }
      final DuelGameStateValidationResult validation = validateGameState(session);
      if (validation.isValid) {
        return;
      }
      final DateTime now = DateTime.now().toUtc();
      final Timestamp? lockAtTs = session.repairLock?['lockedAt'] as Timestamp?;
      final DateTime? lockAt = lockAtTs?.toDate().toUtc();
      final bool lockExpired = lockAt == null || now.difference(lockAt).inSeconds > 15;
      final String? lockBy = session.repairLock?['lockedBy'] as String?;
      if (!lockExpired && lockBy != requestedBy) {
        return;
      }
      if (validation.integrityError != null) {
        tx.update(ref, <String, dynamic>{
          'status': DuelGameStatus.finished.name,
          'integrityError': validation.integrityError,
          'revision': session.revision + 1,
          'repairLock': <String, dynamic>{
            'lockedBy': requestedBy,
            'lockedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      if (validation.autoCorrectPatch.isNotEmpty) {
        tx.update(ref, <String, dynamic>{
          ...validation.autoCorrectPatch,
          'revision': session.revision + 1,
          'repairLock': <String, dynamic>{
            'lockedBy': requestedBy,
            'lockedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> gameRef =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(gameRef);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.status != DuelGameStatus.inProgress) {
        throw StateError('La partie n’est pas active.');
      }
      if (session.currentTurn != action.actorId) {
        throw StateError('Ce n’est pas votre tour.');
      }
      if (!session.players.contains(action.actorId)) {
        throw StateError('Action invalide.');
      }
      if (!session.deckInitialized) {
        throw StateError('Deck non initialisé.');
      }
      final DuelGameStateValidationResult preValidation = validateGameState(session);
      if (preValidation.integrityError != null) {
        tx.update(gameRef, <String, dynamic>{
          'status': DuelGameStatus.finished.name,
          'integrityError': preValidation.integrityError,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        throw StateError('Partie corrompue: cartes dupliquées détectées.');
      }
      DuelBoardState board = DuelBoardState.fromSession(session);

      DuelMoveResult move;
      if (action.type == DuelActionType.playCard) {
        final String? cardId = action.payload['cardId'] as String?;
        if (cardId == null || cardId.isEmpty) {
          throw StateError('Carte invalide.');
        }
        final DuelCard card = DuelCard.fromId(cardId);
        move = board.tryPlay(
          actorId: action.actorId,
          card: card,
          chosenSuit: action.payload['chosenSuit'] as String?,
        );
      } else if (action.type == DuelActionType.drawCard) {
        move = board.tryDraw(actorId: action.actorId);
      } else {
        throw StateError('Action non supportée.');
      }
      if (!move.accepted || move.nextTurn == null) {
        if (move.rejectionMessage != null && move.rejectionMessage!.trim().isNotEmpty) {
          throw StateError(move.rejectionMessage!);
        }
        throw StateError('Action refusée par la logique de jeu.');
      }
      final DuelAction validatedAction = DuelAction(
        type: action.type,
        actorId: action.actorId,
        createdAt: action.createdAt,
        payload: move.payload,
      );
      final DuelBoardState nextBoard = board.applyValidatedAction(validatedAction);
      final DuelGameStatus nextStatus = move.payload.containsKey('winnerId')
          ? DuelGameStatus.finished
          : status;
      final String actionId = gameRef.collection('actions').doc().id;
      tx.update(gameRef, <String, dynamic>{
        'currentTurn': move.nextTurn!,
        'lastAction': validatedAction.toMap(),
        'lastActionId': actionId,
        'lastActionBy': action.actorId,
        'status': nextStatus.name,
        'roundStatus': move.payload.containsKey('winnerId') ? 'roundFinished' : 'playing',
        if (move.payload.containsKey('winnerId')) 'rematchStatus': 'none',
        'revision': session.revision + 1,
        ...nextBoard.toFirestoreFields(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...sessionPatch,
      });
      tx.set(gameRef.collection('actions').doc(actionId), validatedAction.toMap());
    });
  }

  Future<void> handlePlayerExitGame({
    required String gameId,
    required String currentUserId,
  }) async {
    await markPlayerAbandoned(
      gameId: gameId,
      abandonedBy: currentUserId,
      reportedBy: currentUserId,
    );
  }

  Future<void> markPlayerAbandoned({
    required String gameId,
    required String abandonedBy,
    required String reportedBy,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref = db.collection('duel_games').doc(gameId);
    debugPrint('[Forfeit] requested abandonedBy=$abandonedBy reportedBy=$reportedBy');
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.status == DuelGameStatus.finished) {
        return;
      }
      if (!session.players.contains(abandonedBy) || !session.players.contains(reportedBy)) {
        throw StateError('Joueur invalide pour cet abandon.');
      }
      final String winnerId = session.players.firstWhere(
        (String id) => id != abandonedBy,
        orElse: () => '',
      );
      if (winnerId.isEmpty) {
        return;
      }
      if (reportedBy != abandonedBy && reportedBy != winnerId) {
        throw StateError('Signalement non autorisé.');
      }
      final bool voluntaryQuit = reportedBy == abandonedBy;
      final DateTime now = DateTime.now().toUtc();
      if (reportedBy != abandonedBy) {
        final DuelPlayerPresence abandonedPresence =
            session.presence[abandonedBy] ?? const DuelPlayerPresence();
        final DateTime? graceUntil = session.presenceGraceUntil?.toUtc();
        if (graceUntil != null && now.isBefore(graceUntil)) {
          debugPrint('[Presence] abandon check skipped: grace period');
          throw StateError('Période de grâce active.');
        }
        final DateTime? gameStartedAt = session.gameStartedAt?.toUtc();
        if (gameStartedAt == null || now.difference(gameStartedAt) < _presenceGracePeriod) {
          debugPrint('[Presence] abandon check skipped: grace period');
          throw StateError('Partie trop récente pour valider un abandon.');
        }
        if (session.status != DuelGameStatus.inProgress) {
          throw StateError('La partie n’a pas encore commencé.');
        }
        if (session.isCreditsMode && !session.stakeOffer.isAccepted) {
          throw StateError('La mise n’est pas acceptée.');
        }
        final DateTime? lastSeen = abandonedPresence.lastSeenAt?.toUtc();
        final bool heartbeatExpired =
            lastSeen == null || now.difference(lastSeen) >= _abandonTimeout;
        if (abandonedPresence.state == 'online') {
          debugPrint('[Presence] abandon check skipped: heartbeat still recent');
          throw StateError('L’adversaire est encore connecté.');
        }
        if (!heartbeatExpired) {
          debugPrint('[Presence] abandon check skipped: heartbeat still recent');
          throw StateError('L’adversaire est encore connecté.');
        }
      }
      final DuelAction action = DuelAction(
        type: DuelActionType.forfeit,
        actorId: abandonedBy,
        createdAt: DateTime.now(),
        payload: <String, dynamic>{
          'winnerId': winnerId,
          'loserId': abandonedBy,
          'abandoned': true,
        },
      );
      final Map<String, dynamic> patch = <String, dynamic>{
        'status': DuelGameStatus.finished.name,
        'roundStatus': 'roundFinished',
        'abandonedBy': abandonedBy,
        'winnerId': winnerId,
        'loserId': abandonedBy,
        'exitBothPlayers': false,
        'currentTurn': winnerId,
        'lastAction': action.toMap(),
        'lastActionBy': abandonedBy,
        'lastActionId': '${DateTime.now().microsecondsSinceEpoch}',
        'scores.$winnerId': FieldValue.increment(1),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'rematchStatus': 'none',
        ..._presenceOfflinePatch(abandonedBy),
        'betFlowState': session.isCreditsMode
            ? DuelBetFlowState.matchFinished.name
            : DuelBetFlowState.partyExited.name,
        'roomStatus': 'open',
        'closeReason': null,
        'resultProcessed': true,
        'endedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
      };
      if (session.isCreditsMode) {
        final DuelStakeOffer offer = session.stakeOffer;
        final int pot = session.activeStakeCredits;
        final int winnerCredits = session.playerCredits[winnerId] ?? 0;
        if (!session.payoutDone && offer.isAccepted && pot > 0) {
          debugPrint('[Forfeit] payout amount=$pot winner=$winnerId');
          final int loserCredits = session.playerCredits[abandonedBy] ?? 0;
          final int winnerNextCredits = winnerCredits + pot;
          final bool loserNoCredit = loserCredits <= 0;
          patch.addAll(<String, dynamic>{
            'playerCredits.$winnerId': winnerNextCredits,
            'activeStakeCredits': 0,
            'stakeOffer': DuelStakeOffer(
              proposedBy: offer.proposedBy,
              acceptedBy: offer.acceptedBy,
              amount: offer.amount,
              status: DuelStakeStatus.resolved,
              createdAt: offer.createdAt,
            ).toMap(),
            'betFlowState': DuelBetFlowState.matchFinished.name,
            'payoutDone': true,
            'payoutWinnerId': winnerId,
            'payoutAmount': offer.amount,
            'payoutAt': FieldValue.serverTimestamp(),
            if (loserNoCredit) 'roomStatus': 'closed',
            if (loserNoCredit) 'closeReason': 'opponent_no_credit',
            if (loserNoCredit) 'endedAt': FieldValue.serverTimestamp(),
          });
          tx.set(_userProfileRef(db, winnerId), <String, dynamic>{
            'credits': winnerNextCredits,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (session.payoutDone) {
          debugPrint('[Forfeit] skipped: payout already done');
        }
      }
      patch['updatedAt'] = FieldValue.serverTimestamp();
      debugPrint(
        voluntaryQuit
            ? '[Forfeit] voluntary quit confirmed'
            : '[Forfeit] detected absence confirmed after timeout',
      );
      tx.update(ref, patch);
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
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
        'roundStatus': session.isCreditsMode ? 'roundFinished' : 'playing',
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'lastActionBy': requestedBy,
        'lastActionId': '${DateTime.now().microsecondsSinceEpoch}',
        'activeStakeCredits': 0,
        'stakeOffer': const DuelStakeOffer().toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'rematchStatus': 'none',
        'betFlowState': session.isCreditsMode
            ? DuelBetFlowState.initialStakeProposed.name
            : DuelBetFlowState.idle.name,
        'invitedRefusalCount': 0,
        'exitedBy': null,
        'abandonedBy': null,
        'lastInsufficientFundsPlayerId': null,
        'payoutDone': false,
        'payoutWinnerId': null,
        'payoutAmount': 0,
        'payoutAt': null,
        'roomStatus': 'open',
        'closeReason': null,
        'resultProcessed': false,
        'endedAt': null,
        'roundStartedAt': FieldValue.serverTimestamp(),
        'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
        'revision': session.revision + 1,
        if (!session.isCreditsMode)
          ..._boardInitPatch(
            gameId: session.gameId,
            players: session.players,
            round: nextRound,
          ),
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
  }

  Future<void> requestRematch({
    required String gameId,
    required String requestedBy,
  }) async {
    debugPrint('[RematchParis] loser requested rematch: $requestedBy');
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
      final String loserId = session.players.firstWhere(
        (String id) => id != winnerId,
        orElse: () => '',
      );
      final bool canOverrideExpiredRequest = session.isRematchRequestExpired();
      if (session.status != DuelGameStatus.finished ||
          winnerId == null ||
          winnerId.isEmpty ||
          !session.players.contains(requestedBy) ||
          (session.isCreditsMode && requestedBy != loserId) ||
          (session.hasPendingRematchRequest && !canOverrideExpiredRequest)) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'rematchRequestBy': requestedBy,
        'rematchRequestedAt': FieldValue.serverTimestamp(),
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'status': DuelGameStatus.finished.name,
        'roundStatus': 'rematchProposalPending',
        'rematchStatus': 'requested',
        'betFlowState': DuelBetFlowState.rematchPendingFromLoser.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
        if (session.isCreditsMode) ...<String, dynamic>{
          'stakeOffer': const DuelStakeOffer().toMap(),
          'activeStakeCredits': 0,
        },
      });
      debugPrint('[RematchParis] rematch request saved');
    });
  }

  Future<void> cancelRematchRequest({
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
      if (session.status != DuelGameStatus.finished ||
          session.rematchRequestBy != requestedBy ||
          session.rematchDecision != DuelRematchDecision.pending) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'roundStatus': 'roundFinished',
        'rematchStatus': 'none',
        if (session.isCreditsMode) ...<String, dynamic>{
          'betFlowState': DuelBetFlowState.matchFinished.name,
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
    if (accept) {
      await acceptRematch(gameId: current.gameId, acceptedBy: responderId);
      return;
    }
    await declineRematch(gameId: current.gameId, declinedBy: responderId);
  }

  Future<void> acceptRematch({
    required String gameId,
    required String acceptedBy,
  }) async {
    debugPrint('[RematchParis] rematch request accepted by opponent: $acceptedBy');
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.rematchRequestBy == null ||
          session.rematchRequestBy == acceptedBy ||
          session.status != DuelGameStatus.finished ||
          session.rematchDecision != DuelRematchDecision.pending) {
        return;
      }
      final String requesterId = session.rematchRequestBy!;
      if (session.isCreditsMode) {
        tx.update(ref, <String, dynamic>{
          'status': DuelGameStatus.finished.name,
          'roundStatus': 'roundFinished',
          'rematchDecision': DuelRematchDecision.pending.name,
          'rematchDecisionBy': acceptedBy,
          'rematchStatus': 'accepted',
          'betFlowState': DuelBetFlowState.rematchStakePendingWinnerResponse.name,
          'activeStakeCredits': 0,
          'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
          'updatedAt': FieldValue.serverTimestamp(),
          'revision': session.revision + 1,
        });
        return;
      }
      final int nextRound = session.round + 1;
      final String starter = requesterId;
      final DuelAction action = DuelAction(
        type: DuelActionType.resetRound,
        actorId: acceptedBy,
        createdAt: DateTime.now(),
        payload: <String, dynamic>{
          'round': nextRound,
          'startingPlayerId': starter,
        },
      );
      tx.update(ref, <String, dynamic>{
        'status': DuelGameStatus.inProgress.name,
        'roundStatus': 'playing',
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'lastActionBy': acceptedBy,
        'lastActionId': '${DateTime.now().microsecondsSinceEpoch}',
        'activeStakeCredits': session.isCreditsMode ? session.activeStakeCredits : 0,
        'stakeOffer': session.isCreditsMode
            ? session.stakeOffer.toMap()
            : const DuelStakeOffer().toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'rematchStatus': 'none',
        'pendingDrawCount': 0,
        'forcedDrawInitial': 0,
        'requiredSuit': null,
        'requiredColorAfterJoker': null,
        'aceColorRequired': false,
        'abandonedBy': null,
        'exitBothPlayers': false,
        'integrityError': null,
        'repairLock': null,
        'betFlowState': DuelBetFlowState.rematchAccepted.name,
        'payoutDone': false,
        'payoutWinnerId': null,
        'payoutAmount': 0,
        'payoutAt': null,
        'roundStartedAt': FieldValue.serverTimestamp(),
        'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
        ..._boardInitPatch(
          gameId: session.gameId,
          players: session.players,
          round: nextRound,
        ),
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
      debugPrint('[RematchParis] starting new round=$nextRound');
      debugPrint('[RematchParis] board reset applied');
    });
  }

  Future<void> declineRematch({
    required String gameId,
    required String declinedBy,
  }) async {
    debugPrint('[RematchParis] decline requested by=$declinedBy game=$gameId');
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Partie introuvable');
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (session.rematchRequestBy == null ||
          session.status != DuelGameStatus.finished ||
          session.rematchDecision != DuelRematchDecision.pending) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'status': DuelGameStatus.finished.name,
        'roundStatus': 'rematchDeclined',
        'rematchDecision': DuelRematchDecision.declined.name,
        'rematchDecisionBy': declinedBy,
        'rematchStatus': 'refused',
        'betFlowState': DuelBetFlowState.rematchRejected.name,
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
      });
    });
  }

  Future<void> cleanupExpiredRematchRequest({
    required String gameId,
  }) async {
    final FirebaseFirestore db = await _resolveDb();
    final DocumentReference<Map<String, dynamic>> ref =
        db.collection('duel_games').doc(gameId);
    await db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        return;
      }
      final DuelSession session = DuelSession.fromDoc(snap);
      if (!session.isRematchRequestExpired()) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
        'rematchStatus': 'none',
        'roundStatus': 'roundFinished',
        'betFlowState': DuelBetFlowState.matchFinished.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
      });
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
      final int proposerCredits = await _readCreditsFromProfileTx(
        tx: tx,
        db: db,
        playerId: proposedBy,
      );
      if (proposerCredits <= 0 || amount > proposerCredits || amount > balance) {
        throw StateError('Solde insuffisant pour cette proposition.');
      }
      final String opponentId = session.players.firstWhere(
        (String id) => id != proposedBy,
        orElse: () => '',
      );
      if (opponentId.isNotEmpty) {
        final int opponentBalance = session.playerCredits[opponentId] ?? 0;
        final int opponentCredits = await _readCreditsFromProfileTx(
          tx: tx,
          db: db,
          playerId: opponentId,
        );
        if (opponentCredits <= 0 || amount > opponentCredits || amount > opponentBalance) {
          throw StateError('Mise refusée: crédit adverse insuffisant.');
        }
      }
      tx.update(ref, <String, dynamic>{
        'playerCredits.$proposedBy': proposerCredits,
        if (opponentId.isNotEmpty)
          'playerCredits.$opponentId': await _readCreditsFromProfileTx(
            tx: tx,
            db: db,
            playerId: opponentId,
          ),
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
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
      });
      if (isRematchStakeFlow) {
        debugPrint('[RematchParis] loser proposed stake: $amount');
      }
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
          if (session.status == DuelGameStatus.finished) ...<String, dynamic>{
            'rematchDecision': DuelRematchDecision.declined.name,
            'rematchDecisionBy': responderId,
            'betFlowState': DuelBetFlowState.rematchRejected.name,
            'rematchRequestBy': null,
            'rematchRequestedAt': null,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'revision': session.revision + 1,
        });
        return;
      }
      final int responderCredits = session.playerCredits[responderId] ?? 0;
      final int proposerCredits = session.playerCredits[offer.proposedBy!] ?? 0;
      final int latestResponderCredits = await _readCreditsFromProfileTx(
        tx: tx,
        db: db,
        playerId: responderId,
      );
      final int latestProposerCredits = await _readCreditsFromProfileTx(
        tx: tx,
        db: db,
        playerId: offer.proposedBy!,
      );
      if (offer.amount > responderCredits ||
          offer.amount > proposerCredits ||
          offer.amount > latestResponderCredits ||
          offer.amount > latestProposerCredits) {
        tx.update(ref, <String, dynamic>{
          'playerCredits.$responderId': latestResponderCredits,
          'playerCredits.${offer.proposedBy!}': latestProposerCredits,
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
          'updatedAt': FieldValue.serverTimestamp(),
          'revision': session.revision + 1,
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
        if (session.rematchRequestBy == null || responderId == session.rematchRequestBy) {
          throw StateError('Réponse de mise invalide pour la revanche.');
        }
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
          'playerCredits.${offer.proposedBy!}': latestProposerCredits - offer.amount,
          'playerCredits.$responderId': latestResponderCredits - offer.amount,
          'activeStakeCredits': offer.amount * 2,
          'status': DuelGameStatus.inProgress.name,
          'roundStatus': 'playing',
          'round': nextRound,
          'currentTurn': starter,
          'lastAction': action.toMap(),
          'lastActionBy': responderId,
          'lastActionId': '${DateTime.now().microsecondsSinceEpoch}',
          'stakeOffer': acceptedOffer.toMap(),
          'rematchRequestBy': null,
          'rematchRequestedAt': null,
          'rematchDecision': DuelRematchDecision.pending.name,
          'rematchDecisionBy': null,
          'rematchStatus': 'none',
          'betFlowState': DuelBetFlowState.rematchAccepted.name,
          'invitedRefusalCount': 0,
          'exitedBy': null,
          'lastInsufficientFundsPlayerId': null,
          'payoutDone': false,
          'payoutWinnerId': null,
          'payoutAmount': 0,
          'payoutAt': null,
          'roomStatus': 'open',
          'closeReason': null,
          'resultProcessed': false,
          'endedAt': null,
          'roundStartedAt': FieldValue.serverTimestamp(),
          'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
          'updatedAt': FieldValue.serverTimestamp(),
          'revision': session.revision + 1,
          ..._boardInitPatch(
            gameId: session.gameId,
            players: session.players,
            round: nextRound,
          ),
        });
        tx.set(_userProfileRef(db, offer.proposedBy!), <String, dynamic>{
          'credits': latestProposerCredits - offer.amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(_userProfileRef(db, responderId), <String, dynamic>{
          'credits': latestResponderCredits - offer.amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(ref.collection('actions').doc(), action.toMap());
        debugPrint('[RematchParis] winner accepted stake');
        debugPrint('[RematchParis] starting new round=$nextRound');
        debugPrint('[RematchParis] board reset applied');
        debugPrint('[RematchParis] status=inProgress');
        return;
      }
      tx.update(ref, <String, dynamic>{
        'playerCredits.${offer.proposedBy!}': latestProposerCredits - offer.amount,
        'playerCredits.$responderId': latestResponderCredits - offer.amount,
        'activeStakeCredits': offer.amount * 2,
        'status': DuelGameStatus.inProgress.name,
        'roundStatus': 'playing',
        'stakeOffer': acceptedOffer.toMap(),
        'betFlowState': DuelBetFlowState.readyToStart.name,
        'lastInsufficientFundsPlayerId': null,
        'payoutDone': false,
        'payoutWinnerId': null,
        'payoutAmount': 0,
        'payoutAt': null,
        'roomStatus': 'open',
        'closeReason': null,
        'resultProcessed': false,
        'endedAt': null,
        'roundStartedAt': FieldValue.serverTimestamp(),
        'presenceGraceUntil': Timestamp.fromDate(_presenceGraceDeadline()),
        if (!session.deckInitialized)
          ..._boardInitPatch(
            gameId: session.gameId,
            players: session.players,
            round: session.round,
          ),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': session.revision + 1,
      });
      tx.set(_userProfileRef(db, offer.proposedBy!), <String, dynamic>{
        'credits': latestProposerCredits - offer.amount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(_userProfileRef(db, responderId), <String, dynamic>{
        'credits': latestResponderCredits - offer.amount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      if (session.payoutDone ||
          !offer.isAccepted ||
          amount <= 0 ||
          !session.players.contains(winnerId)) {
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
      final int winnerNext = winnerBalance + amount;
      final bool loserNoCredit = loserBalance <= 0;
      tx.update(ref, <String, dynamic>{
        'playerCredits.$winnerId': winnerNext,
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
        'payoutDone': true,
        'payoutWinnerId': winnerId,
        'payoutAmount': offer.amount,
        'payoutAt': FieldValue.serverTimestamp(),
        'resultProcessed': true,
        'endedAt': FieldValue.serverTimestamp(),
        if (loserNoCredit) 'roomStatus': 'closed',
        if (loserNoCredit) 'closeReason': 'opponent_no_credit',
      });
      tx.set(_userProfileRef(db, winnerId), <String, dynamic>{
        'credits': winnerNext,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}

class DuelController extends ChangeNotifier {
  DuelController({
    required this.service,
    required this.localPlayerId,
    required this.localPlayerName,
    this.roomMode = DuelRoomMode.duel,
  });

  final GameService service;
  final String localPlayerId;
  final String localPlayerName;
  final DuelRoomMode roomMode;

  DuelSession? session;
  StreamSubscription<DuelSession>? _subscription;
  Timer? _presenceHeartbeatTimer;
  Timer? _presenceWatchdogTimer;
  bool _repairInFlight = false;
  bool _forfeitReportInFlight = false;
  String? _lastForfeitReportKey;
  String? _lastGraceCheckpointKey;
  DateTime? _localPresenceGraceUntil;
  bool _connectionWarningLogged = false;
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
      final DuelSession? previous = session;
      if (previous != null &&
          previous.gameId == value.gameId &&
          previous.revision == value.revision &&
          previous.status == value.status &&
          previous.lastActionId == value.lastActionId &&
          previous.currentTurn == value.currentTurn &&
          mapEquals(previous.scores, value.scores) &&
          mapEquals(previous.playerCredits, value.playerCredits)) {
        return;
      }
      session = value;
      final String graceCheckpoint = '${value.gameId}_${value.round}_${value.status.name}';
      if (_lastGraceCheckpointKey != graceCheckpoint) {
        _lastGraceCheckpointKey = graceCheckpoint;
        startPresenceGracePeriod();
      }
      _syncPresenceJobs(value);
      _maybeRepairSessionIntegrity(value);
      notifyListeners();
    });
  }

  bool _isActiveSession(DuelSession session) {
    if (session.players.length < 2) {
      return false;
    }
    if (session.status == DuelGameStatus.inProgress) {
      return true;
    }
    return session.status == DuelGameStatus.waiting && session.isCreditsMode;
  }

  void _syncPresenceJobs(DuelSession current) {
    if (!_isActiveSession(current)) {
      _presenceHeartbeatTimer?.cancel();
      _presenceHeartbeatTimer = null;
      _presenceWatchdogTimer?.cancel();
      _presenceWatchdogTimer = null;
      return;
    }
    final bool startedHeartbeat = _presenceHeartbeatTimer == null;
    _presenceHeartbeatTimer ??= Timer.periodic(_presenceHeartbeatInterval, (_) {
      final DuelSession? latest = session;
      if (latest == null || !_isActiveSession(latest)) {
        return;
      }
      unawaited(service.updatePresenceHeartbeat(
        gameId: latest.gameId,
        playerId: localPlayerId,
      ));
    });
    if (startedHeartbeat) {
      debugPrint('[Presence] heartbeat started player=$localPlayerId game=${current.gameId}');
    }
    _presenceWatchdogTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_reportOfflineOpponentIfNeeded());
    });
    unawaited(service.updatePresenceHeartbeat(gameId: current.gameId, playerId: localPlayerId));
  }

  void startPresenceGracePeriod({Duration duration = _presenceGracePeriod}) {
    _localPresenceGraceUntil = DateTime.now().toUtc().add(duration);
  }

  Future<void> _reportOfflineOpponentIfNeeded() async {
    if (_forfeitReportInFlight) {
      return;
    }
    final DuelSession? current = session;
    if (current == null || !_isActiveSession(current)) {
      return;
    }
    final String opponentId = current.players.firstWhere(
      (String id) => id != localPlayerId,
      orElse: () => '',
    );
    if (opponentId.isEmpty) {
      return;
    }
    final DuelPlayerPresence opponentPresence =
        current.presence[opponentId] ?? const DuelPlayerPresence();
    final DateTime now = DateTime.now().toUtc();
    if (_localPresenceGraceUntil != null && now.isBefore(_localPresenceGraceUntil!)) {
      debugPrint('[Presence] abandon check skipped: grace period');
      return;
    }
    final DateTime? backendGrace = current.presenceGraceUntil?.toUtc();
    if (backendGrace != null && now.isBefore(backendGrace)) {
      debugPrint('[Presence] abandon check skipped: grace period');
      return;
    }
    final DateTime? lastSeen = opponentPresence.lastSeenAt?.toUtc();
    final Duration elapsed = lastSeen == null ? _abandonTimeout : now.difference(lastSeen);
    if (elapsed >= _connectionWarningTimeout && elapsed < _abandonTimeout && !_connectionWarningLogged) {
      _connectionWarningLogged = true;
      debugPrint('[Presence] warning: Connexion de l’adversaire instable');
    }
    final bool stale = elapsed >= _abandonTimeout;
    final bool shouldReport = opponentPresence.isOffline || stale;
    if (!shouldReport) {
      _connectionWarningLogged = false;
      return;
    }
    final String reportKey =
        '${current.gameId}_${current.round}_${opponentId}_${opponentPresence.lastSeenAt?.millisecondsSinceEpoch ?? -1}_${opponentPresence.state}';
    if (_lastForfeitReportKey == reportKey) {
      return;
    }
    _forfeitReportInFlight = true;
    try {
      await service.markPlayerAbandoned(
        gameId: current.gameId,
        abandonedBy: opponentId,
        reportedBy: localPlayerId,
      );
      _lastForfeitReportKey = reportKey;
    } catch (_) {
      // Opponent may still be connected or the game already completed.
    } finally {
      _forfeitReportInFlight = false;
    }
  }

  void _maybeRepairSessionIntegrity(DuelSession value) {
    if (_repairInFlight || value.hostId != localPlayerId || !value.deckInitialized) {
      return;
    }
    final DuelGameStateValidationResult validation = validateGameState(value);
    if (validation.isValid) {
      return;
    }
    _repairInFlight = true;
    service
        .repairGameStateIfNeeded(gameId: value.gameId, requestedBy: localPlayerId)
        .whenComplete(() {
          _repairInFlight = false;
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

  Future<void> cancelRematchRequest() async {
    final DuelSession? current = session;
    if (current == null || current.status != DuelGameStatus.finished) {
      return;
    }
    await service.cancelRematchRequest(
      gameId: current.gameId,
      requestedBy: localPlayerId,
    );
  }

  Future<void> respondToRematch(bool accept) async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    if (accept) {
      await acceptRematch();
      return;
    }
    await declineRematch();
  }

  Future<void> acceptRematch() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.acceptRematch(gameId: current.gameId, acceptedBy: localPlayerId);
  }

  Future<void> declineRematch() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.declineRematch(gameId: current.gameId, declinedBy: localPlayerId);
  }

  Future<void> cleanupExpiredRematchRequest() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    await service.cleanupExpiredRematchRequest(gameId: current.gameId);
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

  Future<void> forfeitMatch() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    debugPrint('[Forfeit] voluntary quit confirmed');
    await service.markPlayerAbandoned(
      gameId: current.gameId,
      abandonedBy: localPlayerId,
      reportedBy: localPlayerId,
    );
  }

  Future<void> markOffline() async {
    final DuelSession? current = session;
    if (current == null) {
      return;
    }
    try {
      await service.markPlayerPresenceState(
        gameId: current.gameId,
        playerId: localPlayerId,
        state: 'background',
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _presenceWatchdogTimer?.cancel();
    super.dispose();
  }
}

class DuelLobbyPage extends StatefulWidget {
  const DuelLobbyPage({super.key, this.mode = DuelRoomMode.duel});

  final DuelRoomMode mode;

  @override
  State<DuelLobbyPage> createState() => _DuelLobbyPageState();
}

class DuelPlayerIdentity {
  const DuelPlayerIdentity({
    required this.playerId,
    required this.displayName,
    required this.isGuest,
    required this.pseudoSource,
    this.photoUrl,
  });

  final String playerId;
  final String displayName;
  final bool isGuest;
  final String pseudoSource;
  final String? photoUrl;
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
  late String _localPlayerId;
  String? _authenticatedPlayerId;
  PlayerProfile? _playerProfile;
  DuelPlayerIdentity? _duelIdentity;
  bool _identityResolved = false;

  @override
  void initState() {
    super.initState();
    _localPlayerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
    unawaited(_hydrateExistingAuthSession());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureLobbyAccess());
    });
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
    if (_authenticatedPlayerId == null) {
      return widget.mode == DuelRoomMode.credits
          ? 'Connectez-vous avec Google pour jouer en mode pari.'
          : 'Connectez-vous avec Google pour jouer en duel simple.';
    }
    if (!_shouldAskPseudo) {
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
      debugPrint('[DUEL_AUTH] user connecté ou invité: invité');
      return;
    }
    if (user.isAnonymous) {
      _localPlayerId = user.uid;
      debugPrint('[DUEL_AUTH] user connecté ou invité: invité anonyme');
      return;
    }
    await _upsertProfileFromGoogle(user);
  }

  Future<void> _ensureFirestoreIdentity() async {
    final User? user = _authService.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('GOOGLE_AUTH_REQUIRED');
    }
    _authenticatedPlayerId ??= user.uid;
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
        _nameController.text = profile.publicDisplayName;
      }
    });
  }

  bool get _shouldAskPseudo => false;

  bool _isUsablePseudo(String value) {
    final String cleaned = value.trim();
    return cleaned.isNotEmpty && cleaned.toLowerCase() != 'joueur';
  }

  Future<DuelPlayerIdentity> resolveDuelPlayerIdentity() async {
    final User? user = _authService.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('GOOGLE_AUTH_REQUIRED');
    }

    final String localProfilePseudo = _playerProfile?.displayName.trim() ?? '';
    if (_isUsablePseudo(localProfilePseudo)) {
      debugPrint('[DUEL_AUTH] user connecté ou invité: connecté uid=${user.uid}');
      debugPrint('[DUEL_AUTH] pseudo utilisé: $localProfilePseudo');
      debugPrint('[DUEL_AUTH] source du pseudo: local_state');
      debugPrint('[DUEL_AUTH] accès Duel autorisé');
      return DuelPlayerIdentity(
        playerId: user.uid,
        displayName: localProfilePseudo,
        isGuest: false,
        pseudoSource: 'local_state',
        photoUrl: user.photoURL,
      );
    }

    final PlayerProfile? profile = await _profileService.getProfile(user.uid);
    final String firestorePseudo = profile?.displayName.trim() ?? '';
    if (_isUsablePseudo(firestorePseudo)) {
      if (mounted) {
        setState(() {
          _playerProfile = profile;
        });
      }
      debugPrint('[DUEL_AUTH] user connecté ou invité: connecté uid=${user.uid}');
      debugPrint('[DUEL_AUTH] pseudo utilisé: $firestorePseudo');
      debugPrint('[DUEL_AUTH] source du pseudo: firestore');
      debugPrint('[DUEL_AUTH] accès Duel autorisé');
      return DuelPlayerIdentity(
        playerId: user.uid,
        displayName: firestorePseudo,
        isGuest: false,
        pseudoSource: 'firestore',
        photoUrl: user.photoURL,
      );
    }

    final String authDisplayName = user.displayName?.trim() ?? '';
    if (_isUsablePseudo(authDisplayName)) {
      debugPrint('[DUEL_AUTH] user connecté ou invité: connecté uid=${user.uid}');
      debugPrint('[DUEL_AUTH] pseudo utilisé: $authDisplayName');
      debugPrint('[DUEL_AUTH] source du pseudo: auth_state');
      debugPrint('[DUEL_AUTH] accès Duel autorisé');
      return DuelPlayerIdentity(
        playerId: user.uid,
        displayName: authDisplayName,
        isGuest: false,
        pseudoSource: 'auth_state',
        photoUrl: user.photoURL,
      );
    }

    throw StateError('MISSING_CONNECTED_PSEUDO');
  }

  Future<void> _resolveIdentityIfNeeded() async {
    if (_identityResolved || widget.mode == DuelRoomMode.credits) {
      return;
    }
    try {
      final DuelPlayerIdentity identity = await resolveDuelPlayerIdentity();
      if (!mounted) {
        return;
      }
      setState(() {
        _duelIdentity = identity;
        _identityResolved = true;
        _authenticatedPlayerId = identity.isGuest ? null : identity.playerId;
      });
    } on StateError catch (error) {
      if (error.message == 'GOOGLE_AUTH_REQUIRED') {
        return;
      }
      if (error.message != 'MISSING_CONNECTED_PSEUDO') {
        rethrow;
      }
      if (!mounted) {
        return;
      }
      debugPrint('[DUEL_AUTH] user connecté ou invité: connecté sans pseudo');
      debugPrint('[DUEL_AUTH] source du pseudo: nouvel enregistrement requis');
      setState(() {
        _duelIdentity = null;
        _identityResolved = true;
      });
    }
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

  Future<void> _ensureLobbyAccess() async {
    if (!mounted || _authService.currentUser != null) {
      if (widget.mode == DuelRoomMode.credits && _authenticatedPlayerId != null) {
        final bool hasCredit = await _hasPositiveCredit(_authenticatedPlayerId!);
        if (!mounted) {
          return;
        }
        if (!hasCredit) {
          await _showInsufficientCreditDialog();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
      return;
    }
    final bool shouldLogin = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GinoDecisionPopup(
                title: 'Connexion',
                message: widget.mode == DuelRoomMode.credits
                    ? 'Connecte-toi avec Google pour jouer en mode pari.'
                    : 'Connecte-toi avec Google pour jouer en duel simple.',
                primaryLabel: 'Google',
                secondaryLabel: 'Annuler',
                onPrimary: () => Navigator.of(context).pop(true),
                onSecondary: () => Navigator.of(context).pop(false),
              ),
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
      return;
    }
    if (widget.mode == DuelRoomMode.credits) {
      final bool hasCredit = await _hasPositiveCredit(_authenticatedPlayerId!);
      if (!mounted) {
        return;
      }
      if (!hasCredit) {
        await _showInsufficientCreditDialog();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<bool> _hasPositiveCredit(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection('user_profiles').doc(uid).get();
    final int credits = (snap.data()?['credits'] as num?)?.toInt() ?? 0;
    return credits > 0;
  }

  Future<void> _showInsufficientCreditDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Crédit insuffisant',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300),
          ),
          content: const Text(
            'Votre solde est insuffisant pour accéder au mode Pari. Veuillez contacter le service client ou l’administrateur afin de recharger votre compte.',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w300),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13C76B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Retour à l’accueil'),
            ),
          ],
        );
      },
    );
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
      roomMode: widget.mode,
    )..addListener(_onControllerChange);
    _controller = created;
    return created;
  }

  String? _resolvePlayerName() {
    if (_duelIdentity != null) {
      return _duelIdentity!.displayName;
    }
    if (_authenticatedPlayerId != null && !_shouldAskPseudo) {
      final String profileName = _playerProfile?.displayName.trim() ?? '';
      if (profileName.isNotEmpty) {
        return profileName;
      }
      final String authDisplayName = _authService.currentUser?.displayName?.trim() ?? '';
      if (authDisplayName.isNotEmpty) {
        return authDisplayName;
      }
      return 'Joueur-${_authenticatedPlayerId!.substring(0, 6)}';
    }
    return _nameController.text.trim();
  }

  Future<void> _createGame() async {
    unawaited(_sfx.playClick());
    try {
      await _ensureFirestoreIdentity();
    } on StateError catch (error) {
      if (error.message == 'GOOGLE_AUTH_REQUIRED') {
        unawaited(_sfx.playError());
        setState(() {
          _profileError = 'Connectez-vous avec Google pour continuer.';
        });
        return;
      }
      rethrow;
    } catch (e) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = 'Impossible de préparer la connexion Firebase: $e';
      });
      return;
    }
    await _resolveIdentityIfNeeded();
    final String? pseudoError = _validatePseudo();
    if (pseudoError != null) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = pseudoError;
      });
      return;
    }
    final String pseudo = _resolvePlayerName()!;
    if (widget.mode == DuelRoomMode.credits) {
      final String? uid = _authenticatedPlayerId;
      if (uid == null || !(await _hasPositiveCredit(uid))) {
        await _showInsufficientCreditDialog();
        return;
      }
    }
    final User? user = _authService.currentUser;
    if (_shouldAskPseudo && user != null && !user.isAnonymous) {
      final String cleanedPseudo = _profileService.sanitizeDisplayName(pseudo);
      await _profileService.updateDisplayName(uid: user.uid, displayName: cleanedPseudo);
      _duelIdentity = DuelPlayerIdentity(
        playerId: user.uid,
        displayName: cleanedPseudo,
        isGuest: false,
        pseudoSource: 'nouvel enregistrement',
        photoUrl: user.photoURL,
      );
      _authenticatedPlayerId = user.uid;
      _playerProfile = await _profileService.getProfile(user.uid);
      debugPrint('[DUEL_AUTH] pseudo utilisé: $cleanedPseudo');
      debugPrint('[DUEL_AUTH] source du pseudo: nouvel enregistrement');
      debugPrint('[DUEL_AUTH] accès Duel autorisé');
    }
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
    try {
      await _ensureFirestoreIdentity();
    } on StateError catch (error) {
      if (error.message == 'GOOGLE_AUTH_REQUIRED') {
        unawaited(_sfx.playError());
        setState(() {
          _profileError = 'Connectez-vous avec Google pour continuer.';
        });
        return;
      }
      rethrow;
    } catch (e) {
      unawaited(_sfx.playError());
      setState(() {
        _profileError = 'Impossible de préparer la connexion Firebase: $e';
      });
      return;
    }
    await _resolveIdentityIfNeeded();
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
    if (widget.mode == DuelRoomMode.credits) {
      final String? uid = _authenticatedPlayerId;
      if (uid == null || !(await _hasPositiveCredit(uid))) {
        await _showInsufficientCreditDialog();
        return;
      }
    }
    final User? user = _authService.currentUser;
    if (_shouldAskPseudo && user != null && !user.isAnonymous) {
      final String cleanedPseudo = _profileService.sanitizeDisplayName(pseudo);
      await _profileService.updateDisplayName(uid: user.uid, displayName: cleanedPseudo);
      _duelIdentity = DuelPlayerIdentity(
        playerId: user.uid,
        displayName: cleanedPseudo,
        isGuest: false,
        pseudoSource: 'nouvel enregistrement',
        photoUrl: user.photoURL,
      );
      _authenticatedPlayerId = user.uid;
      _playerProfile = await _profileService.getProfile(user.uid);
      debugPrint('[DUEL_AUTH] pseudo utilisé: $cleanedPseudo');
      debugPrint('[DUEL_AUTH] source du pseudo: nouvel enregistrement');
      debugPrint('[DUEL_AUTH] accès Duel autorisé');
    }
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
    final String title = creditsMode ? 'Mode pari' : 'Duel simple';
    return Scaffold(
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LeaderboardPage()),
          );
        },
        onOpenHistory: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GameHistoryPage()),
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
                    if (!isAuthenticated) ...<Widget>[
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Connexion Google requise pour continuer.',
                              style: TextStyle(
                                color: PremiumColors.textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _googleBusy ? null : _continueWithGoogle,
                              icon: const Icon(Icons.g_mobiledata_rounded),
                              label: const Text('Connexion Google'),
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

class _DuelPageState extends State<DuelPage> with WidgetsBindingObserver {
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

  StreamSubscription<List<DuelChatMessage>>? _chatSub;
  DuelBoardState? _board;
  String? _lastSessionUiKey;
  String? _lastEightPopupKey;
  String? _lastForcedDrawPopupKey;
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
  String? _lastRematchDeclineNotificationKey;
  DuelRematchUiState _rematchUiState = DuelRematchUiState.idle;
  String? _rematchErrorMessage;
  Timer? _rematchTimeoutTimer;
  WebPageLifecycleBinding? _webLifecycleBinding;
  bool _lifecycleExitTriggered = false;
  String? _rematchTimeoutRequestKey;
  String? _lastForfeitNotificationKey;
  final Queue<String> _chatPreviewQueue = Queue<String>();
  final StatsService _statsService = StatsService.instance;
  String? _activeChatPreview;
  Timer? _chatPreviewTimer;
  String? _lastOutcomeSfxKey;
  String? _lastStatsSyncKey;
  String? _lastOpponentActionSfxKey;
  String? _lastFunnyActionKey;
  bool _creditExitHandled = false;
  bool _funnyMessagesEnabled = true;
  final Duration comicMessageCooldown = const Duration(seconds: 8);
  DateTime? _lastComicMessageAt;
  DateTime? _lastImportantPopupOpenedAt;
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
  void _markImportantPopupOpened() {
    _lastImportantPopupOpenedAt = DateTime.now();
    _controller.startPresenceGracePeriod();
  }

  bool _wasImportantPopupRecentlyOpened() {
    final DateTime? openedAt = _lastImportantPopupOpenedAt;
    if (openedAt == null) {
      return false;
    }
    return DateTime.now().difference(openedAt) < const Duration(seconds: 3);
  }

  void _resetLocalRoundUiState() {
    _rematchDialogOpen = false;
    _rematchActionBusy = false;
    _stakeActionBusy = false;
    _stakeDialogOpen = false;
    _stakeSelectionDialogOpen = false;
    _stakeRejectedDialogOpen = false;
    _winDialogOpen = false;
    _rematchUiState = DuelRematchUiState.idle;
    _rematchErrorMessage = null;
    _rematchTimeoutTimer?.cancel();
    _rematchTimeoutTimer = null;
    _rematchTimeoutRequestKey = null;
    _pendingStakeOfferAfterVictoryKey = null;
    _pendingRematchAfterVictoryKey = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.startPresenceGracePeriod();
    _webLifecycleBinding = WebPageLifecycleBinding.install((String reason) {
      unawaited(_handleLifecycleExitSignal(reason));
    });
    _controller.addListener(_onControllerChange);
    _onControllerChange();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webLifecycleBinding?.dispose();
    _controller.removeListener(_onControllerChange);
    _chatSub?.cancel();
    _chatPreviewTimer?.cancel();
    _rematchTimeoutTimer?.cancel();
    _chatMessagesNotifier.dispose();
    FunnyGameToast.hide();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lifecycleExitTriggered = false;
      _controller.startPresenceGracePeriod();
      final DuelSession? current = _controller.session;
      if (current != null) {
        unawaited(_controller.service.updatePresenceHeartbeat(
          gameId: current.gameId,
          playerId: _controller.localPlayerId,
        ));
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      debugPrint('[Presence] lifecycle=$state, no abandon triggered');
      unawaited(_handleLifecycleExitSignal('app:${state.name}'));
    }
  }

  Future<void> _handleLifecycleExitSignal(String reason) async {
    final bool terminalSignal = reason.contains('beforeunload') || reason.contains('pagehide');
    if (terminalSignal && _lifecycleExitTriggered) {
      return;
    }
    if (terminalSignal) {
      _lifecycleExitTriggered = true;
    }
    debugPrint('[Presence] lifecycle exit signal=$reason');
    final DuelSession? session = _controller.session;
    if (session == null) {
      return;
    }
    try {
      await _controller.service.markPlayerPresenceState(
        gameId: session.gameId,
        playerId: _controller.localPlayerId,
        state: terminalSignal ? 'maybeOffline' : 'away',
      );
    } catch (_) {
      // Heartbeat watchdog will determine actual abandonment after timeout.
    }
  }

  void _onControllerChange() {
    final DuelSession? session = _controller.session;
    if (session == null || session.players.length < 2) {
      return;
    }
    final String sessionUiKey =
        '${session.gameId}_${session.revision}_${session.status.name}_${session.betFlowState.name}_${session.currentTurn}_${session.lastActionId}';
    if (_lastSessionUiKey == sessionUiKey) {
      return;
    }
    _lastSessionUiKey = sessionUiKey;

    final DuelBoardState snapshotBoard = DuelBoardState.fromSession(session);
    if (_board != snapshotBoard) {
      setState(() {
        _board = snapshotBoard;
      });
    }
    if (session.status == DuelGameStatus.inProgress &&
        (session.betFlowState == DuelBetFlowState.readyToStart ||
            session.betFlowState == DuelBetFlowState.rematchAccepted ||
            !_isCreditsMode)) {
      _resetLocalRoundUiState();
    }
    _updateRematchUiState(session);
    debugPrint(
      '[RematchParis] snapshot game=${session.gameId} status=${session.status.name} '
      'bet=${session.betFlowState.name} requestBy=${session.rematchRequestBy} '
      'decision=${session.rematchDecision.name}',
    );
    _bindChatRealtime(session);
    _maybeShowCommandPopup(session);
    _maybeShowForcedDrawPopup(session);
    _maybePlayOpponentActionSfx(session);
    _maybeShowFunnyGameMessage(session);
    _maybeHandleStakeFlow(session);
    _maybeHandleStakeRejected(session);
    _maybeHandleInsufficientFunds(session);
    _maybeHandleRematchFlow(session);
    _maybeHandleForfeitNotification(session);
    _maybeHandleNoCreditClosure(session);
    _maybeHandlePartyExit(session);
    _maybePromptMandatoryStake(session);
    _maybeShowWinPopup(session);
    _maybePlayRoundOutcomeSfx(session);
  }

  double _defaultProbabilityForTrigger(ComicMessageTrigger trigger) {
    switch (trigger) {
      case ComicMessageTrigger.mustDraw:
        return 0.14;
      case ComicMessageTrigger.strongActionAgainstPlayer:
        return 0.16;
      case ComicMessageTrigger.heavyDraw:
        return 0.25;
      case ComicMessageTrigger.tooManyCards:
        return 0.12;
      case ComicMessageTrigger.playedJoker:
        return 0.16;
      case ComicMessageTrigger.playedTwo:
        return 0.15;
      case ComicMessageTrigger.aceForced:
        return 0.13;
    }
  }

  bool shouldShowComicMessage({
    required ComicMessageTrigger trigger,
    double probability = 0.18,
  }) {
    if (!_funnyMessagesEnabled ||
        !mounted ||
        _controller.busy ||
        _isBlockingDialogOpen() ||
        _wasImportantPopupRecentlyOpened()) {
      return false;
    }
    if (FunnyGameToast.isVisible) {
      debugPrint('[ComicMessage] skipped: cooldown');
      return false;
    }
    final DateTime? lastShown = _lastComicMessageAt;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < comicMessageCooldown) {
      debugPrint('[ComicMessage] skipped: cooldown');
      return false;
    }
    final double clampedProbability = probability.clamp(0.0, 0.25);
    if (Random().nextDouble() > clampedProbability) {
      debugPrint('[ComicMessage] skipped: probability');
      return false;
    }
    return true;
  }

  void maybeShowComicMessage({
    required String targetPlayerId,
    required String currentPlayerId,
    required ComicMessageTrigger trigger,
    String? targetPlayerName,
  }) {
    if (targetPlayerId != currentPlayerId) {
      debugPrint('[ComicMessage] skipped: not target player');
      return;
    }
    final double probability = _defaultProbabilityForTrigger(trigger);
    if (!shouldShowComicMessage(trigger: trigger, probability: probability)) {
      return;
    }

    String message;
    FunnyMessageType type;
    switch (trigger) {
      case ComicMessageTrigger.mustDraw:
        message = 'Vas-y, pioche mon frère !!!';
        type = FunnyMessageType.difficulty;
      case ComicMessageTrigger.strongActionAgainstPlayer:
        final String playerName = (targetPlayerName ?? 'Joueur').trim();
        message = 'Oui, $playerName est sur toi-même.';
        type = FunnyMessageType.difficulty;
      case ComicMessageTrigger.heavyDraw:
        message = 'Est-ce que tu vas t’en sortir ?';
        type = FunnyMessageType.difficulty;
      case ComicMessageTrigger.tooManyCards:
        message = 'Djo, c’est éventail tu veux faire ou bien ?';
        type = FunnyMessageType.difficulty;
      case ComicMessageTrigger.playedJoker:
        message = 'Oui, tu as mis dans joker même.';
        type = FunnyMessageType.success;
      case ComicMessageTrigger.playedTwo:
        message = 'Oui, tu as mis dans deux même.';
        type = FunnyMessageType.success;
      case ComicMessageTrigger.aceForced:
        message = 'C’est As forcé hein, poto.';
        type = FunnyMessageType.difficulty;
    }

    _lastComicMessageAt = DateTime.now();
    debugPrint('[ComicMessage] show trigger=$trigger target=$targetPlayerId');
    FunnyGameToast.show(
      context,
      playerName: targetPlayerName ?? 'Joueur',
      message: message,
      type: type,
      alignment: Alignment.topCenter,
      duration: const Duration(milliseconds: 2500),
    );
  }

  void _maybeShowFunnyGameMessage(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null || session.lastActionId == null) {
      return;
    }
    if (_lastFunnyActionKey == session.lastActionId) {
      return;
    }
    _lastFunnyActionKey = session.lastActionId;
    final String localPlayerId = _controller.localPlayerId;
    if (action.type == DuelActionType.drawCard) {
      final bool isForcedDraw = action.payload['forcedDraw'] == true;
      if (isForcedDraw) {
        final int pendingDrawCount = session.pendingDrawCount;
        final ComicMessageTrigger trigger = pendingDrawCount >= 4
            ? ComicMessageTrigger.heavyDraw
            : ComicMessageTrigger.mustDraw;
        maybeShowComicMessage(
          targetPlayerId: action.actorId,
          currentPlayerId: localPlayerId,
          trigger: trigger,
          targetPlayerName: session.playerNames[action.actorId] ?? 'Joueur',
        );
        final List<String> targetHand = session.handForPlayer(action.actorId);
        if (targetHand.length > 10) {
          maybeShowComicMessage(
            targetPlayerId: action.actorId,
            currentPlayerId: localPlayerId,
            trigger: ComicMessageTrigger.tooManyCards,
            targetPlayerName: session.playerNames[action.actorId] ?? 'Joueur',
          );
        }
      }
      return;
    }
    if (action.type != DuelActionType.playCard) {
      return;
    }
    final String actorName = session.playerNames[action.actorId] ?? 'Joueur';
    final String targetId = session.players.firstWhere(
      (String id) => id != action.actorId,
      orElse: () => action.actorId,
    );
    final String targetName = session.playerNames[targetId] ?? 'Joueur';
    final String cardId = (action.payload['cardId'] as String?) ?? '';
    if (cardId.isEmpty) {
      return;
    }
    final DuelCard card = DuelCard.fromId(cardId);
    if (card.isJoker) {
      if (localPlayerId == action.actorId) {
        maybeShowComicMessage(
          targetPlayerId: action.actorId,
          currentPlayerId: localPlayerId,
          trigger: ComicMessageTrigger.playedJoker,
          targetPlayerName: actorName,
        );
      } else {
        maybeShowComicMessage(
          targetPlayerId: targetId,
          currentPlayerId: localPlayerId,
          trigger: ComicMessageTrigger.heavyDraw,
          targetPlayerName: targetName,
        );
      }
      return;
    }
    if (card.rank == '2') {
      if (localPlayerId == action.actorId) {
        maybeShowComicMessage(
          targetPlayerId: action.actorId,
          currentPlayerId: localPlayerId,
          trigger: ComicMessageTrigger.playedTwo,
          targetPlayerName: actorName,
        );
      } else {
        maybeShowComicMessage(
          targetPlayerId: targetId,
          currentPlayerId: localPlayerId,
          trigger: ComicMessageTrigger.mustDraw,
          targetPlayerName: targetName,
        );
      }
      return;
    }
    if (card.rank == 'A') {
      maybeShowComicMessage(
        targetPlayerId: targetId,
        currentPlayerId: localPlayerId,
        trigger: ComicMessageTrigger.aceForced,
        targetPlayerName: targetName,
      );
      return;
    }
    if (card.rank == '8') {
      maybeShowComicMessage(
        targetPlayerId: targetId,
        currentPlayerId: localPlayerId,
        trigger: ComicMessageTrigger.strongActionAgainstPlayer,
        targetPlayerName: targetName,
      );
      return;
    }
    final List<String> localHand = session.handForPlayer(localPlayerId);
    if (localHand.length > 10) {
      maybeShowComicMessage(
        targetPlayerId: localPlayerId,
        currentPlayerId: localPlayerId,
        trigger: ComicMessageTrigger.tooManyCards,
        targetPlayerName: session.playerNames[localPlayerId] ?? 'Joueur',
      );
    }
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
            _chatMessagesNotifier.value = List<DuelChatMessage>.unmodifiable(ordered);
            final bool hadError = _chatError != null;
            _chatError = null;
            if (unreadDelta > 0 || hadError) {
              setState(() {
                _unreadChatCount += unreadDelta;
              });
            }
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

  void _showSnackBar(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.trim()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
      if (move.rejectionMessage != null && move.rejectionMessage!.trim().isNotEmpty) {
        _showSnackBar(move.rejectionMessage!);
      }
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
    _markImportantPopupOpened();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GinoChooseSuitPopup(
            suits: const <String>['♥', '♠', '♣', '♦'],
            onSuitSelected: (String suit) => Navigator.of(dialogContext).pop(suit),
          ),
        );
      },
    );
  }

  Future<void> _showOpponentEightPopup({
    required String actorName,
    required String suit,
  }) async {
    _markImportantPopupOpened();
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
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GinoOpponentCommandPopup(
            playerName: actorName,
            suit: suit,
          ),
        );
      },
    );
  }

  Future<void> _showForcedDrawPopup(int amount) async {
    _markImportantPopupOpened();
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
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GinoDrawPenaltyPopup(
            cardsToDraw: amount,
            rank: amount >= 8 ? '8' : '2',
            suit: amount >= 8 ? 'spades' : 'diamonds',
          ),
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
        : (card.rank == '2' ? 2 : 8);
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
      _resolveName(session, playerId);

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
    if (_isCreditsMode &&
        session.stakeOffer.status == DuelStakeStatus.accepted &&
        !session.payoutDone) {
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
      await _statsService.recordDuelResult(
        gameId: session.gameId,
        round: session.round,
        winnerId: winnerId,
        loserId: loserId,
        winnerCreditsDelta: 0,
        loserCreditsDelta: 0,
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
        _hasEnoughCredit(session, minimum: 1) &&
        session.activeStakeCredits <= 0 &&
        !session.stakeOffer.isPending;
  }

  int _creditsOf(DuelSession session, String playerId) =>
      session.playerCredits[playerId] ?? 1000;

  bool _hasEnoughCredit(DuelSession session, {required int minimum}) =>
      _creditsOf(session, _controller.localPlayerId) >= minimum;

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
      opponentName: opponentId.isEmpty ? 'Adversaire' : _displayNameUpper(session, opponentId),
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
    required String opponentName,
    required int myCredits,
    required int? opponentCredits,
  }) async {
    if (_stakeSelectionDialogOpen) {
      return null;
    }
    _stakeSelectionDialogOpen = true;
    _markImportantPopupOpened();
    final TextEditingController amountController = TextEditingController();
    int? selectedAmount;
    String? validationError;
    final List<int> options = <int>[100, 250, 500, 1000, 2000];
    final int? selected = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
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

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GinoBetProposalPopup(
                      opponentName: opponentName,
                      presetAmounts: options,
                      selectedAmount: selectedAmount,
                      amountController: amountController,
                      validationError: validationError,
                      onAmountChanged: (String value) {
                        final int? parsed = int.tryParse(value.trim());
                        setModalState(() {
                          selectedAmount = parsed;
                          validationError = validate(parsed);
                        });
                      },
                      onSelectAmount: selectAmount,
                      onCancel: () => Navigator.of(context).pop(),
                      onValidate: () {
                        final int? parsed = int.tryParse(amountController.text.trim());
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
                    ),
                  ],
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
      return 'Crédit insuffisant\nVous ne disposez pas d’un solde suffisant pour proposer cette mise. Veuillez recharger votre compte auprès du service client ou de l’administrateur.';
    }
    if (opponentCredits != null && amount > opponentCredits) {
      return 'Mise refusée: le crédit adverse est insuffisant.';
    }
    return null;
  }

  Future<void> _showStakeDecisionDialog(DuelSession session) async {
    final DuelStakeOffer offer = session.stakeOffer;
    final String proposer = _displayNameUpper(session, offer.proposedBy ?? '');
    final int myCredits = _creditsOf(session, _controller.localPlayerId);
    final bool insufficient = myCredits < offer.amount;
    _stakeDialogOpen = true;
    _markImportantPopupOpened();
    final String? decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GinoIncomingBetPopup(
                proposerName: proposer,
                amount: offer.amount,
                acceptEnabled: !insufficient,
                onAccept: () => Navigator.of(dialogContext).pop('accept'),
                onRefuse: () => Navigator.of(dialogContext).pop('refuse'),
              ),
            ],
          ),
        );
      },
    );
    _stakeDialogOpen = false;
    if (decision == null || _stakeActionBusy) {
      if (insufficient) {
        _showStakeRequiredMessage(
          'Crédit insuffisant\nVotre solde est insuffisant. Veuillez contacter le service client ou l’administrateur pour recharger votre compte.',
        );
      }
      return;
    }
    if (decision == 'refuse' && insufficient) {
      _showStakeRequiredMessage(
        'Crédit insuffisant\nVotre solde est insuffisant. Veuillez contacter le service client ou l’administrateur pour recharger votre compte.',
      );
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
    _markImportantPopupOpened();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoDecisionPopup(
            title: 'Mise refusée',
            message: '$rejecterName a refusé cette mise.',
            primaryLabel: 'Valider',
            secondaryLabel: 'Retour menu',
            onPrimary: () => Navigator.of(dialogContext).pop(),
            onSecondary: () {
              Navigator.of(dialogContext).pop();
              unawaited(_exitPartyFlow());
            },
          ),
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
    if (_isCreditsMode && !_hasEnoughCredit(session, minimum: 1)) {
      return;
    }
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
    if (session == null || session.status != DuelGameStatus.finished) {
      return;
    }
    if (_isCreditsMode && !_hasEnoughCredit(session, minimum: 1)) {
      await _showCreditExhaustedDialog();
      if (mounted) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
      return;
    }
    setState(() {
      _rematchActionBusy = true;
      _rematchErrorMessage = null;
    });
    try {
      debugPrint('[RematchParis] replay tap by=${_controller.localPlayerId} game=${session.gameId}');
      if (session.rematchRequestBy != null &&
          session.rematchRequestBy != _controller.localPlayerId) {
        await _controller.acceptRematch();
      } else {
        await _controller.requestRematch();
        final DuelSession? latest = _controller.session;
        if (latest != null && _canPromptRematchStake(latest)) {
          await _openStakeProposal(latest);
        }
      }
    } catch (error) {
      debugPrint('[RematchParis] failed: $error');
      if (mounted) {
        setState(() {
          _rematchUiState = DuelRematchUiState.rematchError;
          _rematchErrorMessage = 'Impossible de lancer la revanche. Vérifie ta connexion et réessaie.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lancer la revanche. Vérifie ta connexion et réessaie.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _rematchActionBusy = false;
        });
      }
    }
  }

  Future<void> _onCancelRematchTap() async {
    if (_rematchActionBusy) {
      return;
    }
    final DuelSession? session = _controller.session;
    final bool isPendingRequester = session != null &&
        session.status == DuelGameStatus.finished &&
        session.rematchRequestBy == _controller.localPlayerId &&
        session.rematchDecision == DuelRematchDecision.pending;
    if (!isPendingRequester) {
      return;
    }
    setState(() {
      _rematchActionBusy = true;
    });
    try {
      await _controller.cancelRematchRequest();
    } catch (error) {
      debugPrint('[RematchParis] failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lancer la revanche. Vérifie ta connexion et réessaie.'),
          ),
        );
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
    if (session == null) {
      return;
    }
    if (session.status == DuelGameStatus.inProgress && session.players.length == 2) {
      await _controller.forfeitMatch();
    } else if (_isCreditsMode) {
      await _controller.exitBetParty();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<bool> _confirmLeaveGame() async {
    final DuelSession? session = _controller.session;
    if (session == null ||
        session.status != DuelGameStatus.inProgress ||
        session.players.length < 2) {
      return true;
    }
    final bool? shouldQuit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoDecisionPopup(
            title: 'Quitter la partie ?',
            message: _isCreditsMode
                ? 'Si vous quittez maintenant, vous perdez la mise.'
                : 'Si vous quittez maintenant, vous perdez la manche.',
            primaryLabel: 'Quitter',
            secondaryLabel: 'Rester',
            onPrimary: () => Navigator.of(dialogContext).pop(true),
            onSecondary: () => Navigator.of(dialogContext).pop(false),
          ),
        );
      },
    );
    if (shouldQuit != true) {
      return false;
    }
    await _exitPartyFlow();
    return true;
  }

  Future<void> _handleBackNavigation() async {
    final bool leave = await _confirmLeaveGame();
    if (!leave && mounted) {
      unawaited(_sfx.playClick());
    }
  }

  Future<void> _showRematchConfirmDialog({
    required DuelSession session,
    required String requesterId,
  }) async {
    final String requester = _displayNameUpper(session, requesterId);
    _rematchDialogOpen = true;
    _markImportantPopupOpened();
    final bool? accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoDecisionPopup(
            title: 'Revanche proposée',
            message: '$requester demande une revanche.',
            primaryLabel: 'Accepter',
            secondaryLabel: 'Refuser',
            onPrimary: () => Navigator.of(dialogContext).pop(true),
            onSecondary: () => Navigator.of(dialogContext).pop(false),
          ),
        );
      },
    );
    _rematchDialogOpen = false;
    if (accepted == null || _rematchActionBusy) {
      return;
    }
    setState(() {
      _rematchActionBusy = true;
      _rematchErrorMessage = null;
    });
    try {
      if (accepted) {
        await _controller.acceptRematch();
      } else {
        await _controller.declineRematch();
      }
    } catch (error) {
      debugPrint('[RematchParis] failed: $error');
      if (mounted) {
        setState(() {
          _rematchUiState = DuelRematchUiState.rematchError;
          _rematchErrorMessage = 'Impossible de lancer la revanche. Vérifie ta connexion et réessaie.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lancer la revanche. Vérifie ta connexion et réessaie.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _rematchActionBusy = false;
        });
      }
    }
  }

  void _maybeHandleRematchFlow(DuelSession session) {
    if (session.rematchDecision == DuelRematchDecision.declined) {
      final String key =
          '${session.round}_${session.rematchDecisionBy ?? ''}_${session.rematchRequestedAt?.millisecondsSinceEpoch ?? 0}';
      if (_lastRematchDeclineNotificationKey == key) {
        return;
      }
      _lastRematchDeclineNotificationKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre adversaire a refusé la revanche.')),
        );
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

  void _updateRematchUiState(DuelSession session) {
    if (session.status == DuelGameStatus.inProgress) {
      _rematchTimeoutTimer?.cancel();
      _rematchTimeoutTimer = null;
      _rematchTimeoutRequestKey = null;
      if (_rematchUiState != DuelRematchUiState.idle) {
        setState(() {
          _rematchUiState = DuelRematchUiState.rematchAcceptedStarting;
          _rematchErrorMessage = null;
        });
      }
      return;
    }
    if (session.rematchDecision == DuelRematchDecision.declined) {
      _rematchTimeoutTimer?.cancel();
      _rematchTimeoutTimer = null;
      _rematchTimeoutRequestKey = null;
      if (_rematchUiState != DuelRematchUiState.rematchRejected) {
        setState(() {
          _rematchUiState = DuelRematchUiState.rematchRejected;
        });
      }
      return;
    }
    final String? requesterId = session.rematchRequestBy;
    final bool pendingRequest = session.status == DuelGameStatus.finished &&
        requesterId != null &&
        requesterId.isNotEmpty &&
        session.rematchDecision == DuelRematchDecision.pending;
    if (!pendingRequest) {
      _rematchTimeoutTimer?.cancel();
      _rematchTimeoutTimer = null;
      _rematchTimeoutRequestKey = null;
      if (_rematchUiState != DuelRematchUiState.idle &&
          _rematchUiState != DuelRematchUiState.rematchError) {
        setState(() {
          _rematchUiState = DuelRematchUiState.idle;
        });
      }
      return;
    }
    if (requesterId == _controller.localPlayerId) {
      if (_rematchUiState != DuelRematchUiState.waitingForOpponentResponse) {
        setState(() {
          _rematchUiState = DuelRematchUiState.waitingForOpponentResponse;
        });
      }
      if (session.stakeOffer.isPending) {
        _scheduleStakeResponseTimeout(session);
      } else {
        _scheduleRematchTimeout(session);
      }
      return;
    }
    _rematchTimeoutTimer?.cancel();
    _rematchTimeoutTimer = null;
    _rematchTimeoutRequestKey = null;
    if (_rematchUiState != DuelRematchUiState.rematchRequestReceived) {
      setState(() {
        _rematchUiState = DuelRematchUiState.rematchRequestReceived;
      });
    }
  }

  void _scheduleRematchTimeout(DuelSession session) {
    final DateTime? requestedAt = session.rematchRequestedAt?.toUtc();
    if (requestedAt == null) {
      return;
    }
    final String requestKey =
        '${session.gameId}_${session.rematchRequestBy}_${requestedAt.millisecondsSinceEpoch}';
    if (_rematchTimeoutRequestKey == requestKey) {
      return;
    }
    _rematchTimeoutTimer?.cancel();
    _rematchTimeoutRequestKey = requestKey;
    final Duration elapsed = DateTime.now().toUtc().difference(requestedAt);
    final Duration waitFor = elapsed >= _kRematchRequestTimeout
        ? Duration.zero
        : _kRematchRequestTimeout - elapsed;
    _rematchTimeoutTimer = Timer(waitFor, () async {
      if (!mounted) {
        return;
      }
      final DuelSession? latest = _controller.session;
      if (latest == null ||
          latest.rematchRequestBy != _controller.localPlayerId ||
          latest.rematchDecision != DuelRematchDecision.pending ||
          latest.status != DuelGameStatus.finished) {
        return;
      }
      setState(() {
        _rematchUiState = DuelRematchUiState.rematchError;
        _rematchErrorMessage = 'L’adversaire n’a pas répondu.';
        _rematchActionBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L’adversaire n’a pas répondu.')),
      );
      try {
        await _controller.cleanupExpiredRematchRequest();
      } catch (error) {
        debugPrint('[RematchParis] failed: $error');
      }
    });
  }

  void _scheduleStakeResponseTimeout(DuelSession session) {
    final DateTime? proposedAt = session.stakeOffer.createdAt?.toUtc();
    if (proposedAt == null) {
      _scheduleRematchTimeout(session);
      return;
    }
    final String requestKey =
        '${session.gameId}_${session.rematchRequestBy}_${proposedAt.millisecondsSinceEpoch}_${session.stakeOffer.amount}';
    if (_rematchTimeoutRequestKey == requestKey) {
      return;
    }
    _rematchTimeoutTimer?.cancel();
    _rematchTimeoutRequestKey = requestKey;
    final Duration elapsed = DateTime.now().toUtc().difference(proposedAt);
    final Duration waitFor = elapsed >= _kRematchRequestTimeout
        ? Duration.zero
        : _kRematchRequestTimeout - elapsed;
    _rematchTimeoutTimer = Timer(waitFor, () async {
      if (!mounted) {
        return;
      }
      final DuelSession? latest = _controller.session;
      if (latest == null ||
          latest.rematchRequestBy != _controller.localPlayerId ||
          !latest.stakeOffer.isPending ||
          latest.status != DuelGameStatus.finished) {
        return;
      }
      setState(() {
        _rematchUiState = DuelRematchUiState.rematchError;
        _rematchErrorMessage = 'L’adversaire n’a pas répondu.';
        _rematchActionBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L’adversaire n’a pas répondu.')),
      );
      try {
        await _controller.cancelRematchRequest();
      } catch (error) {
        debugPrint('[RematchParis] failed: $error');
      }
    });
  }

  void _maybeHandleForfeitNotification(DuelSession session) {
    final DuelAction? action = session.lastAction;
    if (action == null || action.type != DuelActionType.forfeit) {
      return;
    }
    final String key =
        '${session.gameId}_${session.round}_${action.createdAt.toIso8601String()}';
    if (_lastForfeitNotificationKey == key) {
      return;
    }
    _lastForfeitNotificationKey = key;
    final String quitterId = action.actorId;
    final String winnerId = action.payload['winnerId'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (winnerId == _controller.localPlayerId) {
        return;
      } else if (quitterId == _controller.localPlayerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous avez quitté la partie. Manche perdue.')),
        );
      }
    });
  }

  void _maybeHandlePartyExit(DuelSession session) {
    final bool shouldForceExit = session.betFlowState == DuelBetFlowState.partyExited ||
        session.exitBothPlayers ||
        session.abandonedBy != null;
    if (!shouldForceExit) {
      return;
    }
    final String key =
        '${session.round}_${session.exitedBy ?? ''}_${session.abandonedBy ?? ''}_${session.exitBothPlayers}';
    if (_lastExitKey == key) {
      return;
    }
    _lastExitKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String? abandonedBy = session.abandonedBy;
      if (abandonedBy != null && abandonedBy != _controller.localPlayerId) {
        _showOpponentLeftPopup(session);
        return;
      }
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    });
  }

  void _maybeHandleNoCreditClosure(DuelSession session) {
    if (!_isCreditsMode || session.roomStatus != 'closed' || _creditExitHandled) {
      return;
    }
    final bool localNoCredit =
        (session.playerCredits[_controller.localPlayerId] ?? 0) <= 0;
    if (session.closeReason != 'opponent_no_credit' && !localNoCredit) {
      return;
    }
    _creditExitHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (localNoCredit) {
        await _showCreditExhaustedDialog();
      } else {
        await _showOpponentNoCreditDialog();
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    });
  }

  Future<void> _showCreditExhaustedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Solde épuisé',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300),
          ),
          content: const Text(
            'Votre crédit est épuisé. Vous ne pouvez plus continuer en mode Pari. Veuillez contacter le service client ou l’administrateur pour recharger votre compte.',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w300),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13C76B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Retour à l’accueil'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpponentNoCreditDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Partie terminée',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300),
          ),
          content: const Text(
            'Votre adversaire n’a plus de crédit disponible. La partie est terminée.',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w300),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13C76B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Retour'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpponentLeftPopup(DuelSession session) async {
    if (_winDialogOpen || _isBlockingDialogOpen()) {
      return;
    }
    _winDialogOpen = true;
    _markImportantPopupOpened();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoDecisionPopup(
            title: 'Adversaire parti',
            message: _isCreditsMode
                ? 'Votre adversaire a quitté la partie. Vous remportez la mise.'
                : 'Votre adversaire a quitté la partie. Vous gagnez la manche.',
            primaryLabel: 'Retour',
            secondaryLabel: 'Nouvelle partie',
            onPrimary: () => Navigator.of(dialogContext).pop(),
            onSecondary: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
    _winDialogOpen = false;
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> _showWinPopup({required int gainAmount}) async {
    _winDialogOpen = true;
    _markImportantPopupOpened();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoVictoryPopup(
            title: 'Victoire',
            message: 'Vous avez gagné la manche.',
            wonAmount: gainAmount,
            onBackToMenu: () => Navigator.of(dialogContext).pop(),
          ),
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
            ? 'Joueur 2'
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
        final Size screenSize = MediaQuery.sizeOf(context);
        final bool isCompactDuelLayout = screenSize.height <= 860 || screenSize.width <= 393;
        final double sectionGap = isCompactDuelLayout ? 5 : 8;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (didPop) {
              return;
            }
            unawaited(_handleBackNavigation());
          },
          child: Scaffold(
            backgroundColor: PremiumColors.tableGreenDark,
            body: Stack(
              children: <Widget>[
              TableBackground(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, topInset + 1, 12, isCompactDuelLayout ? 6 : 10),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              unawaited(_handleBackNavigation());
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
                                  _isCreditsMode ? 'Mode pari' : 'Duel',
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
                                  const CreditCoinsIcon(size: 16),
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
                      SizedBox(height: isCompactDuelLayout ? 1 : 2),
                      _DuelStatusBanner(
                        opponentName: opponentName,
                        myScore: myScore,
                        opponentScore: opponentScore,
                        round: session.round,
                        compact: isCompactDuelLayout,
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
                      SizedBox(height: sectionGap),
                      _OpponentRow(
                        name: opponentName,
                        count: getOpponentCardCount(session, _controller.localPlayerId),
                        wins: opponentScore,
                        losses: myScore,
                        fallbackInitial: opponentName.isNotEmpty ? opponentName[0] : '?',
                        avatarCard: opponentAvatarCard,
                        compact: isCompactDuelLayout,
                      ),
                      SizedBox(height: sectionGap),
                      _CenterArea(
                        discardPile: board.discardPile,
                        drawCount: board.drawPile.length,
                        canDraw: myTurn && board.canDraw(_controller.localPlayerId),
                        onDrawTap: _onDrawTap,
                        overlay: texts.overlay,
                        requiredSuit: board.requiredSuit,
                        mustDraw: myTurn && board.pendingDraw > 0,
                        compact: isCompactDuelLayout,
                      ),
                      SizedBox(height: sectionGap),
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
                        cardScale: isCompactDuelLayout ? 0.9 : 0.94,
                        minCardsViewportHeight: isCompactDuelLayout ? 210 : 190,
                      ),
                      SizedBox(height: isCompactDuelLayout ? 4 : 6),
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
                          session.rematchDecision != DuelRematchDecision.accepted &&
                          (!_isCreditsMode || _hasEnoughCredit(session, minimum: 1)) &&
                          (_isLocalLoser(session) ||
                              (session.rematchRequestBy != null &&
                                  session.rematchRequestBy != _controller.localPlayerId)))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: _rematchUiState == DuelRematchUiState.waitingForOpponentResponse
                                ? Column(
                                    children: <Widget>[
                                      GinoDisabledPopupButton(
                                        label: session.stakeOffer.isPending
                                            ? 'En attente de l’accord de l’adversaire'
                                            : 'En attente de l’adversaire',
                                      ),
                                      const SizedBox(height: 8),
                                      GinoPopupButton(
                                        label: 'Annuler la demande',
                                        onPressed: () {
                                          unawaited(_sfx.playClick());
                                          _onCancelRematchTap();
                                        },
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: <Widget>[
                                      GinoPopupButton(
                                        label: session.rematchRequestBy != null &&
                                                session.rematchRequestBy != _controller.localPlayerId
                                            ? 'Accepter la revanche'
                                            : 'Demander revanche',
                                        onPressed: () {
                                          unawaited(_sfx.playClick());
                                          _onReplayTap();
                                        },
                                      ),
                                      if (_rematchUiState == DuelRematchUiState.rematchRejected)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Revanche refusée.',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                      if (_rematchUiState == DuelRematchUiState.rematchError)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            _rematchErrorMessage ??
                                                'Impossible de lancer la revanche. Vérifie ta connexion et réessaie.',
                                            style: const TextStyle(color: Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
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
  String get color => isRed ? 'red' : 'black';

  bool isSameColorAsSuit(String suitRef) {
    return color == colorFromSuit(suitRef);
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

  static String colorFromSuit(String suitRef) {
    return (suitRef == '♥' || suitRef == '♦') ? 'red' : 'black';
  }
}

class DuelMoveResult {
  const DuelMoveResult({
    required this.accepted,
    this.payload = const <String, dynamic>{},
    this.nextTurn,
    this.rejectionMessage,
  });

  final bool accepted;
  final Map<String, dynamic> payload;
  final String? nextTurn;
  final String? rejectionMessage;
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
    required this.requiredColorAfterJoker,
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
  final String? requiredColorAfterJoker;
  final String overlay;
  final String status;
  final int round;

  int get player1Count => players.isNotEmpty ? handOf(players.first).length : 0;
  int get player2Count => players.length > 1 ? handOf(players[1]).length : 0;
  int get totalCardCount =>
      (players.isNotEmpty ? handOf(players.first).length : 0) +
      (players.length > 1 ? handOf(players[1]).length : 0) +
      drawPile.length +
      discardPile.length;

  factory DuelBoardState.fromSession(DuelSession session) {
    if (!session.deckInitialized || session.players.length < 2) {
      return DuelBoardState.initial(
        gameId: session.gameId,
        players: session.players,
        round: session.round,
      );
    }
    final String p1 = session.players.first;
    final String p2 = session.players[1];
    final List<DuelCard> discardCards = session.discardPile
        .map(DuelCard.fromId)
        .toList();
    final DuelCard top = session.topDiscard != null
        ? DuelCard.fromId(session.topDiscard!)
        : (discardCards.isNotEmpty
            ? discardCards.last
            : const DuelCard(suit: '♥', rank: 'A'));
    return DuelBoardState._(
      gameId: session.gameId,
      players: session.players,
      drawPile: session.drawPile.map(DuelCard.fromId).toList(),
      discardPile: discardCards,
      hands: <String, List<DuelCard>>{
        p1: session.player1Hand.map(DuelCard.fromId).toList(),
        p2: session.player2Hand.map(DuelCard.fromId).toList(),
      },
      discardTop: top,
      requiredSuit: session.requiredSuit,
      pendingDraw: session.pendingDrawCount,
      forcedDrawInitial: session.forcedDrawInitial,
      aceColorRequired: session.aceColorRequired,
      requiredColorAfterJoker: session.requiredColorAfterJoker,
      overlay: '',
      status: '',
      round: session.round,
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    final String p1 = players.isNotEmpty ? players.first : '';
    final String p2 = players.length > 1 ? players[1] : '';
    final List<String> p1Hand = p1.isEmpty
        ? const <String>[]
        : handOf(p1).map((DuelCard c) => c.id).toList();
    final List<String> p2Hand = p2.isEmpty
        ? const <String>[]
        : handOf(p2).map((DuelCard c) => c.id).toList();
    final List<String> drawIds = drawPile.map((DuelCard c) => c.id).toList();
    final List<String> discardIds = discardPile.map((DuelCard c) => c.id).toList();
    final DuelCard? top = discardIds.isEmpty ? null : discardPile.last;
    return <String, dynamic>{
      'player1Hand': p1Hand,
      'player2Hand': p2Hand,
      'drawPile': drawIds,
      'discardPile': discardIds,
      'topDiscard': top?.id,
      'player1CardCount': p1Hand.length,
      'player2CardCount': p2Hand.length,
      'deckInitialized': true,
      'pendingDrawCount': pendingDraw,
      'forcedDrawInitial': forcedDrawInitial,
      'requiredSuit': requiredSuit,
      'requiredColorAfterJoker': requiredColorAfterJoker,
      'aceColorRequired': aceColorRequired,
    };
  }

  factory DuelBoardState.initial({
    required String gameId,
    required List<String> players,
    required int round,
  }) {
    final Random random = Random(_stableDeckSeed(gameId, round));
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
      requiredColorAfterJoker: null,
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

  DuelBoardState applyValidatedAction(DuelAction action) => _apply(action);

  List<DuelCard> handOf(String playerId) => hands[playerId] ?? <DuelCard>[];

  bool canPlay(String actorId, DuelCard card) {
    if (!handOf(actorId).any((DuelCard c) => c.id == card.id)) {
      return false;
    }
    if (pendingDraw > 0) {
      return false;
    }
    if (aceColorRequired) {
      return card.rank == 'A';
    }
    if (requiredColorAfterJoker != null &&
        !_matchesRequiredJokerColor(requiredColorAfterJoker!, card)) {
      return false;
    }
    if (card.rank == '8') {
      return true;
    }
    if (card.isJoker) {
      final String colorRefSuit = requiredSuit ?? discardTop.suit;
      if (requiredSuit != null) {
        return false;
      }
      return card.color == DuelCard.colorFromSuit(colorRefSuit);
    }
    if (requiredSuit != null) {
      return card.suit == requiredSuit || card.rank == discardTop.rank;
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
      if (requiredColorAfterJoker == 'red' &&
          !_matchesRequiredJokerColor('red', card)) {
        debugPrint('[JokerRule] card rejected: wrong color');
        return const DuelMoveResult(
          accepted: false,
          rejectionMessage: 'Vous devez jouer une carte rouge.',
        );
      }
      if (requiredColorAfterJoker == 'black' &&
          !_matchesRequiredJokerColor('black', card)) {
        debugPrint('[JokerRule] card rejected: wrong color');
        return const DuelMoveResult(
          accepted: false,
          rejectionMessage: 'Vous devez jouer une carte noire.',
        );
      }
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
    String? newRequiredColorAfterJoker = requiredColorAfterJoker;
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
      if (newRequiredColorAfterJoker != null) {
        debugPrint('[JokerRule] required color active=$newRequiredColorAfterJoker');
      }
      newOverlay = '${action.actorId} pioche';
      newStatus = newPendingDraw > 0
          ? '$newPendingDraw cartes à piocher'
          : '${action.actorId} a pioché.';
    }

    if (action.type == DuelActionType.playCard) {
      final DuelCard card = DuelCard.fromId(action.payload['cardId'] as String);
      final List<DuelCard>? actorCards = newHands[action.actorId];
      if (actorCards != null) {
        final int cardIndex = actorCards.indexWhere((DuelCard c) => c.id == card.id);
        if (cardIndex >= 0) {
          actorCards.removeAt(cardIndex);
        }
      }
      newTop = card;
      newDiscardPile.add(card);
      newRequiredSuit = null;
      newOverlay = '${action.actorId} a joué ${card.label}';
      newStatus = newOverlay;

      if (newRequiredColorAfterJoker != null &&
          _matchesRequiredJokerColor(newRequiredColorAfterJoker, card)) {
        newRequiredColorAfterJoker = null;
        debugPrint('[JokerRule] required color cleared');
      }

      if (card.rank == '8') {
        newRequiredSuit = action.payload['chosenSuit'] as String? ?? '♥';
        newOverlay = '${action.actorId} a commandé $newRequiredSuit';
        newStatus = 'Couleur demandée: $newRequiredSuit';
      } else if (card.rank == '2') {
        newPendingDraw += 2;
        newForcedDrawInitial = newPendingDraw;
        newOverlay = '+2';
        newStatus = '$newPendingDraw cartes à piocher';
      } else if (card.isJoker) {
        newRequiredColorAfterJoker = card.color;
        debugPrint('[JokerRule] joker played color=${card.color}');
        debugPrint('[JokerRule] required color active=$newRequiredColorAfterJoker');
        newPendingDraw += 8;
        newForcedDrawInitial = newPendingDraw;
        newOverlay = '+8';
        newStatus = '$newPendingDraw cartes à piocher';
      } else if (card.rank == 'A') {
        newAceRequired = !newAceRequired;
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
      newRequiredColorAfterJoker = null;
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
      requiredColorAfterJoker: newRequiredColorAfterJoker,
      overlay: newOverlay,
      status: newStatus,
      round: round,
    );
  }

  static bool _matchesRequiredJokerColor(String requiredColor, DuelCard card) {
    if (requiredColor == 'red') {
      return card.isRed;
    }
    return !card.isRed;
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

int _stableDeckSeed(String gameId, int round) {
  final String value = '$gameId#$round';
  int hash = 2166136261;
  for (final int rune in value.runes) {
    hash ^= rune;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash;
}

class DuelGameStateValidationResult {
  const DuelGameStateValidationResult({
    required this.isValid,
    required this.errors,
    required this.autoCorrectPatch,
    this.integrityError,
  });

  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> autoCorrectPatch;
  final Map<String, dynamic>? integrityError;

  bool get hasOnlyAutoCorrectableIssues =>
      !isValid && integrityError == null && autoCorrectPatch.isNotEmpty;
}

DuelGameStateValidationResult validateGameState(DuelSession session) {
  final List<String> errors = <String>[];
  final Map<String, dynamic> patch = <String, dynamic>{};
  final List<String> allCards = <String>[
    ...session.player1Hand,
    ...session.player2Hand,
    ...session.drawPile,
    ...session.discardPile,
  ];
  final Map<String, List<String>> locationsByCard = <String, List<String>>{};
  void collect(String zone, List<String> cards) {
    for (final String card in cards) {
      locationsByCard.putIfAbsent(card, () => <String>[]).add(zone);
    }
  }

  collect('player1Hand', session.player1Hand);
  collect('player2Hand', session.player2Hand);
  collect('drawPile', session.drawPile);
  collect('discardPile', session.discardPile);

  final int computedP1 = session.player1Hand.length;
  final int computedP2 = session.player2Hand.length;
  if (session.player1CardCount != computedP1) {
    errors.add('player1CardCount incohérent');
    patch['player1CardCount'] = computedP1;
  }
  if (session.player2CardCount != computedP2) {
    errors.add('player2CardCount incohérent');
    patch['player2CardCount'] = computedP2;
  }
  final String? expectedTop = session.discardPile.isEmpty ? null : session.discardPile.last;
  if (session.topDiscard != expectedTop) {
    errors.add('topDiscard incohérent avec discardPile');
    patch['topDiscard'] = expectedTop;
  }
  if (session.status == DuelGameStatus.inProgress &&
      !session.players.contains(session.currentTurn)) {
    errors.add('currentTurn invalide pour une partie active');
  }
  if (allCards.length != 54) {
    errors.add('Nombre total de cartes incohérent: ${allCards.length}/54');
  }

  for (final MapEntry<String, List<String>> entry in locationsByCard.entries) {
    if (entry.value.length > 1) {
      final Map<String, dynamic> integrity = <String, dynamic>{
        'type': 'duplicate_card',
        'cardId': entry.key,
        'locations': entry.value,
        'detectedAt': FieldValue.serverTimestamp(),
      };
      errors.add('Carte dupliquée ${entry.key} dans ${entry.value.join(', ')}');
      return DuelGameStateValidationResult(
        isValid: false,
        errors: errors,
        autoCorrectPatch: patch,
        integrityError: integrity,
      );
    }
  }

  return DuelGameStateValidationResult(
    isValid: errors.isEmpty,
    errors: errors,
    autoCorrectPatch: patch,
  );
}

int getOpponentCardCount(DuelSession session, String currentUserId) {
  if (currentUserId == session.player1Id) {
    return session.player2Hand.isNotEmpty
        ? session.player2Hand.length
        : session.player2CardCount;
  }
  if (currentUserId == session.player2Id) {
    return session.player1Hand.isNotEmpty
        ? session.player1Hand.length
        : session.player1CardCount;
  }
  return 0;
}

class _DuelStatusBanner extends StatelessWidget {
  const _DuelStatusBanner({
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.round,
    this.compact = false,
  });

  final String opponentName;
  final int myScore;
  final int opponentScore;
  final int round;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 3 : 6),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 7 : 10),
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
                    TextSpan(
                      text: 'Vous  ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '$myScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const TextSpan(
                      text: '   :   ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: '$opponentName  ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '$opponentScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: compact ? 4 : 6),
            child: Text(
              'Manche $round',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 11 : 12,
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

class _OpponentRow extends StatefulWidget {
  const _OpponentRow({
    required this.name,
    required this.count,
    required this.wins,
    required this.losses,
    required this.fallbackInitial,
    required this.avatarCard,
    this.compact = false,
  });

  final String name;
  final int count;
  final int wins;
  final int losses;
  final String fallbackInitial;
  final DuelCard avatarCard;
  final bool compact;

  @override
  State<_OpponentRow> createState() => _OpponentRowState();
}

class _OpponentRowState extends State<_OpponentRow> {
  int _animatedStartIndex = -1;

  @override
  void didUpdateWidget(covariant _OpponentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _animatedStartIndex = oldWidget.count;
    } else {
      _animatedStartIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ProfileBlock(
                name: widget.name,
                wins: widget.wins,
                losses: widget.losses,
                fallbackInitial: widget.fallbackInitial,
                compact: true,
                avatarCard: widget.avatarCard,
              ),
              Padding(
                padding: EdgeInsets.only(top: widget.compact ? 6 : 8, bottom: widget.compact ? 6 : 8),
                child: Container(height: 1, color: Colors.white.withOpacity(0.16)),
              ),
              SizedBox(
                height: widget.compact ? 36 : 42,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(
                      widget.count,
                      (int index) {
                        final bool isNewCard = _animatedStartIndex >= 0 && index >= _animatedStartIndex;
                        final int staggerStep = isNewCard ? index - _animatedStartIndex : 0;
                        return Padding(
                          padding: EdgeInsets.only(left: index == widget.count - 1 ? 0 : 8),
                          child: BouncyCardEntry(
                            key: ValueKey<String>('duel-opponent-$index'),
                            animate: isNewCard,
                            delay: Duration(milliseconds: isNewCard ? staggerStep * 34 : 0),
                            child: _DuelCardBack(
                              width: widget.compact ? 24 : 28,
                              height: widget.compact ? 34 : 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -6,
            right: -6,
            child: _DrawCountBadge(count: widget.count),
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
    return Row(
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
    required this.discardPile,
    required this.drawCount,
    required this.canDraw,
    required this.onDrawTap,
    required this.overlay,
    required this.requiredSuit,
    required this.mustDraw,
    this.compact = false,
  });

  final List<DuelCard> discardPile;
  final int drawCount;
  final bool canDraw;
  final VoidCallback onDrawTap;
  final String overlay;
  final String? requiredSuit;
  final bool mustDraw;
  final bool compact;

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
                            child: _DuelCardBack(
                              width: compact ? 56 : 64,
                              height: compact ? 82 : 92,
                            ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: 0.05,
                        child: _DuelCardBack(
                          width: compact ? 56 : 64,
                          height: compact ? 82 : 92,
                        ),
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
            SizedBox(width: compact ? 14 : 20),
            Column(
              children: <Widget>[
                _DiscardPileStackView(
                  cards: discardPile,
                  compact: compact,
                ),
              ],
            ),
          ],
        ),
        if (overlay.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: compact ? 7 : 10),
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 5 : 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: _SuitOverlayText(message: overlay),
          ),
      ],
    );
  }
}

class _DiscardPileStackView extends StatelessWidget {
  const _DiscardPileStackView({
    required this.cards,
    required this.compact,
  });

  final List<DuelCard> cards;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DuelCard topCard = cards.last;
    final int cardCount = cards.length;
    final List<DuelCard> underCards = cardCount <= 1
        ? const <DuelCard>[]
        : cardCount == 2
            ? <DuelCard>[cards[cardCount - 2]]
            : <DuelCard>[cards[cardCount - 3], cards[cardCount - 2]];

    return SizedBox(
      width: compact ? 82 : 86,
      height: compact ? 114 : 118,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (int index = 0; index < underCards.length; index++)
            Transform.translate(
              offset: Offset(-4.0 + (index * 4), -2.0 + (index * 3)),
              child: Transform.rotate(
                angle: index == 0 ? -0.087 : 0.070,
                child: Opacity(
                  opacity: 0.92 - (index * 0.15),
                  child: compact
                      ? Transform.scale(
                          scale: 0.92,
                          child: _FaceCard(card: underCards[index]),
                        )
                      : _FaceCard(card: underCards[index]),
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>('${topCard.id}-$cardCount'),
              child: compact
                  ? Transform.scale(
                      scale: 0.92,
                      child: _FaceCard(card: topCard),
                    )
                  : _FaceCard(card: topCard),
            ),
          ),
        ],
      ),
    );
  }
}


class _MyHandRow extends StatefulWidget {
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
    this.cardScale = 1,
    this.minCardsViewportHeight = 190,
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
  final double cardScale;
  final double minCardsViewportHeight;
  static const int _maxCardsPerRow = 6;
  static const double _cardGap = 6;

  @override
  State<_MyHandRow> createState() => _MyHandRowState();
}

class _MyHandRowState extends State<_MyHandRow> {
  List<String> _previousCardIds = const <String>[];
  Set<String> _newCardIds = <String>{};

  @override
  void initState() {
    super.initState();
    _previousCardIds = widget.cards.map((DuelCard c) => c.id).toList();
  }

  @override
  void didUpdateWidget(covariant _MyHandRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<String> currentIds = widget.cards.map((DuelCard c) => c.id).toList();
    final Set<String> previousIds = _previousCardIds.toSet();
    _newCardIds = currentIds.where((String id) => !previousIds.contains(id)).toSet();
    _previousCardIds = currentIds;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _ProfileBlock(
                      name: widget.profileName,
                      wins: widget.wins,
                      losses: widget.losses,
                      credits: widget.credits,
                      fallbackInitial: widget.fallbackInitial,
                      compact: true,
                      avatarCard: widget.avatarCard,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _TurnStateBadge(
                          text: widget.canInteract ? 'À votre tour' : 'En attente',
                          blink: widget.canInteract,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Container(height: 1, color: Colors.white.withOpacity(0.16)),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final List<DuelCard> cards = widget.cards;
                      if (cards.isEmpty) {
                        return const SizedBox.expand();
                      }
                      int newCardOrder = 0;

                      final double maxRowWidth =
                          (_FaceCard.width * widget.cardScale * _MyHandRow._maxCardsPerRow) +
                          (_MyHandRow._cardGap * (_MyHandRow._maxCardsPerRow - 1));
                      final double wrapWidth = min(
                        constraints.maxWidth - 8,
                        maxRowWidth,
                      );
                      final double cardWidth = _FaceCard.width * widget.cardScale;
                      final double cardsMinHeight = max(
                        widget.minCardsViewportHeight,
                        _FaceCard.height * widget.cardScale + 8,
                      );

                      return Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          ConstrainedBox(
                            constraints: BoxConstraints(minHeight: cardsMinHeight),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: wrapWidth,
                                  child: Wrap(
                                    spacing: _MyHandRow._cardGap,
                                    runSpacing: _MyHandRow._cardGap,
                                    children: List<Widget>.generate(cards.length, (int index) {
                                      final DuelCard card = cards[index];
                                      final bool isPlayable = widget.playable(card);
                                      final bool isNew = _newCardIds.contains(card.id);
                                      final int staggerIndex = isNew ? newCardOrder++ : 0;
                                      return SizedBox(
                                        width: cardWidth,
                                        child: BouncyCardEntry(
                                          key: ValueKey<String>('duel-my-${card.id}-$index'),
                                          animate: isNew,
                                          delay: Duration(milliseconds: isNew ? staggerIndex * 34 : 0),
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: widget.canInteract && isPlayable
                                                ? () => widget.onCardTap(card)
                                                : null,
                                            child: Opacity(
                                              opacity: widget.canInteract && !isPlayable ? 0.45 : 1,
                                              child: widget.cardScale == 1
                                                  ? _FaceCard(card: card)
                                                  : SizedBox(
                                                      width: cardWidth,
                                                      height: _FaceCard.height * widget.cardScale,
                                                      child: FittedBox(
                                                        fit: BoxFit.contain,
                                                        alignment: Alignment.topCenter,
                                                        child: _FaceCard(card: card),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 6,
                            child: _DrawCountBadge(count: widget.cards.length),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
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
    final String actorName = session.playerNames[action.actorId] ?? 'Joueur';

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
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                children: <TextSpan>[
                  if (isMe)
                    const TextSpan(text: 'Vous avez joué')
                  else ...<TextSpan>[
                    TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' a joué'),
                  ],
                ],
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
