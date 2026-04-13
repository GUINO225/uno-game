import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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

  FirebaseFirestore get _db {
    if (_firestore != null) {
      return _firestore!;
    }
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase non configuré. Le mode duel nécessite Firebase.initializeApp().',
      );
    }
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('duel_games');

  String _generateCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random();
    return List<String>.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> createGame({required String playerId}) async {
    final String code = _generateCode();
    await _games.doc(code).set(
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
    final DocumentReference<Map<String, dynamic>> ref = _games.doc(gameId);
    await _db.runTransaction((Transaction tx) async {
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

  Stream<DuelSession> watchSession(String gameId) {
    return _games.doc(gameId).snapshots().where((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists).map(DuelSession.fromDoc);
  }

  Future<void> pushAction({required String gameId, required DuelAction action, required String nextTurn}) async {
    final DocumentReference<Map<String, dynamic>> gameRef = _games.doc(gameId);
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
        return Scaffold(
          appBar: AppBar(title: Text('Duel ${session?.gameId ?? ''}')),
          body: session == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Tour actif: ${session.currentTurn == controller.localPlayerId ? 'Vous' : 'Adversaire'}'),
                      const SizedBox(height: 8),
                      Text('Status: ${session.status.name}'),
                      const SizedBox(height: 8),
                      Text('Dernière action: ${session.lastAction?.type.name ?? 'Aucune'}'),
                      const Divider(height: 24),
                      const Text(
                        'Intégration GameEngine : chaque action reçue doit être rejouée localement '
                        'avec la même logique existante du mode solo.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: controller.isMyTurn
                            ? () => controller.sendAction(
                                  DuelActionType.playCard,
                                  payload: <String, dynamic>{'cardId': 'example_card'},
                                )
                            : null,
                        child: const Text('Jouer une carte (action sync)'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: controller.isMyTurn
                            ? () => controller.sendAction(DuelActionType.drawCard)
                            : null,
                        child: const Text('Piocher (action sync)'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: controller.isMyTurn
                            ? () => controller.sendAction(DuelActionType.passTurn)
                            : null,
                        child: const Text('Passer le tour'),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
