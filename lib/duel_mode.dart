import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_config.dart';

enum DuelGameStatus { waiting, inProgress, finished }

enum DuelActionType { playCard, drawCard }

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
    required this.currentTurn,
    required this.status,
    this.lastAction,
  });

  final String gameId;
  final String hostId;
  final List<String> players;
  final String currentTurn;
  final DuelGameStatus status;
  final DuelAction? lastAction;

  bool get canStart => players.length == 2;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'hostId': hostId,
      'players': players,
      'currentTurn': currentTurn,
      'status': status.name,
      'lastAction': lastAction?.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory DuelSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> json = doc.data() ?? <String, dynamic>{};
    return DuelSession(
      gameId: doc.id,
      hostId: json['hostId'] as String? ?? '',
      players: List<String>.from(json['players'] as List? ?? const <String>[]),
      currentTurn: json['currentTurn'] as String? ?? '',
      status: DuelGameStatus.values.firstWhere(
        (DuelGameStatus s) => s.name == (json['status'] as String? ?? DuelGameStatus.waiting.name),
      ),
      lastAction: json['lastAction'] == null
          ? null
          : DuelAction.fromMap(Map<String, dynamic>.from(json['lastAction'] as Map)),
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

  Future<String> createGame({required String playerId}) async {
    final String code = _generateCode();
    final CollectionReference<Map<String, dynamic>> games = await _games();
    await games.doc(code).set(
      DuelSession(
        gameId: code,
        hostId: playerId,
        players: <String>[playerId],
        currentTurn: playerId,
        status: DuelGameStatus.waiting,
      ).toMap(),
    );
    return code;
  }

  Future<void> joinGame({required String gameId, required String playerId}) async {
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

  Future<void> pushAction({required String gameId, required DuelAction action, required String nextTurn}) async {
    final CollectionReference<Map<String, dynamic>> games = await _games();
    final DocumentReference<Map<String, dynamic>> gameRef = games.doc(gameId);
    await gameRef.update(<String, dynamic>{
      'currentTurn': nextTurn,
      'lastAction': action.toMap(),
      'status': DuelGameStatus.inProgress.name,
    });
    await gameRef.collection('actions').add(action.toMap());
  }
}

class DuelController extends ChangeNotifier {
  DuelController({required this.service, required this.localPlayerId});

  final GameService service;
  final String localPlayerId;

  DuelSession? session;
  StreamSubscription<DuelSession>? _subscription;
  bool busy = false;
  String? error;

  Future<void> create() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final String id = await service.createGame(playerId: localPlayerId);
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
      await service.joinGame(gameId: gameId, playerId: localPlayerId);
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
  late final DuelController _controller;
  final TextEditingController _codeController = TextEditingController();
  bool _openedDuel = false;

  @override
  void initState() {
    super.initState();
    final String playerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
    _controller = DuelController(service: GameService(), localPlayerId: playerId)
      ..addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChange)
      ..dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    final DuelSession? session = _controller.session;
    if (!_openedDuel && session != null && session.players.length == 2 && mounted) {
      _openedDuel = true;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DuelPage(controller: _controller),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final DuelSession? session = _controller.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby Duel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Votre ID: ${_controller.localPlayerId}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _controller.busy ? null : _controller.create,
              child: const Text('Créer une partie'),
            ),
            if (session != null) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText('Code de partie: ${session.gameId}'),
              Text('Joueurs connectés: ${session.players.length}/2'),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code partie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _controller.busy
                  ? null
                  : () => _controller.join(_codeController.text.trim().toUpperCase()),
              child: const Text('Rejoindre une partie'),
            ),
            if (_controller.error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_controller.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
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
    if (_board == null || _board!.gameId != session.gameId) {
      final DuelBoardState initial = DuelBoardState.initial(
        gameId: session.gameId,
        players: session.players,
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
  }

  Future<void> _onCardTap(DuelCard card) async {
    final DuelSession? session = _controller.session;
    final DuelBoardState? board = _board;
    if (session == null || board == null || !_controller.isMyTurn) {
      return;
    }
    final DuelMoveResult move = board.tryPlay(
      actorId: _controller.localPlayerId,
      card: card,
    );
    if (!move.accepted) {
      return;
    }
    await _controller.sendAction(
      DuelActionType.playCard,
      payload: move.payload,
      nextTurnOverride: move.nextTurn,
    );
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
        final bool myTurn = _controller.isMyTurn;
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          appBar: AppBar(title: Text('Duel ${session.gameId}')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  _DuelStatusBanner(
                    isMyTurn: myTurn,
                    connectedPlayers: session.players.length,
                    duelStatus: session.status,
                    opponentId: opponentId,
                    status: board.status,
                  ),
                  const SizedBox(height: 12),
                  _OpponentRow(count: board.handOf(opponentId).length),
                  const SizedBox(height: 10),
                  _CenterArea(
                    discard: board.discardTop,
                    drawCount: board.drawPile.length,
                    canDraw: myTurn && board.canDraw(_controller.localPlayerId),
                    onDrawTap: _onDrawTap,
                    overlay: board.overlay,
                  ),
                  const SizedBox(height: 10),
                  _MyHandRow(
                    cards: board.handOf(_controller.localPlayerId),
                    canInteract: myTurn,
                    onCardTap: _onCardTap,
                    playable: (DuelCard card) =>
                        myTurn && board.canPlay(_controller.localPlayerId, card),
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

  String get id => '$rank$suit';

  bool get isRed => suit == '♥' || suit == '♦';

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
    required this.aceColorRequired,
    required this.overlay,
    required this.status,
  });

  final String gameId;
  final List<String> players;
  final List<DuelCard> drawPile;
  final Map<String, List<DuelCard>> hands;
  final DuelCard discardTop;
  final String? requiredSuit;
  final int pendingDraw;
  final bool aceColorRequired;
  final String overlay;
  final String status;

  factory DuelBoardState.initial({required String gameId, required List<String> players}) {
    final Random random = Random(gameId.hashCode);
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
      aceColorRequired: false,
      overlay: '',
      status: 'Partie démarrée',
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
    if (card.rank == '8' || card.isJoker) {
      return true;
    }
    if (requiredSuit != null) {
      return card.suit == requiredSuit || card.rank == discardTop.rank;
    }
    return card.matches(discardTop);
  }

  bool canDraw(String actorId) => drawPile.isNotEmpty;

  DuelMoveResult tryPlay({required String actorId, required DuelCard card}) {
    if (!canPlay(actorId, card)) {
      return const DuelMoveResult(accepted: false);
    }
    String? suitChoice;
    if (card.rank == '8') {
      suitChoice = handOf(actorId).firstWhere((DuelCard c) => c.id != card.id, orElse: () => card).suit;
    }
    final String next = _nextPlayer(actorId, skip: card.rank == '10' || card.rank == 'J');
    return DuelMoveResult(
      accepted: true,
      nextTurn: next,
      payload: <String, dynamic>{
        'cardId': card.id,
        if (suitChoice != null) 'chosenSuit': suitChoice,
      },
    );
  }

  DuelMoveResult tryDraw({required String actorId}) {
    if (drawPile.isEmpty) {
      return const DuelMoveResult(accepted: false);
    }
    return DuelMoveResult(
      accepted: true,
      nextTurn: _nextPlayer(actorId),
      payload: <String, dynamic>{'count': pendingDraw > 0 ? pendingDraw : 1},
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
    bool newAceRequired = aceColorRequired;
    String newOverlay = overlay;
    String newStatus = status;

    if (action.type == DuelActionType.drawCard) {
      final int count = (action.payload['count'] as int?) ?? 1;
      final int amount = count.clamp(1, 9);
      for (int i = 0; i < amount && newPile.isNotEmpty; i++) {
        newHands[action.actorId]?.add(newPile.removeLast());
      }
      newPendingDraw = 0;
      newAceRequired = false;
      newOverlay = '${action.actorId} pioche';
      newStatus = '${action.actorId} a pioché.';
    }

    if (action.type == DuelActionType.playCard) {
      final DuelCard card = DuelCard.fromId(action.payload['cardId'] as String);
      newHands[action.actorId]?.removeWhere((DuelCard c) => c.id == card.id);
      newTop = card;
      newRequiredSuit = null;
      newOverlay = '${action.actorId} joue ${card.label}';
      newStatus = newOverlay;

      if (card.rank == '8') {
        newRequiredSuit = action.payload['chosenSuit'] as String? ?? '♥';
        newOverlay = '${action.actorId} change la couleur en $newRequiredSuit';
      } else if (card.rank == '2') {
        newPendingDraw += 2;
        newOverlay = '${action.actorId} force +2';
      } else if (card.isJoker) {
        newPendingDraw += 9;
        newOverlay = '${action.actorId} force +9 (joker)';
      } else if (card.rank == 'A') {
        newAceRequired = true;
        newOverlay = '${action.actorId} joue un As';
      } else if (card.rank == '10' || card.rank == 'J') {
        newOverlay = '${action.actorId} saute un tour';
      }
    }

    return DuelBoardState._(
      gameId: gameId,
      players: players,
      drawPile: newPile,
      hands: newHands,
      discardTop: newTop,
      requiredSuit: newRequiredSuit,
      pendingDraw: newPendingDraw,
      aceColorRequired: newAceRequired,
      overlay: newOverlay,
      status: newStatus,
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
    required this.isMyTurn,
    required this.connectedPlayers,
    required this.duelStatus,
    required this.opponentId,
    required this.status,
  });

  final bool isMyTurn;
  final int connectedPlayers;
  final DuelGameStatus duelStatus;
  final String opponentId;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isMyTurn ? 'Votre tour' : 'Tour adverse', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('Joueurs: $connectedPlayers/2 · état: ${duelStatus.name}', style: const TextStyle(color: Colors.white70)),
          Text('Adversaire: ${opponentId.isEmpty ? 'en attente...' : 'connecté'}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(status, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: <Widget>[
          const Text('Adversaire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('($count cartes)', style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          ...List<Widget>.generate(min(count, 10), (int _) => const Padding(
            padding: EdgeInsets.only(left: 4),
            child: _DuelCardBack(width: 24, height: 34),
          )),
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
  });

  final DuelCard discard;
  final int drawCount;
  final bool canDraw;
  final VoidCallback onDrawTap;
  final String overlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: canDraw ? onDrawTap : null,
              child: Opacity(
                opacity: canDraw ? 1 : 0.45,
                child: Column(
                  children: <Widget>[
                    const _DuelCardBack(width: 64, height: 92),
                    const SizedBox(height: 6),
                    Text('Pioche ($drawCount)', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              children: <Widget>[
                _FaceCard(card: discard),
                const SizedBox(height: 6),
                const Text('Défausse', style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
        if (overlay.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(overlay, style: const TextStyle(color: Colors.white)),
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
            Text(canInteract ? 'Votre main (touchez une carte)' : 'Votre main (attendez votre tour)', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceCard extends StatelessWidget {
  const _FaceCard({required this.card});

  final DuelCard card;

  @override
  Widget build(BuildContext context) {
    final bool red = card.isRed;
    return Container(
      width: 64,
      height: 92,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(card.isJoker ? 'JOKER' : card.id, style: TextStyle(color: red ? Colors.red : Colors.black, fontWeight: FontWeight.bold))),
    );
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
