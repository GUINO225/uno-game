import 'dart:async';
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

enum JokerKind { red, black }

enum PlayerTurn { human, bot }

class PlayingCard {
  const PlayingCard._({this.suit, this.rank, this.jokerKind});

  const PlayingCard.normal({required Suit suit, required int rank}) : this._(suit: suit, rank: rank);

  const PlayingCard.joker({required JokerKind kind}) : this._(jokerKind: kind);

  final Suit? suit;
  final int? rank;
  final JokerKind? jokerKind;

  bool get isJoker => jokerKind != null;

  bool get isRed {
    if (jokerKind != null) {
      return jokerKind == JokerKind.red;
    }
    return suit == Suit.hearts || suit == Suit.diamonds;
  }

  bool get isBlack => !isRed;

  bool get canFinishGame => rank != 10 && rank != 11;

  String get rankLabel {
    if (isJoker) {
      return 'JOKER';
    }

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
        return '${rank!}';
    }
  }

  String get suitSymbol {
    if (isJoker) {
      return jokerKind == JokerKind.red ? '🟥' : '⬛';
    }

    switch (suit!) {
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

  String get label => isJoker ? 'Joker ${isRed ? 'rouge' : 'noir'}' : '$rankLabel$suitSymbol';

  Color get suitColor {
    if (isJoker) {
      return isRed ? Colors.red.shade700 : Colors.black87;
    }
    return isRed ? Colors.red.shade700 : Colors.black87;
  }
}

class _PlayResolution {
  const _PlayResolution({required this.extraTurn, required this.skipTurnSwitch});

  final bool extraTurn;
  final bool skipTurnSwitch;
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

  PlayerTurn _turn = PlayerTurn.human;
  String _status = '';
  bool _gameOver = false;
  bool _isResolvingTurn = false;

  int _forcedHumanDrawRemaining = 0;
  bool _humanMustAnswerAce = false;
  bool _botMustAnswerAce = false;
  Suit? _activeSuitConstraint;

  bool _isEightDemandOverlayVisible = false;
  Suit? _eightDemandOverlaySuit;
  String _eightDemandOverlayMessage = '';

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
      _isResolvingTurn = false;
      _forcedHumanDrawRemaining = 0;
      _humanMustAnswerAce = false;
      _botMustAnswerAce = false;
      _activeSuitConstraint = null;
      _isEightDemandOverlayVisible = false;
      _eightDemandOverlaySuit = null;
      _eightDemandOverlayMessage = '';
    });
  }

  List<PlayingCard> _createDeck() {
    final deck = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard.normal(suit: suit, rank: rank));
      }
    }
    deck.add(const PlayingCard.joker(kind: JokerKind.red));
    deck.add(const PlayingCard.joker(kind: JokerKind.black));
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
      if (card.rank == 8 || card.rank == 10 || card.rank == 11 || card.isJoker) {
        _drawPile.insert(0, card);
        _shuffleDeck(_drawPile);
      } else {
        _discardPile.add(card);
        return;
      }
    }
  }

  PlayingCard get _topDiscard => _discardPile.last;

  bool _sameColor(PlayingCard a, PlayingCard b) {
    return a.isRed == b.isRed;
  }

  bool _isCardPlayableForHand(PlayingCard card, List<PlayingCard> hand) {
    if (_discardPile.isEmpty) {
      return false;
    }

    final isLastCard = hand.length == 1;
    if (isLastCard && !card.canFinishGame) {
      return false;
    }

    if (card.rank == 8) {
      return true;
    }

    if (_activeSuitConstraint != null) {
      return !card.isJoker && card.suit == _activeSuitConstraint;
    }

    final top = _topDiscard;

    if (card.isJoker) {
      return _sameColor(card, top);
    }

    if (top.isJoker) {
      return _sameColor(card, top);
    }

    return card.suit == top.suit || card.rank == top.rank;
  }

  bool _isCardPlayableForHuman(PlayingCard card) {
    if (_humanMustAnswerAce) {
      return !card.isJoker && card.rank == 1;
    }
    if (_forcedHumanDrawRemaining > 0) {
      return false;
    }
    return _isCardPlayableForHand(card, _humanHand);
  }

  Future<void> _onHumanTapCard(PlayingCard card) async {
    if (_turn != PlayerTurn.human || _gameOver || _isResolvingTurn || _forcedHumanDrawRemaining > 0) {
      return;
    }
    if (!_isCardPlayableForHuman(card)) {
      return;
    }

    if (_humanMustAnswerAce) {
      setState(() {
        _humanMustAnswerAce = false;
      });
    }

    _isResolvingTurn = true;
    await _humanPlayCard(card);
    _isResolvingTurn = false;
  }

  Future<void> _humanPlayCard(PlayingCard card) async {
    _playCard(hand: _humanHand, card: card, playerName: 'Vous');

    final result = await _applyCardEffects(card: card, currentTurn: PlayerTurn.human, sourceLabel: 'Vous');

    if (_checkVictory(player: 'Vous', hand: _humanHand, lastPlayed: card)) {
      return;
    }

    if (result.extraTurn) {
      setState(() {
        _status = '${_status}\nVous rejouez.';
      });
      return;
    }

    if (result.skipTurnSwitch) {
      return;
    }

    _endHumanTurn();
  }

  Future<void> _onHumanDraw() async {
    if (_turn != PlayerTurn.human || _gameOver || _isResolvingTurn || _humanMustAnswerAce) {
      return;
    }

    if (_forcedHumanDrawRemaining > 0) {
      final card = _drawOneCard();
      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la contrainte de joker.';
          _forcedHumanDrawRemaining = 0;
        });
        return;
      }

      setState(() {
        _humanHand.add(card);
        _forcedHumanDrawRemaining--;
        _status = _forcedHumanDrawRemaining > 0
            ? 'Vous devez d\'abord piocher $_forcedHumanDrawRemaining carte(s).'
            : 'Contrainte terminée. À vous de jouer.';
      });
      return;
    }

    final drawn = _drawCards(_humanHand, 1);
    if (drawn.isEmpty) {
      setState(() {
        _status = 'La pioche est vide.';
      });
      _endHumanTurn();
      return;
    }

    setState(() {
      _status = 'Vous piochez ${drawn.first.label}.';
    });

    if (_isCardPlayableForHuman(drawn.first)) {
      _isResolvingTurn = true;
      await _humanPlayCard(drawn.first);
      _isResolvingTurn = false;
    } else {
      _endHumanTurn();
    }
  }

  List<PlayingCard> _drawCards(List<PlayingCard> destination, int count) {
    final drawn = <PlayingCard>[];
    for (int i = 0; i < count; i++) {
      final card = _drawOneCard();
      if (card == null) {
        break;
      }
      destination.add(card);
      drawn.add(card);
    }
    return drawn;
  }

  PlayingCard? _drawOneCard() {
    if (_drawPile.isEmpty) {
      _rebuildDrawPileFromDiscard();
    }
    if (_drawPile.isEmpty) {
      return null;
    }
    return _drawPile.removeLast();
  }

  void _rebuildDrawPileFromDiscard() {
    if (_discardPile.length <= 1) {
      return;
    }

    final topCard = _discardPile.removeLast();
    _drawPile = List<PlayingCard>.from(_discardPile);
    _discardPile
      ..clear()
      ..add(topCard);
    _shuffleDeck(_drawPile);
  }

  void _playCard({
    required List<PlayingCard> hand,
    required PlayingCard card,
    required String playerName,
  }) {
    setState(() {
      hand.remove(card);
      _discardPile.add(card);
      if (card.rank != 8) {
        _activeSuitConstraint = null;
      }
      _status = '$playerName joue ${card.label}.';
    });
  }

  Future<_PlayResolution> _applyCardEffects({
    required PlayingCard card,
    required PlayerTurn currentTurn,
    required String sourceLabel,
  }) async {
    if (card.rank == 1) {
      if (currentTurn == PlayerTurn.human) {
        final botHasAce = _botHand.any((c) => !c.isJoker && c.rank == 1);
        if (botHasAce) {
          setState(() {
            _botMustAnswerAce = true;
            _status = 'Vous jouez un As : le bot doit répondre avec un As.';
          });
          return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
        }

        final drawn = _drawCards(_botHand, 1).length;
        setState(() {
          _status = drawn > 0
              ? 'Le bot n’a pas d’As : il pioche 1 carte.'
              : 'Le bot n’a pas d’As : il ne peut pas piocher.';
        });
        return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
      }

      final hasHumanAce = _humanHand.any((c) => !c.isJoker && c.rank == 1);
      if (hasHumanAce) {
        setState(() {
          _humanMustAnswerAce = true;
          _status = 'Le bot joue un As : vous devez répondre avec un As.';
        });
        return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
      }

      final drawn = _drawCards(_humanHand, 1).length;
      setState(() {
        _status = drawn > 0
            ? 'Vous n’avez pas d’As : vous devez piocher 1 carte.'
            : 'Vous n’avez pas d’As : vous ne pouvez pas piocher.';
      });
      return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
    }

    if (card.rank == 2) {
      if (currentTurn == PlayerTurn.human) {
        setState(() {
          _status = '$sourceLabel joue un 2 : le bot doit piocher 2 cartes.';
        });
        await _botDrawWithVisual(2);
      } else {
        final drawn = _drawCards(_humanHand, 2).length;
        setState(() {
          _status = '$sourceLabel joue un 2 : vous devez piocher $drawn cartes.';
        });
      }
      return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
    }

    if (card.isJoker) {
      if (currentTurn == PlayerTurn.human) {
        setState(() {
          _status = '$sourceLabel joue un Joker : le bot pioche 8 cartes.';
        });
        await _botDrawWithVisual(8);
      } else {
        setState(() {
          _forcedHumanDrawRemaining = 8;
          _status = 'Le bot joue un Joker : vous devez d\'abord piocher 8 cartes.';
        });
      }
      return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
    }

    if (card.rank == 8) {
      final askedSuit = await _getAskedSuit(currentTurn);
      if (_gameOver || !mounted) {
        return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
      }

      final demander = currentTurn == PlayerTurn.human
          ? 'Vous demandez ${_suitName(askedSuit)}.'
          : 'Le bot demande ${_suitName(askedSuit)}.';
      setState(() {
        _activeSuitConstraint = askedSuit;
        _status = demander;
      });
      return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
    }

    if (card.rank == 10 || card.rank == 11) {
      setState(() {
        _status = card.rank == 11
            ? '$sourceLabel joue un Valet : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'le bot'} rejoue.'
            : '$sourceLabel joue un 10 : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'le bot'} rejoue.';
      });
      return const _PlayResolution(extraTurn: true, skipTurnSwitch: false);
    }

    return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
  }

  Future<void> _botDrawWithVisual(int count) async {
    for (int i = 0; i < count; i++) {
      if (_gameOver) {
        return;
      }
      final card = _drawOneCard();
      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la pénalité du bot.';
        });
        return;
      }

      setState(() {
        _botHand.add(card);
        final remaining = count - i - 1;
        _status = remaining > 0 ? 'Le bot pioche ${remaining + 1} cartes... ($remaining restantes)' : 'Le bot a terminé sa pioche forcée.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
  }

  Future<Suit> _getAskedSuit(PlayerTurn player) async {
    if (player == PlayerTurn.human) {
      return _showSuitChooserDialog();
    }

    final bestSuit = _chooseRequestedSuitForBot(_botHand);
    await _showEightDemandOverlay(
      suit: bestSuit,
      message: 'Le bot demande ${_suitName(bestSuit)}',
    );
    return bestSuit;
  }

  Future<void> _showEightDemandOverlay({required Suit suit, required String message}) async {
    setState(() {
      _eightDemandOverlaySuit = suit;
      _eightDemandOverlayMessage = message;
      _isEightDemandOverlayVisible = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _isEightDemandOverlayVisible = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    setState(() {
      _eightDemandOverlaySuit = null;
      _eightDemandOverlayMessage = '';
    });
  }

  Future<Suit> _showSuitChooserDialog() async {
    final selected = await showDialog<Suit>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisissez une enseigne'),
          content: SizedBox(
            width: 360,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: Suit.values
                  .map(
                    (suit) => _SuitChoiceTile(
                      suit: suit,
                      onTap: () => Navigator.of(context).pop(suit),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    final chosenSuit = selected ?? Suit.spades;
    await _showEightDemandOverlay(
      suit: chosenSuit,
      message: 'Vous demandez ${_suitName(chosenSuit)}',
    );
    return chosenSuit;
  }

  Suit _chooseRequestedSuitForBot(List<PlayingCard> hand) {
    final counts = <Suit, int>{};
    for (final card in hand) {
      if (!card.isJoker) {
        counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return Suit.values[_random.nextInt(Suit.values.length)];
    }

    Suit bestSuit = counts.keys.first;
    int bestCount = counts[bestSuit] ?? 0;

    counts.forEach((suit, count) {
      if (count > bestCount) {
        bestSuit = suit;
        bestCount = count;
      }
    });

    return bestSuit;
  }

  PlayingCard? _findRequestedCard(List<PlayingCard> hand, int rank) {
    final candidates = hand.where((card) => !card.isJoker && card.rank == rank).toList();
    if (candidates.isEmpty) {
      return null;
    }

    if (hand.length == 1 && !candidates.first.canFinishGame) {
      return null;
    }

    return candidates.first;
  }

  void _endHumanTurn() {
    if (_gameOver) {
      return;
    }
    setState(() {
      _turn = PlayerTurn.bot;
      _status = 'Tour du bot...';
    });
    _runBotTurn();
  }

  Future<void> _runBotTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || _gameOver || _turn != PlayerTurn.bot) {
      return;
    }

    if (_botMustAnswerAce) {
      final botAce = _findRequestedCard(_botHand, 1);
      if (botAce == null) {
        final drawn = _drawCards(_botHand, 1).length;
        setState(() {
          _botMustAnswerAce = false;
          _status = drawn > 0
              ? 'Le bot n’a pas d’As : il pioche 1 carte.'
              : 'Le bot n’a pas d’As : il ne peut pas piocher.';
        });
        _switchToHuman();
        return;
      }

      _playCard(hand: _botHand, card: botAce, playerName: 'Le bot');

      if (_checkVictory(player: 'Le bot', hand: _botHand, lastPlayed: botAce)) {
        return;
      }

      final hasHumanAce = _humanHand.any((c) => !c.isJoker && c.rank == 1);
      if (hasHumanAce) {
        setState(() {
          _botMustAnswerAce = false;
          _humanMustAnswerAce = true;
          _turn = PlayerTurn.human;
          _status = 'Le bot joue un As : vous devez répondre avec un As.';
        });
      } else {
        final drawn = _drawCards(_humanHand, 1).length;
        setState(() {
          _botMustAnswerAce = false;
          _turn = PlayerTurn.human;
          _status = drawn > 0
              ? 'Vous n’avez pas d’As : vous devez piocher 1 carte.'
              : 'Vous n’avez pas d’As : vous ne pouvez pas piocher.';
        });
      }
      return;
    }

    final playable = _botHand.where((card) => _isCardPlayableForHand(card, _botHand)).toList();
    PlayingCard? chosen;

    if (playable.isNotEmpty) {
      final nonEight = playable.where((card) => card.rank != 8).toList();
      chosen = nonEight.isNotEmpty ? nonEight.first : playable.first;
    }

    if (chosen == null) {
      final drawn = _drawCards(_botHand, 1);
      if (drawn.isEmpty) {
        setState(() {
          _status = 'Le bot ne peut pas piocher. Pioche vide.';
        });
        _switchToHuman();
        return;
      }

      setState(() {
        _status = 'Le bot pioche une carte.';
      });

      final drawnCard = drawn.first;
      if (_isCardPlayableForHand(drawnCard, _botHand)) {
        chosen = drawnCard;
      } else {
        _switchToHuman();
        return;
      }
    }

    _playCard(hand: _botHand, card: chosen, playerName: 'Le bot');
    final outcome = await _applyCardEffects(card: chosen, currentTurn: PlayerTurn.bot, sourceLabel: 'Le bot');

    if (_checkVictory(player: 'Le bot', hand: _botHand, lastPlayed: chosen)) {
      return;
    }

    if (outcome.extraTurn) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _runBotTurn();
      return;
    }

    if (outcome.skipTurnSwitch) {
      return;
    }

    _switchToHuman();
  }

  bool _checkVictory({required String player, required List<PlayingCard> hand, required PlayingCard lastPlayed}) {
    if (hand.isNotEmpty) {
      return false;
    }

    if (!lastPlayed.canFinishGame) {
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
        _status = _forcedHumanDrawRemaining > 0
            ? 'Vous devez d\'abord piocher $_forcedHumanDrawRemaining carte(s).'
            : 'À vous de jouer';
      }
    });
  }

  String _suitName(Suit suit) => switch (suit) {
        Suit.spades => 'pique',
        Suit.hearts => 'cœur',
        Suit.diamonds => 'carreau',
        Suit.clubs => 'trèfle',
      };

  String _suitSymbol(Suit suit) => switch (suit) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
      };

  Color _suitColor(Suit suit) => switch (suit) {
        Suit.hearts || Suit.diamonds => Colors.red.shade700,
        Suit.spades || Suit.clubs => Colors.black87,
      };

  @override
  Widget build(BuildContext context) {
    final canInteract = _turn == PlayerTurn.human &&
        !_gameOver &&
        !_isResolvingTurn &&
        _forcedHumanDrawRemaining == 0;

    final mustDraw = _turn == PlayerTurn.human && !_gameOver && _forcedHumanDrawRemaining > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      appBar: AppBar(
        title: const Text('Huit américain'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoPanel(),
                  const SizedBox(height: 12),
                  _botHandArea(),
                  const SizedBox(height: 12),
                  _centerArea(),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: (_turn == PlayerTurn.human && !_gameOver && !_humanMustAnswerAce) ? _onHumanDraw : null,
                    child: Text(mustDraw ? 'Piocher (reste $_forcedHumanDrawRemaining)' : 'Piocher'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Votre main',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (_humanMustAnswerAce) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        'Réponse obligatoire : jouez un As.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
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
                                  enabled: canInteract && _isCardPlayableForHuman(card),
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
          if (_isEightDemandOverlayVisible && _eightDemandOverlaySuit != null)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isEightDemandOverlayVisible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      tween: Tween<double>(begin: 0.85, end: 1),
                      builder: (context, value, child) => Transform.scale(scale: value, child: child),
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Nouvelle enseigne', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 10),
                            _EightSuitCard(suit: _eightDemandOverlaySuit!),
                            const SizedBox(height: 10),
                            Text(_eightDemandOverlayMessage),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoPanel() {
    final forcedText = _forcedHumanDrawRemaining > 0
        ? 'Contrainte Joker : piochez $_forcedHumanDrawRemaining carte(s) avant de jouer.'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
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
          Text('Défausse : ${_topDiscard.label}', style: const TextStyle(color: Colors.white)),
          if (_activeSuitConstraint != null) ...[
            const SizedBox(height: 4),
            Text(
              'Enseigne active (8) : ${_suitName(_activeSuitConstraint!)} ${_suitSymbol(_activeSuitConstraint!)}',
              style: TextStyle(color: _suitColor(_activeSuitConstraint!), fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 4),
          Text('Statut : $_status', style: const TextStyle(color: Colors.white)),
          if (forcedText != null) ...[
            const SizedBox(height: 6),
            Text(forcedText, style: const TextStyle(color: Colors.amberAccent)),
          ],
        ],
      ),
    );
  }

  Widget _botHandArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Main du bot (cachée)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, __) => const CardBackView(),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemCount: _botHand.length,
          ),
        ),
      ],
    );
  }

  Widget _centerArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pioche', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                const CardBackView(width: 70, height: 100),
                Text('${_drawPile.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
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

class CardBackView extends StatelessWidget {
  const CardBackView({super.key, this.width = 52, this.height = 72});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF172554)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white70),
      ),
      child: const Center(child: Icon(Icons.style, color: Colors.white70, size: 18)),
    );
  }
}

class CardView extends StatelessWidget {
  const CardView({super.key, required this.card, this.enabled = false, this.onTap});

  final PlayingCard card;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      width: 64,
      height: 96,
      decoration: BoxDecoration(
        color: card.isJoker ? (card.isRed ? Colors.red.shade50 : Colors.grey.shade200) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled ? Colors.amber : Colors.black26, width: enabled ? 3 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))],
      ),
      padding: const EdgeInsets.all(8),
      child: card.isJoker
          ? Center(
              child: Text(
                card.isRed ? 'Joker\nRouge' : 'Joker\nNoir',
                textAlign: TextAlign.center,
                style: TextStyle(color: card.suitColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.rankLabel,
                  style: TextStyle(color: card.suitColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(color: card.suitColor, fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    );

    return GestureDetector(onTap: onTap, child: cardWidget);
  }
}

class _SuitChoiceTile extends StatelessWidget {
  const _SuitChoiceTile({required this.suit, required this.onTap});

  final Suit suit;
  final VoidCallback onTap;

  String get _symbol => switch (suit) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
      };

  String get _name => switch (suit) {
        Suit.spades => 'pique',
        Suit.hearts => 'cœur',
        Suit.diamonds => 'carreau',
        Suit.clubs => 'trèfle',
      };

  Color get _color => switch (suit) {
        Suit.hearts || Suit.diamonds => Colors.red.shade700,
        Suit.spades || Suit.clubs => Colors.black87,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 156,
        height: 124,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withValues(alpha: 0.55), width: 1.8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(1, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_symbol, style: TextStyle(color: _color, fontSize: 44, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EightSuitCard extends StatelessWidget {
  const _EightSuitCard({required this.suit});

  final Suit suit;

  String get _symbol => switch (suit) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
      };

  Color get _color => switch (suit) {
        Suit.hearts || Suit.diamonds => Colors.red.shade700,
        Suit.spades || Suit.clubs => Colors.black87,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 146,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey, width: 1.6),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('8', style: TextStyle(color: _color, fontSize: 26, fontWeight: FontWeight.w700)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(_symbol, style: TextStyle(color: _color, fontSize: 44, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
