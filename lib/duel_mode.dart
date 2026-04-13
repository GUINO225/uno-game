import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_config.dart';

enum DuelGameStatus { waiting, inProgress, finished }

enum DuelActionType { playCard, drawCard, passTurn }

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

  Future<void> sendAction(DuelActionType type, {Map<String, dynamic> payload = const <String, dynamic>{}}) async {
    final DuelSession? current = session;
    if (current == null || !isMyTurn || current.players.length < 2) {
      return;
    }

    final String nextTurn = current.players.firstWhere((String id) => id != localPlayerId, orElse: () => localPlayerId);

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

class DuelPage extends StatelessWidget {
  const DuelPage({super.key, required this.controller});

  final DuelController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final DuelSession? session = controller.session;
        final bool myTurn = controller.isMyTurn;
        final DuelAction? lastAction = session?.lastAction;
        final String? opponentId = session == null
            ? null
            : session.players.where((String id) => id != controller.localPlayerId).isEmpty
                ? null
                : session.players.firstWhere((String id) => id != controller.localPlayerId);
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          appBar: AppBar(title: Text('Duel ${session?.gameId ?? ''}')),
          body: session == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.15),
                            radius: 1.15,
                            colors: <Color>[
                              const Color(0xFF2E7D32),
                              const Color(0xFF1B5E20),
                              const Color(0xFF0E3E13),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _DuelStatusBanner(
                              isMyTurn: myTurn,
                              connectedPlayers: session.players.length,
                              duelStatus: session.status,
                              opponentId: opponentId,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Column(
                                children: <Widget>[
                                  _PlayerHandZone(
                                    title: 'Adversaire',
                                    subtitle:
                                        lastAction?.actorId == controller.localPlayerId
                                        ? 'En attente de sa réponse...'
                                        : 'Dernière action: ${_readableAction(lastAction)}',
                                    cardCount: 7,
                                    highlighted: !myTurn,
                                    showFaceDown: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _CenterStacks(
                                    lastActionLabel: _readableAction(lastAction),
                                    myTurn: myTurn,
                                  ),
                                  const SizedBox(height: 12),
                                  _PlayerHandZone(
                                    title: 'Vous',
                                    subtitle: myTurn
                                        ? 'À vous de jouer'
                                        : 'Tour de l’adversaire',
                                    cardCount: 7,
                                    highlighted: myTurn,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: myTurn
                                        ? () => controller.sendAction(
                                              DuelActionType.playCard,
                                              payload: <String, dynamic>{
                                                'cardId': 'example_card',
                                              },
                                            )
                                        : null,
                                    child: const Text('Jouer'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: myTurn
                                        ? () => controller.sendAction(
                                              DuelActionType.drawCard,
                                            )
                                        : null,
                                    child: const Text('Piocher'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: myTurn
                                        ? () => controller.sendAction(
                                              DuelActionType.passTurn,
                                            )
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    child: const Text('Passer'),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

String _readableAction(DuelAction? action) {
  if (action == null) {
    return 'Aucune';
  }
  switch (action.type) {
    case DuelActionType.playCard:
      return 'Carte jouée';
    case DuelActionType.drawCard:
      return 'Carte piochée';
    case DuelActionType.passTurn:
      return 'Tour passé';
  }
}

class _DuelStatusBanner extends StatelessWidget {
  const _DuelStatusBanner({
    required this.isMyTurn,
    required this.connectedPlayers,
    required this.duelStatus,
    required this.opponentId,
  });

  final bool isMyTurn;
  final int connectedPlayers;
  final DuelGameStatus duelStatus;
  final String? opponentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? Colors.lightGreenAccent.shade100 : Colors.white30,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isMyTurn ? 'Votre tour' : 'Tour adverse',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Joueurs connectés: $connectedPlayers/2',
            style: const TextStyle(color: Colors.white70),
          ),
          Text('État: ${duelStatus.name}', style: const TextStyle(color: Colors.white70)),
          Text(
            'Adversaire: ${opponentId == null ? 'en attente...' : 'connecté'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PlayerHandZone extends StatelessWidget {
  const _PlayerHandZone({
    required this.title,
    required this.subtitle,
    required this.cardCount,
    this.highlighted = false,
    this.showFaceDown = false,
  });

  final String title;
  final String subtitle;
  final int cardCount;
  final bool highlighted;
  final bool showFaceDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.28),
        border: Border.all(
          color: highlighted ? Colors.lightBlue.shade200 : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cardCount,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, int index) => showFaceDown
                  ? const _DuelCardBack(width: 52, height: 74)
                  : _PlayerCardStub(index: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterStacks extends StatelessWidget {
  const _CenterStacks({
    required this.lastActionLabel,
    required this.myTurn,
  });

  final String lastActionLabel;
  final bool myTurn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 165,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _StackCard(
            title: 'Pioche',
            label: 'Cartes',
            highlighted: myTurn,
            icon: const _DuelCardBack(),
          ),
          const SizedBox(width: 12),
          _StackCard(
            title: 'Défausse',
            label: lastActionLabel,
            highlighted: false,
            icon: const _DiscardCardFace(),
          ),
        ],
      ),
    );
  }
}

class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.title,
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  final String title;
  final String label;
  final Widget icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? Colors.amber.shade300 : Colors.white24,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          icon,
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlayerCardStub extends StatelessWidget {
  const _PlayerCardStub({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const List<String> values = <String>['A♠', '8♥', '2♦', 'J♣', 'K♠', '7♦', 'Q♥'];
    final String value = values[index % values.length];
    final bool red = value.contains('♥') || value.contains('♦');
    return Container(
      width: 52,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: red ? Colors.red.shade700 : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

class _DiscardCardFace extends StatelessWidget {
  const _DiscardCardFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26),
      ),
      child: const Center(
        child: Icon(Icons.style, color: Colors.black54),
      ),
    );
  }
}
