import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huit américain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const CrazyEightsPage(),
    );
  }
}

enum Suit { hearts, spades, diamonds, clubs }

enum PlayerTurn { human, bot }

class PlayingCard {
  const PlayingCard({required this.suit, required this.rank});

  final Suit suit;
  final int rank;

  String get rankLabel {
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

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get label => '$rankLabel$suitSymbol';

  Color get suitColor {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }
}

class CrazyEightsPage extends StatefulWidget {
  const CrazyEightsPage({super.key});

  @override
  State<CrazyEightsPage> createState() => _CrazyEightsPageState();
}

class _CrazyEightsPageState extends State<CrazyEightsPage> {
  final Random _random = Random();

  List<PlayingCard> _drawPile = [];
  final List<PlayingCard> _discardPile = [];
  final List<PlayingCard> _humanHand = [];
  final List<PlayingCard> _botHand = [];

  Suit? _activeSuit;
  PlayerTurn _turn = PlayerTurn.human;
  String _status = '';
  bool _gameOver = false;
  bool _isChoosingSuit = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _drawPile = _createDeck();
    _shuffleDeck(_drawPile);
    _discardPile.clear();
    _humanHand
      ..clear()
      ..addAll(_dealCards(_drawPile, 7));
    _botHand
      ..clear()
      ..addAll(_dealCards(_drawPile, 7));

    _openFirstDiscardCard();

    setState(() {
      _turn = PlayerTurn.human;
      _status = 'À vous de jouer';
      _gameOver = false;
      _isChoosingSuit = false;
    });
  }

  List<PlayingCard> _createDeck() {
    final deck = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    return deck;
  }

  void _shuffleDeck(List<PlayingCard> deck) {
    deck.shuffle(_random);
  }

  List<PlayingCard> _dealCards(List<PlayingCard> deck, int count) {
    final dealt = <PlayingCard>[];
    for (int i = 0; i < count && deck.isNotEmpty; i++) {
      dealt.add(deck.removeLast());
    }
    return dealt;
  }

  void _openFirstDiscardCard() {
    while (_drawPile.isNotEmpty) {
      final card = _drawPile.removeLast();
      if (card.rank == 8) {
        _drawPile.insert(0, card);
        _shuffleDeck(_drawPile);
      } else {
        _discardPile.add(card);
        _activeSuit = card.suit;
        return;
      }
    }
  }

  PlayingCard get _topDiscard => _discardPile.last;

  bool _isCardPlayable(PlayingCard card) {
    if (_activeSuit == null || _discardPile.isEmpty) {
      return false;
    }
    return card.rank == 8 || card.suit == _activeSuit || card.rank == _topDiscard.rank;
  }

  Future<void> _onHumanTapCard(PlayingCard card) async {
    if (_turn != PlayerTurn.human || _gameOver || _isChoosingSuit) {
      return;
    }
    if (!_isCardPlayable(card)) {
      return;
    }

    Suit? selectedSuit;
    if (card.rank == 8) {
      selectedSuit = await _chooseSuitDialog();
      if (selectedSuit == null) {
        return;
      }
    }

    _playCard(
      hand: _humanHand,
      card: card,
      playerName: 'Vous',
      chosenSuit: selectedSuit,
    );
    _afterHumanAction();
  }

  Future<Suit?> _chooseSuitDialog() async {
    setState(() {
      _isChoosingSuit = true;
    });

    final choice = await showDialog<Suit>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisissez une couleur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: Suit.values
                .map(
                  (suit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(suit),
                      child: Text(_suitName(suit)),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isChoosingSuit = false;
      });
    }

    return choice;
  }

  Future<void> _onHumanDraw() async {
    if (_turn != PlayerTurn.human || _gameOver || _isChoosingSuit) {
      return;
    }

    final drawn = _drawOneCard();
    if (drawn == null) {
      setState(() {
        _status = 'La pioche est vide.';
      });
      _endHumanTurn();
      return;
    }

    setState(() {
      _humanHand.add(drawn);
      _status = 'Vous piochez ${drawn.label}.';
    });

    if (_isCardPlayable(drawn)) {
      Suit? suit;
      if (drawn.rank == 8) {
        suit = await _chooseSuitDialog();
        if (suit == null) {
          _endHumanTurn();
          return;
        }
      }

      _playCard(
        hand: _humanHand,
        card: drawn,
        playerName: 'Vous',
        chosenSuit: suit,
      );
      _afterHumanAction();
    } else {
      _endHumanTurn();
    }
  }

  PlayingCard? _drawOneCard() {
    if (_drawPile.isEmpty) {
      return null;
    }
    return _drawPile.removeLast();
  }

  void _playCard({
    required List<PlayingCard> hand,
    required PlayingCard card,
    required String playerName,
    Suit? chosenSuit,
  }) {
    setState(() {
      hand.remove(card);
      _discardPile.add(card);
      _activeSuit = chosenSuit ?? card.suit;
      if (card.rank == 8 && chosenSuit != null) {
        _status = '$playerName joue un 8 et choisit ${_suitName(chosenSuit)}.';
      } else {
        _status = '$playerName joue ${card.label}.';
      }
    });
  }

  void _afterHumanAction() {
    if (_checkVictory(player: 'Vous', hand: _humanHand)) {
      return;
    }
    _endHumanTurn();
  }

  void _endHumanTurn() {
    if (_gameOver) {
      return;
    }
    setState(() {
      _turn = PlayerTurn.bot;
    });
    _runBotTurn();
  }

  Future<void> _runBotTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted || _gameOver || _turn != PlayerTurn.bot) {
      return;
    }

    final playable = _botHand.where(_isCardPlayable).toList();
    final nonEightPlayable = playable.where((card) => card.rank != 8).toList();

    if (nonEightPlayable.isNotEmpty) {
      _playCard(hand: _botHand, card: nonEightPlayable.first, playerName: 'Bot');
      if (_checkVictory(player: 'Le bot', hand: _botHand)) {
        return;
      }
      _switchToHuman();
      return;
    }

    if (playable.isNotEmpty) {
      final eight = playable.first;
      final bestSuit = _chooseBestSuit(_botHand);
      _playCard(
        hand: _botHand,
        card: eight,
        playerName: 'Bot',
        chosenSuit: bestSuit,
      );
      if (_checkVictory(player: 'Le bot', hand: _botHand)) {
        return;
      }
      _switchToHuman();
      return;
    }

    final drawn = _drawOneCard();
    if (drawn == null) {
      setState(() {
        _status = 'Le bot ne peut pas piocher. La pioche est vide.';
      });
      _switchToHuman();
      return;
    }

    setState(() {
      _botHand.add(drawn);
      _status = 'Le bot pioche une carte.';
    });

    if (_isCardPlayable(drawn)) {
      if (drawn.rank == 8) {
        final suit = _chooseBestSuit(_botHand);
        _playCard(
          hand: _botHand,
          card: drawn,
          playerName: 'Bot',
          chosenSuit: suit,
        );
      } else {
        _playCard(hand: _botHand, card: drawn, playerName: 'Bot');
      }

      if (_checkVictory(player: 'Le bot', hand: _botHand)) {
        return;
      }
    }

    _switchToHuman();
  }

  Suit _chooseBestSuit(List<PlayingCard> hand) {
    final counts = <Suit, int>{for (final suit in Suit.values) suit: 0};
    for (final card in hand) {
      if (card.rank != 8) {
        counts[card.suit] = (counts[card.suit] ?? 0) + 1;
      }
    }

    Suit best = Suit.hearts;
    int bestCount = -1;
    for (final suit in Suit.values) {
      final count = counts[suit] ?? 0;
      if (count > bestCount) {
        best = suit;
        bestCount = count;
      }
    }
    return best;
  }

  bool _checkVictory({required String player, required List<PlayingCard> hand}) {
    if (hand.isNotEmpty) {
      return false;
    }

    setState(() {
      _gameOver = true;
      _status = '$player a gagné !';
    });
    return true;
  }

  void _switchToHuman() {
    setState(() {
      _turn = PlayerTurn.human;
      if (!_gameOver) {
        _status = 'À vous de jouer';
      }
    });
  }

  String _suitName(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return 'cœur';
      case Suit.spades:
        return 'pique';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trèfle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = _turn == PlayerTurn.human && !_gameOver && !_isChoosingSuit;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      appBar: AppBar(
        title: const Text('Huit américain'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoPanel(),
              const SizedBox(height: 12),
              _centerArea(),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canInteract ? _onHumanDraw : null,
                child: const Text('Piocher'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre main',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _humanHand
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CardView(
                              card: card,
                              enabled: canInteract && _isCardPlayable(card),
                              onTap: () => _onHumanTapCard(card),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (_gameOver)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                    onPressed: _startNewGame,
                    child: const Text('Rejouer'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cartes du bot : ${_botHand.length}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Pioche : ${_drawPile.length}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Tour : ${_turn == PlayerTurn.human ? 'Joueur' : 'Bot'}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('Couleur active : ${_suitName(_activeSuit ?? Suit.hearts)}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Statut : $_status', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _centerArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Défausse', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            CardView(card: _topDiscard),
          ],
        ),
      ],
    );
  }
}

class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.enabled = false,
    this.onTap,
  });

  final PlayingCard card;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      width: 64,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.amber : Colors.black26,
          width: enabled ? 3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rankLabel,
            style: TextStyle(
              color: card.suitColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                color: card.suitColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(onTap: onTap, child: cardWidget);
  }
}
