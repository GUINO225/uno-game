import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_config.dart';
import 'premium_ui.dart';

enum DuelGameStatus { waiting, inProgress, finished }

enum DuelActionType { playCard, drawCard, resetRound }

enum DuelRematchDecision { pending, accepted, declined }

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
    this.lastAction,
    this.rematchRequestBy,
    this.rematchRequestedAt,
    this.rematchDecision = DuelRematchDecision.pending,
    this.rematchDecisionBy,
  });

  final String gameId;
  final String hostId;
  final List<String> players;
  final Map<String, String> playerNames;
  final String currentTurn;
  final DuelGameStatus status;
  final Map<String, int> scores;
  final int round;
  final DuelAction? lastAction;
  final String? rematchRequestBy;
  final DateTime? rematchRequestedAt;
  final DuelRematchDecision rematchDecision;
  final String? rematchDecisionBy;

  bool get canStart => players.length == 2;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'hostId': hostId,
      'players': players,
      'playerNames': playerNames,
      'currentTurn': currentTurn,
      'status': status.name,
      'scores': scores,
      'round': round,
      'lastAction': lastAction?.toMap(),
      'rematchRequestBy': rematchRequestBy,
      'rematchRequestedAt': rematchRequestedAt == null
          ? null
          : Timestamp.fromDate(rematchRequestedAt!.toUtc()),
      'rematchDecision': rematchDecision.name,
      'rematchDecisionBy': rematchDecisionBy,
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
  }) async {
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
      ).toMap(),
    );
    return code;
  }

  Future<void> joinGame({
    required String gameId,
    required String playerId,
    required String playerName,
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
      if (session.players.length >= 2 && !session.players.contains(playerId)) {
        throw StateError('Partie déjà complète');
      }
      final List<String> players = <String>{...session.players, playerId}.toList();
      tx.update(ref, <String, dynamic>{
        'players': players,
        'playerNames.$playerId': playerName,
        'scores.$playerId': session.scores[playerId] ?? 0,
        'status': players.length == 2 ? DuelGameStatus.inProgress.name : DuelGameStatus.waiting.name,
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
        'status': DuelGameStatus.inProgress.name,
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.pending.name,
        'rematchDecisionBy': null,
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
  }

  Future<void> requestRematch({
    required String gameId,
    required String requestedBy,
  }) async {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    await games.doc(gameId).update(<String, dynamic>{
      'rematchRequestBy': requestedBy,
      'rematchRequestedAt': FieldValue.serverTimestamp(),
      'rematchDecision': DuelRematchDecision.pending.name,
      'rematchDecisionBy': null,
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
        'status': DuelGameStatus.inProgress.name,
        'round': nextRound,
        'currentTurn': starter,
        'lastAction': action.toMap(),
        'rematchRequestBy': null,
        'rematchRequestedAt': null,
        'rematchDecision': DuelRematchDecision.accepted.name,
        'rematchDecisionBy': responderId,
      });
      tx.set(ref.collection('actions').doc(), action.toMap());
    });
  }
}

class DuelController extends ChangeNotifier {
  DuelController({
    required this.service,
    required this.localPlayerId,
    required this.localPlayerName,
  });

  final GameService service;
  final String localPlayerId;
  final String localPlayerName;

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
      );
      await attach(id);
    } catch (e) {
      error = '$e';
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
      );
      await attach(gameId);
    } catch (e) {
      error = '$e';
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class DuelLobbyPage extends StatefulWidget {
  const DuelLobbyPage({super.key});

  @override
  State<DuelLobbyPage> createState() => _DuelLobbyPageState();
}

class _DuelLobbyPageState extends State<DuelLobbyPage> {
  DuelController? _controller;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _openedDuel = false;
  late final String _localPlayerId;

  @override
  void initState() {
    super.initState();
    _localPlayerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
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
          builder: (_) => DuelPage(controller: _controller!),
        ),
      );
    }
    setState(() {});
  }

  String _resolvedName({required bool asHost}) {
    final String raw = _nameController.text.trim();
    return raw.isEmpty ? (asHost ? 'Joueur 1' : 'Joueur 2') : raw;
  }

  Future<void> _createGame() async {
    if (_controller == null) {
      _controller = DuelController(
        service: GameService(),
        localPlayerId: _localPlayerId,
        localPlayerName: _resolvedName(asHost: true),
      )..addListener(_onControllerChange);
    }
    await _controller!.create();
  }

  Future<void> _joinGame() async {
    if (_controller == null) {
      _controller = DuelController(
        service: GameService(),
        localPlayerId: _localPlayerId,
        localPlayerName: _resolvedName(asHost: false),
      )..addListener(_onControllerChange);
    }
    await _controller!.join(_codeController.text.trim().toUpperCase());
  }


  @override
  Widget build(BuildContext context) {
    final DuelSession? session = _controller?.session;
    final bool busy = _controller?.busy ?? false;
    return Scaffold(
      body: TableBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'DUEL EN LIGNE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crée un salon privé ou rejoins une partie existante.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.84)),
                    ),
                    const SizedBox(height: 20),
                    PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Ton profil',
                            style: TextStyle(
                              color: PremiumColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Pseudo',
                              hintText: 'Joueur 1',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            'ID local: $_localPlayerId',
                            style: TextStyle(
                              color: PremiumColors.textDark.withOpacity(0.72),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    'Joueurs connectés: ${session.players.length}/2',
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
                            decoration: const InputDecoration(
                              labelText: 'Code de partie',
                              hintText: 'AB12CD',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: busy ? null : _joinGame,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Rejoindre'),
                          ),
                        ],
                      ),
                    ),
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
    );
  }
}

class DuelPage extends StatefulWidget {
  const DuelPage({super.key, required this.controller});

  final DuelController controller;

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  StreamSubscription<List<DuelAction>>? _actionsSubscription;
  DuelBoardState? _board;
  String? _lastEightPopupKey;
  String? _lastForcedDrawPopupKey;
  String? _lastRematchRequestKey;
  bool _rematchDialogOpen = false;
  bool _rematchActionBusy = false;
  bool _didNavigateHomeAfterDecline = false;

  DuelController get _controller => widget.controller;

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
    _maybeShowCommandPopup(session);
    _maybeShowForcedDrawPopup(session);
    _maybeHandleRematchFlow(session);
  }

  Future<void> _onCardTap(DuelCard card) async {
    final DuelSession? session = _controller.session;
    final DuelBoardState? board = _board;
    if (session == null || board == null || !_controller.isMyTurn) {
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
        return AlertDialog(
          title: const Center(
            child: Text(
              'TU COMMANDES ?',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
          content: SizedBox(
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
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
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
                            Text(suit.$2),
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
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                actorName,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'a commandé',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
        return AlertDialog(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _DuelCardBack(width: 52, height: 76),
              const SizedBox(height: 12),
              Text(
                'PIOCHEZ $amount CARTES',
                textAlign: TextAlign.center,
                style: const TextStyle(
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

  Future<void> _onDrawTap() async {
    final DuelSession? session = _controller.session;
    final DuelBoardState? board = _board;
    if (session == null || board == null || !_controller.isMyTurn) {
      return;
    }
    final DuelMoveResult move = board.tryDraw(actorId: _controller.localPlayerId);
    if (!move.accepted) {
      return;
    }
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

  Future<void> _onReplayTap() async {
    if (_rematchActionBusy) {
      return;
    }
    final DuelSession? session = _controller.session;
    if (session == null || session.status != DuelGameStatus.finished) {
      return;
    }
    if (session.rematchRequestBy == _controller.localPlayerId &&
        session.rematchDecision == DuelRematchDecision.pending) {
      return;
    }
    setState(() {
      _rematchActionBusy = true;
    });
    try {
      await _controller.requestRematch();
    } finally {
      if (mounted) {
        setState(() {
          _rematchActionBusy = false;
        });
      }
    }
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
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'REJOUER ?',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$requester VEUT REJOUER',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 112,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('NON'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('OUI'),
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
        _rematchDialogOpen) {
      return;
    }
    final String requestKey = '${requesterId}_${session.rematchRequestedAt?.millisecondsSinceEpoch ?? 0}';
    if (_lastRematchRequestKey == requestKey) {
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
        final int myScore = session.scores[_controller.localPlayerId] ?? 0;
        final int opponentScore = session.scores[opponentId] ?? 0;
        final bool myTurn = _controller.isMyTurn && session.status != DuelGameStatus.finished;
        final ({String status, String overlay}) texts = _personalizedTexts(session, board);
        final double topInset = MediaQuery.paddingOf(context).top;
        return Scaffold(
          backgroundColor: PremiumColors.tableGreenDark,
          body: TableBackground(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Retour',
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        'DUEL',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  _DuelStatusBanner(
                    opponentName: opponentName,
                    myScore: myScore,
                    opponentScore: opponentScore,
                    round: session.round,
                  ),
                  const SizedBox(height: 12),
                  _OpponentRow(
                    name: opponentName,
                    count: board.handOf(opponentId).length,
                    wins: opponentScore,
                    losses: myScore,
                    fallbackInitial: opponentName.isNotEmpty ? opponentName[0] : '?',
                  ),
                  const SizedBox(height: 10),
                  _CenterArea(
                    discard: board.discardTop,
                    drawCount: board.drawPile.length,
                    canDraw: myTurn && board.canDraw(_controller.localPlayerId),
                    onDrawTap: _onDrawTap,
                    overlay: texts.overlay,
                    requiredSuit: board.requiredSuit,
                    mustDraw: myTurn && board.pendingDraw > 0,
                  ),
                  const SizedBox(height: 10),
                  _MyHandRow(
                    cards: board.handOf(_controller.localPlayerId),
                    canInteract: myTurn,
                    onCardTap: _onCardTap,
                    playable: (DuelCard card) =>
                        myTurn && board.canPlay(_controller.localPlayerId, card),
                  ),
                  const SizedBox(height: 8),
                  _ActionMessageCard(
                    session: session,
                    localPlayerId: _controller.localPlayerId,
                  ),
                  if (session.status == DuelGameStatus.finished)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: _onReplayTap,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          session.rematchRequestBy == _controller.localPlayerId &&
                                  session.rematchDecision == DuelRematchDecision.pending
                              ? 'EN ATTENTE...'
                              : 'REJOUER',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
    throw ArgumentError('Invalid DuelCard payload: $json');
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
    if (aceColorRequired && discardTop.rank != 'A') {
      return true;
    }
    if (discardTop.rank == 'A' && aceColorRequired) {
      if (card.rank == 'A') {
        return true;
      }
      if (card.isJoker && card.isRed == discardTop.isRed) {
        return true;
      }
      return false;
    }
    if (card.rank == '8') {
      return true;
    }
    if (card.isJoker) {
      final String colorRefSuit = requiredSuit ?? discardTop.suit;
      return card.isSameColorAsSuit(colorRefSuit);
    }
    if (requiredSuit != null) {
      return card.suit == requiredSuit || card.rank == discardTop.rank;
    }
    return card.matches(discardTop);
  }

  bool canDraw(String actorId) => drawPile.isNotEmpty;

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
    if (drawPile.isEmpty) {
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
    DuelCard newTop = discardTop;
    String? newRequiredSuit = requiredSuit;
    int newPendingDraw = pendingDraw;
    int newForcedDrawInitial = forcedDrawInitial;
    bool newAceRequired = aceColorRequired;
    String newOverlay = overlay;
    String newStatus = status;

    if (action.type == DuelActionType.drawCard) {
      final int count = (action.payload['count'] as int?) ?? 1;
      final int amount = count.clamp(1, 9);
      for (int i = 0; i < amount && newPile.isNotEmpty; i++) {
        newHands[action.actorId]?.add(newPile.removeLast());
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
      newRequiredSuit = null;
      newOverlay = '${action.actorId} a joué ${card.label}';
      newStatus = newOverlay;

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
        newPendingDraw += 8;
        newForcedDrawInitial = newPendingDraw;
        newOverlay = '+8';
        newStatus = '$newPendingDraw cartes à piocher';
      } else if (card.rank == 'A') {
        newAceRequired = true;
        newOverlay = 'As a été joué';
      } else if (card.rank == '10' || card.rank == 'J') {
        newOverlay = 'Tour sauté';
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

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({
    required this.name,
    required this.count,
    required this.wins,
    required this.losses,
    required this.fallbackInitial,
  });

  final String name;
  final int count;
  final int wins;
  final int losses;
  final String fallbackInitial;

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
    this.compact = false,
  });

  final String name;
  final int wins;
  final int losses;
  final String fallbackInitial;
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
            ),
            alignment: Alignment.center,
            child: Text(
              fallbackInitial,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 14 : 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
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
            ],
          ),
        ],
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
                      const _DuelCardBack(width: 64, height: 92),
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
  });

  final List<DuelCard> cards;
  final bool canInteract;
  final ValueChanged<DuelCard> onCardTap;
  final bool Function(DuelCard) playable;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _TurnStateBadge(
              text: canInteract ? 'À VOTRE TOUR' : 'PATIENTEZ',
              blink: canInteract,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, int index) {
                      final DuelCard card = cards[index];
                      final bool isPlayable = playable(card);
                      return GestureDetector(
                        onTap: canInteract && isPlayable ? () => onCardTap(card) : null,
                        child: Opacity(opacity: canInteract && !isPlayable ? 0.4 : 1, child: _FaceCard(card: card)),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: cards.length,
                  ),
                  Positioned(
                    top: -6,
                    right: -2,
                    child: _DrawCountBadge(count: cards.length),
                  ),
                ],
              ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withOpacity(0.22)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
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
  static const double width = 72;
  static const double height = 102;

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.22)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
          ],
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
      return const Color(0xFF1B1B1B);
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white70),
        image: const DecorationImage(
          image: AssetImage('assets/img/card_back.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
