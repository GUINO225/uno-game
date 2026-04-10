import 'dart:async';
import 'dart:math';
import 'dart:ui';

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
      title: 'GUINO',
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

enum _FlightCardFace { front, back }

class PlayingCard {
  const PlayingCard._({this.suit, this.rank, this.jokerKind});

  const PlayingCard.normal({required Suit suit, required int rank})
      : this._(suit: suit, rank: rank);

  const PlayingCard.joker({required JokerKind kind})
      : this._(jokerKind: kind);

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

  String get label =>
      isJoker ? 'Joker ${isRed ? 'rouge' : 'noir'}' : '$rankLabel$suitSymbol';

  Color get suitColor {
    if (isJoker) {
      return isRed ? Colors.red.shade700 : Colors.black87;
    }
    return isRed ? Colors.red.shade700 : Colors.black87;
  }
}

class _PlayResolution {
  const _PlayResolution({
    required this.extraTurn,
    required this.skipTurnSwitch,
  });

  final bool extraTurn;
  final bool skipTurnSwitch;
}

class _CardFlightData {
  const _CardFlightData({
    required this.begin,
    required this.end,
    required this.face,
    required this.duration,
    required this.curve,
    required this.arcHeight,
    required this.beginScale,
    required this.endScale,
    this.card,
  });

  final Alignment begin;
  final Alignment end;
  final _FlightCardFace face;
  final Duration duration;
  final Curve curve;
  final double arcHeight;
  final double beginScale;
  final double endScale;
  final PlayingCard? card;
}

class CrazyEightsPage extends StatefulWidget {
  const CrazyEightsPage({super.key});

  @override
  State<CrazyEightsPage> createState() => _CrazyEightsPageState();
}

class _CrazyEightsPageState extends State<CrazyEightsPage>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();

  List<PlayingCard> _drawPile = <PlayingCard>[];
  final List<PlayingCard> _discardPile = <PlayingCard>[];
  final List<PlayingCard> _humanHand = <PlayingCard>[];
  final List<PlayingCard> _botHand = <PlayingCard>[];

  PlayerTurn _turn = PlayerTurn.human;
  String _status = '';
  bool _gameOver = false;
  bool _isResolvingTurn = false;

  int _forcedDrawCount = 0;
  PlayerTurn? _forcedDrawTarget;
  PlayerTurn? _forcedDrawSource;
  bool _humanMustAnswerAce = false;
  bool _botMustAnswerAce = false;
  Suit? _activeSuitConstraint;

  bool _isEightDemandOverlayVisible = false;
  Suit? _eightDemandOverlaySuit;
  String _eightDemandOverlayMessage = '';

  bool _isRoundInfoOverlayVisible = false;
  String _roundInfoOverlayMessage = '';

  int _humanScore = 0;
  int _botScore = 0;
  _CardFlightData? _cardFlight;
  int _flightNonce = 0;

  final GlobalKey _tableKey = GlobalKey();
  final GlobalKey _discardPileKey = GlobalKey();
  final Map<PlayingCard, GlobalKey> _humanCardKeys = <PlayingCard, GlobalKey>{};

  static const Alignment _drawPileAnchor = Alignment(-0.45, -0.05);
  static const Alignment _discardPileAnchor = Alignment(0.0, -0.02);
  static const Alignment _humanHandAnchor = Alignment(0.0, 0.87);
  static const Alignment _botHandAnchor = Alignment(0.0, -0.82);

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  Future<void> _animateCardFlight({
    required Alignment from,
    required Alignment to,
    required _FlightCardFace face,
    PlayingCard? card,
    Duration duration = const Duration(milliseconds: 620),
    Curve curve = Curves.easeInOutCubic,
    double arcHeight = 0,
    double beginScale = 1,
    double endScale = 1,
  }) async {
    final int nonce = ++_flightNonce;
    setState(() {
      _cardFlight = _CardFlightData(
        begin: from,
        end: to,
        face: face,
        duration: duration,
        curve: curve,
        arcHeight: arcHeight,
        beginScale: beginScale,
        endScale: endScale,
        card: card,
      );
    });

    await Future<void>.delayed(duration);
    if (!mounted || nonce != _flightNonce) {
      return;
    }

    setState(() {
      _cardFlight = null;
    });
  }

  Future<void> _animateInitialDeal() async {
    for (int i = 0; i < 7; i++) {
      if (!mounted) {
        return;
      }
      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _humanHandAnchor,
        face: _FlightCardFace.back,
        duration: const Duration(milliseconds: 220),
      );
      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _botHandAnchor,
        face: _FlightCardFace.back,
        duration: const Duration(milliseconds: 220),
      );
    }
  }

  void _startNewGame() {
    final PlayerTurn dealer =
    _random.nextBool() ? PlayerTurn.human : PlayerTurn.bot;
    final PlayerTurn startingPlayer = _opponentOf(dealer);

    _drawPile = _createDeck();
    _shuffleDeck(_drawPile);

    _discardPile.clear();

    _humanHand
      ..clear()
      ..addAll(_dealCards(_drawPile, 7));

    _botHand
      ..clear()
      ..addAll(_dealCards(_drawPile, 7));

    final PlayingCard openingCard = _openFirstDiscardCard();

    setState(() {
      _turn = startingPlayer;
      _status = '${_turnLabel(startingPlayer)} commence.';
      _gameOver = false;
      _isResolvingTurn = false;
      _forcedDrawCount = 0;
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _humanMustAnswerAce = false;
      _botMustAnswerAce = false;
      _activeSuitConstraint = null;
      _isEightDemandOverlayVisible = false;
      _eightDemandOverlaySuit = null;
      _eightDemandOverlayMessage = '';
      _isRoundInfoOverlayVisible = false;
      _roundInfoOverlayMessage = '';
      _cardFlight = null;
    });

    unawaited(_showRoundInfoOverlay(
      dealer == PlayerTurn.human ? 'Vous distribuez' : 'Le bot distribue',
    ));
    unawaited(_animateInitialDeal());

    _applyOpeningCardPenaltyIfNeeded(
      openingCard,
      startingPlayer: startingPlayer,
      dealer: dealer,
    );

    if (_turn == PlayerTurn.bot && !_gameOver) {
      unawaited(_runBotTurn());
    }
  }

  List<PlayingCard> _createDeck() {
    final List<PlayingCard> deck = <PlayingCard>[];

    for (final Suit suit in Suit.values) {
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

  PlayerTurn _opponentOf(PlayerTurn player) {
    return player == PlayerTurn.human ? PlayerTurn.bot : PlayerTurn.human;
  }

  String _turnLabel(PlayerTurn turn) {
    return turn == PlayerTurn.human ? 'Vous' : 'Le bot';
  }

  List<PlayingCard> _dealCards(List<PlayingCard> deck, int count) {
    final List<PlayingCard> dealt = <PlayingCard>[];
    for (int i = 0; i < count && deck.isNotEmpty; i++) {
      dealt.add(deck.removeLast());
    }
    return dealt;
  }

  PlayingCard _openFirstDiscardCard() {
    while (_drawPile.isNotEmpty) {
      final PlayingCard card = _drawPile.removeLast();
      if (card.rank == 8 || card.rank == 10 || card.rank == 11) {
        _drawPile.insert(0, card);
        _shuffleDeck(_drawPile);
      } else {
        _discardPile.add(card);
        return card;
      }
    }

    const PlayingCard fallback =
    PlayingCard.normal(suit: Suit.spades, rank: 3);
    _discardPile.add(fallback);
    return fallback;
  }

  PlayingCard get _topDiscard => _discardPile.last;

  void _applyOpeningCardPenaltyIfNeeded(
      PlayingCard openingCard, {
        required PlayerTurn startingPlayer,
        required PlayerTurn dealer,
      }) {
    if (openingCard.rank == 2) {
      _setForcedDraw(
        target: startingPlayer,
        source: dealer,
        count: 2,
        announcement:
        '${_turnLabel(startingPlayer)} commence, mais la carte d’ouverture est un 2.',
      );
      return;
    }

    if (openingCard.isJoker) {
      _setForcedDraw(
        target: startingPlayer,
        source: dealer,
        count: 9,
        announcement:
        '${_turnLabel(startingPlayer)} commence, mais la carte d’ouverture est un joker.',
      );
    }
  }

  bool _sameColor(PlayingCard a, PlayingCard b) {
    return a.isRed == b.isRed;
  }

  bool _isCardPlayableForHand(PlayingCard card, List<PlayingCard> hand) {
    if (_discardPile.isEmpty) {
      return false;
    }

    final bool isLastCard = hand.length == 1;
    if (isLastCard && !card.canFinishGame) {
      return false;
    }

    if (card.rank == 8) {
      return true;
    }

    if (_activeSuitConstraint != null) {
      return !card.isJoker && card.suit == _activeSuitConstraint;
    }

    final PlayingCard top = _topDiscard;

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
      return _isValidAceResponse(card);
    }

    if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.human) {
      return false;
    }

    return _isCardPlayableForHand(card, _humanHand);
  }

  bool _isValidAceResponse(PlayingCard card) {
    if (_discardPile.isEmpty || _topDiscard.rank != 1) {
      return false;
    }

    if (!card.isJoker && card.rank == 1) {
      return true;
    }

    if (card.isJoker) {
      return card.isRed == _topDiscard.isRed;
    }

    return false;
  }

  void _setForcedDraw({
    required PlayerTurn target,
    required PlayerTurn source,
    required int count,
    required String announcement,
  }) {
    final String starter = count > 1 ? 'cartes' : 'carte';

    setState(() {
      _forcedDrawCount = count;
      _forcedDrawTarget = target;
      _forcedDrawSource = source;
      _status =
      '$announcement ${_turnLabel(target)} doit d’abord piocher $count $starter.';
    });
  }

  bool _isHumanForcedToDrawNow() {
    return _forcedDrawCount > 0 &&
        _forcedDrawTarget == PlayerTurn.human &&
        _turn == PlayerTurn.human;
  }

  String _forcedDrawRemainingText() {
    if (_forcedDrawCount <= 0 || _forcedDrawTarget == null) {
      return '';
    }

    final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
    return '${_turnLabel(_forcedDrawTarget!)} doit d’abord piocher $_forcedDrawCount $unit.';
  }

  Future<void> _onHumanTapCard(PlayingCard card) async {
    if (_turn != PlayerTurn.human ||
        _gameOver ||
        _isResolvingTurn ||
        _isHumanForcedToDrawNow()) {
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
    await _humanPlayCard(card, fromCardKey: _keyForHumanCard(card));
    _isResolvingTurn = false;
  }

  Future<void> _humanPlayCard(PlayingCard card, {GlobalKey? fromCardKey}) async {
    await _playCard(
      hand: _humanHand,
      card: card,
      playerName: 'Vous',
      from: _humanHandAnchor,
      fromCardKey: fromCardKey,
      to: _discardPileAnchor,
    );

    final _PlayResolution result = await _applyCardEffects(
      card: card,
      currentTurn: PlayerTurn.human,
      sourceLabel: 'Vous',
    );

    if (_checkVictory(
      winner: PlayerTurn.human,
      hand: _humanHand,
      lastPlayed: card,
    )) {
      return;
    }

    if (result.extraTurn) {
      setState(() {
        _status = '$_status\nVous rejouez.';
      });
      return;
    }

    if (result.skipTurnSwitch) {
      return;
    }

    _endHumanTurn();
  }

  Future<void> _onHumanDraw() async {
    if (_turn != PlayerTurn.human || _gameOver || _isResolvingTurn) {
      return;
    }

    if (_isHumanForcedToDrawNow()) {
      final PlayingCard? card = _drawOneCard();
      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la pioche forcée.';
          _forcedDrawCount = 0;
        });
        _finishForcedDrawIfNeeded();
        return;
      }

      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _humanHandAnchor,
        face: _FlightCardFace.back,
      );

      setState(() {
        _humanHand.add(card);
        _forcedDrawCount--;
        final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
        _status = _forcedDrawCount > 0
            ? 'Vous devez d’abord piocher $_forcedDrawCount $unit.'
            : 'Pioche forcée terminée.';
      });

      _finishForcedDrawIfNeeded();
      return;
    }

    if (_humanMustAnswerAce) {
      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _humanHandAnchor,
        face: _FlightCardFace.back,
      );
      final int drawn = _drawCards(_humanHand, 1).length;
      setState(() {
        _humanMustAnswerAce = false;
        _status = drawn > 0
            ? 'Vous choisissez de piocher au lieu de répondre à l’As.'
            : 'Vous choisissez de piocher, mais la pioche est vide.';
      });
      _endHumanTurn();
      return;
    }

    final List<PlayingCard> drawn = _drawCards(_humanHand, 1);
    if (drawn.isEmpty) {
      setState(() {
        _status = 'La pioche est vide.';
      });
      _endHumanTurn();
      return;
    }

    await _animateCardFlight(
      from: _drawPileAnchor,
      to: _humanHandAnchor,
      face: _FlightCardFace.back,
    );

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
    final List<PlayingCard> drawn = <PlayingCard>[];

    for (int i = 0; i < count; i++) {
      final PlayingCard? card = _drawOneCard();
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

    final PlayingCard topCard = _discardPile.removeLast();
    _drawPile = List<PlayingCard>.from(_discardPile);
    _discardPile
      ..clear()
      ..add(topCard);

    _shuffleDeck(_drawPile);
  }

  Future<void> _playCard({
    required List<PlayingCard> hand,
    required PlayingCard card,
    required String playerName,
    required Alignment from,
    required Alignment to,
    GlobalKey? fromCardKey,
  }) async {
    final Alignment flightFrom = fromCardKey != null
        ? (_alignmentForKey(fromCardKey) ?? from)
        : from;
    final Alignment flightTo = _alignmentForKey(_discardPileKey) ?? to;
    final bool useExactHumanOverlayFlight =
        fromCardKey != null && hand == _humanHand;

    setState(() {
      hand.remove(card);
      _humanCardKeys.remove(card);
      if (card.rank != 8) {
        _activeSuitConstraint = null;
      }
      _status = '$playerName joue ${card.label}.';
    });

    if (useExactHumanOverlayFlight) {
      final bool didAnimate = await _animateHumanCardOverlayFlight(
        card: card,
        fromCardKey: fromCardKey,
      );
      if (!didAnimate) {
        await _animateCardFlight(
          from: flightFrom,
          to: flightTo,
          face: _FlightCardFace.front,
          card: card,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutQuart,
          arcHeight: 0.09,
          beginScale: 1,
          endScale: 0.9,
        );
      }
    } else {
      await _animateCardFlight(
        from: flightFrom,
        to: flightTo,
        face: _FlightCardFace.front,
        card: card,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutQuart,
        arcHeight: 0.09,
        beginScale: 1,
        endScale: 0.9,
      );
    }

    setState(() {
      _discardPile.add(card);
    });
  }

  Future<_PlayResolution> _applyCardEffects({
    required PlayingCard card,
    required PlayerTurn currentTurn,
    required String sourceLabel,
  }) async {
    if (card.rank == 1) {
      if (currentTurn == PlayerTurn.human) {
        setState(() {
          _botMustAnswerAce = true;
          _status =
          'Vous jouez un As : le bot doit répondre avec un As, un joker de même couleur, ou piocher.';
        });
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }

      setState(() {
        _humanMustAnswerAce = true;
        _status =
        'Le bot joue un As : répondez avec un As, un joker de même couleur, ou piochez.';
      });

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 2) {
      if (currentTurn == PlayerTurn.human) {
        _setForcedDraw(
          target: PlayerTurn.bot,
          source: PlayerTurn.human,
          count: 2,
          announcement: 'Vous jouez un 2 : le bot doit piocher 2 cartes.',
        );
        await _runForcedDrawForBot();
        return const _PlayResolution(
          extraTurn: true,
          skipTurnSwitch: false,
        );
      } else {
        _setForcedDraw(
          target: PlayerTurn.human,
          source: PlayerTurn.bot,
          count: 2,
          announcement: 'Le bot joue un 2 : vous devez piocher 2 cartes.',
        );
      }

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.isJoker) {
      if (currentTurn == PlayerTurn.human) {
        _setForcedDraw(
          target: PlayerTurn.bot,
          source: PlayerTurn.human,
          count: 9,
          announcement: 'Vous jouez un joker : le bot doit piocher 9 cartes.',
        );
        await _runForcedDrawForBot();
        return const _PlayResolution(
          extraTurn: true,
          skipTurnSwitch: false,
        );
      } else {
        _setForcedDraw(
          target: PlayerTurn.human,
          source: PlayerTurn.bot,
          count: 9,
          announcement: 'Le bot joue un joker : vous devez piocher 9 cartes.',
        );
      }

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 8) {
      final Suit askedSuit = await _getAskedSuit(currentTurn);
      if (_gameOver || !mounted) {
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }

      final String demander = currentTurn == PlayerTurn.human
          ? 'Vous demandez ${_suitName(askedSuit)}.'
          : 'Le bot demande ${_suitName(askedSuit)}.';

      setState(() {
        _activeSuitConstraint = askedSuit;
        _status = demander;
      });

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 10 || card.rank == 11) {
      setState(() {
        _status = card.rank == 11
            ? '$sourceLabel joue un Valet : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'le bot'} rejoue.'
            : '$sourceLabel joue un 10 : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'le bot'} rejoue.';
      });

      return const _PlayResolution(
        extraTurn: true,
        skipTurnSwitch: false,
      );
    }

    return const _PlayResolution(
      extraTurn: false,
      skipTurnSwitch: false,
    );
  }

  void _finishForcedDrawIfNeeded() {
    if (_forcedDrawCount > 0 || _forcedDrawSource == null) {
      return;
    }

    final PlayerTurn source = _forcedDrawSource!;
    final PlayerTurn? target = _forcedDrawTarget;

    setState(() {
      _status =
      '${target != null ? _turnLabel(target) : 'Le joueur pénalisé'} a terminé la pioche forcée. Le tour reste à ${_turnLabel(source)}.';
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _turn = source;
    });

    if (_turn == PlayerTurn.bot && !_gameOver) {
      unawaited(_runBotTurn());
    }
  }

  Future<void> _runForcedDrawForBot() async {
    while (_forcedDrawCount > 0 &&
        _forcedDrawTarget == PlayerTurn.bot &&
        !_gameOver) {
      final PlayingCard? card = _drawOneCard();

      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la pénalité du bot.';
          _forcedDrawCount = 0;
        });
        break;
      }

      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _botHandAnchor,
        face: _FlightCardFace.back,
      );

      setState(() {
        _botHand.add(card);
        _forcedDrawCount--;
        final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
        _status = _forcedDrawCount > 0
            ? 'Le bot doit encore piocher $_forcedDrawCount $unit.'
            : 'Le bot a terminé sa pioche forcée.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    _finishForcedDrawIfNeeded();
  }

  Future<Suit> _getAskedSuit(PlayerTurn player) async {
    if (player == PlayerTurn.human) {
      return _showSuitChooserDialog();
    }

    final Suit bestSuit = _chooseRequestedSuitForBot(_botHand);
    await _showEightDemandOverlay(
      suit: bestSuit,
      message: 'Le bot demande ${_suitName(bestSuit)}',
    );
    return bestSuit;
  }

  Future<void> _showEightDemandOverlay({
    required Suit suit,
    required String message,
  }) async {
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

  Future<void> _showRoundInfoOverlay(String message) async {
    setState(() {
      _roundInfoOverlayMessage = message;
      _isRoundInfoOverlayVisible = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    setState(() {
      _isRoundInfoOverlayVisible = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      return;
    }

    setState(() {
      _roundInfoOverlayMessage = '';
    });
  }

  Future<Suit> _showSuitChooserDialog() async {
    final Suit? selected = await showDialog<Suit>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: 260,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: Suit.values
                  .map(
                    (Suit suit) => _SuitChoiceTile(
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

    final Suit chosenSuit = selected ?? Suit.spades;

    await _showEightDemandOverlay(
      suit: chosenSuit,
      message: 'Vous demandez ${_suitName(chosenSuit)}',
    );

    return chosenSuit;
  }

  Suit _chooseRequestedSuitForBot(List<PlayingCard> hand) {
    final Map<Suit, int> counts = <Suit, int>{};

    for (final PlayingCard card in hand) {
      if (!card.isJoker) {
        counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return Suit.values[_random.nextInt(Suit.values.length)];
    }

    Suit bestSuit = counts.keys.first;
    int bestCount = counts[bestSuit] ?? 0;

    counts.forEach((Suit suit, int count) {
      if (count > bestCount) {
        bestSuit = suit;
        bestCount = count;
      }
    });

    return bestSuit;
  }

  void _endHumanTurn() {
    if (_gameOver) {
      return;
    }

    setState(() {
      _turn = PlayerTurn.bot;
      _status = 'Tour du bot...';
    });

    unawaited(_runBotTurn());
  }

  Future<void> _runBotTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted || _gameOver || _turn != PlayerTurn.bot) {
      return;
    }

    if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.bot) {
      await _runForcedDrawForBot();
      return;
    }

    if (_botMustAnswerAce) {
      final List<PlayingCard> aceResponses =
      _botHand.where(_isValidAceResponse).toList();

      final bool chooseToDraw = aceResponses.isEmpty || _random.nextBool();

      if (chooseToDraw) {
        await _animateCardFlight(
          from: _drawPileAnchor,
          to: _botHandAnchor,
          face: _FlightCardFace.back,
        );
        final int drawn = _drawCards(_botHand, 1).length;
        setState(() {
          _botMustAnswerAce = false;
          _status = drawn > 0
              ? 'Le bot choisit de piocher au lieu de répondre à l’As.'
              : 'Le bot choisit de piocher, mais la pioche est vide.';
        });
        _switchToHuman();
        return;
      }

      final PlayingCard botAce = aceResponses.first;
      await _playCard(
        hand: _botHand,
        card: botAce,
        playerName: 'Le bot',
        from: _botHandAnchor,
        to: _discardPileAnchor,
      );

      setState(() {
        _botMustAnswerAce = false;
      });

      if (_checkVictory(
        winner: PlayerTurn.bot,
        hand: _botHand,
        lastPlayed: botAce,
      )) {
        return;
      }

      final _PlayResolution outcome = await _applyCardEffects(
        card: botAce,
        currentTurn: PlayerTurn.bot,
        sourceLabel: 'Le bot',
      );

      if (outcome.extraTurn) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _runBotTurn();
        return;
      }

      if (outcome.skipTurnSwitch) {
        return;
      }

      _switchToHuman();
      return;
    }

    final List<PlayingCard> playable =
    _botHand.where((PlayingCard card) {
      return _isCardPlayableForHand(card, _botHand);
    }).toList();

    PlayingCard? chosen;

    if (playable.isNotEmpty) {
      final List<PlayingCard> nonEight =
      playable.where((PlayingCard card) => card.rank != 8).toList();
      chosen = nonEight.isNotEmpty ? nonEight.first : playable.first;
    }

    if (chosen == null) {
      await _animateCardFlight(
        from: _drawPileAnchor,
        to: _botHandAnchor,
        face: _FlightCardFace.back,
      );
      final List<PlayingCard> drawn = _drawCards(_botHand, 1);

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

      final PlayingCard drawnCard = drawn.first;
      if (_isCardPlayableForHand(drawnCard, _botHand)) {
        chosen = drawnCard;
      } else {
        _switchToHuman();
        return;
      }
    }

    await _playCard(
      hand: _botHand,
      card: chosen,
      playerName: 'Le bot',
      from: _botHandAnchor,
      to: _discardPileAnchor,
    );

    final _PlayResolution outcome = await _applyCardEffects(
      card: chosen,
      currentTurn: PlayerTurn.bot,
      sourceLabel: 'Le bot',
    );

    if (_checkVictory(
      winner: PlayerTurn.bot,
      hand: _botHand,
      lastPlayed: chosen,
    )) {
      return;
    }

    if (outcome.extraTurn) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _runBotTurn();
      return;
    }

    if (outcome.skipTurnSwitch) {
      return;
    }

    _switchToHuman();
  }

  bool _checkVictory({
    required PlayerTurn winner,
    required List<PlayingCard> hand,
    required PlayingCard lastPlayed,
  }) {
    if (hand.isNotEmpty) {
      return false;
    }

    if (!lastPlayed.canFinishGame) {
      return false;
    }

    setState(() {
      if (winner == PlayerTurn.human) {
        _humanScore++;
      } else {
        _botScore++;
      }
      _gameOver = true;
      _status = '${_turnLabel(winner)} a gagné !';
    });

    return true;
  }

  void _switchToHuman() {
    setState(() {
      _turn = PlayerTurn.human;
      if (!_gameOver) {
        _status =
        _isHumanForcedToDrawNow() ? _forcedDrawRemainingText() : 'À vous de jouer';
      }
    });
  }

  String _suitName(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return 'pique';
      case Suit.hearts:
        return 'cœur';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trèfle';
    }
  }

  String _suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  Color _suitColor(Suit suit) {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

  bool _humanHasPlayableCard() {
    return _humanHand.any(_isCardPlayableForHuman);
  }

  bool _canHumanDrawNow() {
    return _turn == PlayerTurn.human && !_gameOver && !_isResolvingTurn;
  }

  Future<bool> _animateHumanCardOverlayFlight({
    required PlayingCard card,
    required GlobalKey fromCardKey,
  }) async {
    final BuildContext? cardContext = fromCardKey.currentContext;
    final BuildContext? discardContext = _discardPileKey.currentContext;
    if (cardContext == null || discardContext == null) {
      return false;
    }

    final RenderObject? cardRender = cardContext.findRenderObject();
    final RenderObject? discardRender = discardContext.findRenderObject();
    if (cardRender is! RenderBox || discardRender is! RenderBox) {
      return false;
    }

    final Size startSize = cardRender.size;
    if (startSize.width == 0 || startSize.height == 0) {
      return false;
    }

    final Offset startCenter = cardRender.localToGlobal(
      startSize.center(Offset.zero),
    );
    final Offset endCenter = discardRender.localToGlobal(
      discardRender.size.center(Offset.zero),
    );

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return false;
    }

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final Animation<double> progress = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutQuart,
    );

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: progress,
            child: CardView(card: card),
            builder: (BuildContext context, Widget? child) {
              final double t = progress.value;
              final Offset center = Offset.lerp(startCenter, endCenter, t) ??
                  endCenter;
              final double arc = sin(pi * t) * 18;
              final double scale = lerpDouble(1, 0.9, t) ?? 1;
              final double width = startSize.width * scale;
              final double height = startSize.height * scale;

              return Stack(
                children: <Widget>[
                  Positioned(
                    left: center.dx - (width / 2),
                    top: center.dy - (height / 2) - arc,
                    width: width,
                    height: height,
                    child: child!,
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    overlay.insert(entry);
    try {
      await controller.forward();
      return true;
    } finally {
      entry.remove();
      controller.dispose();
    }
  }

  GlobalKey _keyForHumanCard(PlayingCard card) {
    return _humanCardKeys.putIfAbsent(card, () => GlobalKey());
  }

  Alignment? _alignmentForKey(GlobalKey key) {
    final BuildContext? tableContext = _tableKey.currentContext;
    final BuildContext? targetContext = key.currentContext;
    if (tableContext == null || targetContext == null) {
      return null;
    }

    final RenderObject? tableRender = tableContext.findRenderObject();
    final RenderObject? targetRender = targetContext.findRenderObject();
    if (tableRender is! RenderBox || targetRender is! RenderBox) {
      return null;
    }

    final Offset center = targetRender.localToGlobal(
      targetRender.size.center(Offset.zero),
      ancestor: tableRender,
    );

    final Size tableSize = tableRender.size;
    if (tableSize.width == 0 || tableSize.height == 0) {
      return null;
    }

    final double dx = (center.dx / tableSize.width) * 2 - 1;
    final double dy = (center.dy / tableSize.height) * 2 - 1;
    return Alignment(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
  }

  bool _shouldHighlightDrawPile() {
    if (!_canHumanDrawNow()) {
      return false;
    }

    if (_isHumanForcedToDrawNow()) {
      return true;
    }

    if (_humanMustAnswerAce) {
      return true;
    }

    return !_humanHasPlayableCard();
  }

  @override
  Widget build(BuildContext context) {
    final bool canInteract = _turn == PlayerTurn.human &&
        !_gameOver &&
        !_isResolvingTurn &&
        !_isHumanForcedToDrawNow();

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: const Text('GUINO'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: _startNewGame,
            tooltip: 'Nouvelle manche',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        key: _tableKey,
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
                  _scoreBar(),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.center,
                      child: _botHandArea(),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.center,
                      child: _centerArea(),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Votre main',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_activeSuitConstraint != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'Enseigne demandée : ${_suitName(_activeSuitConstraint!)} ${_suitSymbol(_activeSuitConstraint!)}',
                            style: TextStyle(
                              color: _suitColor(_activeSuitConstraint!),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (_humanMustAnswerAce) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.7),
                              ),
                            ),
                            child: const Text(
                              'Vous pouvez répondre avec un As, un joker de même couleur, ou choisir de piocher.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 440),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: <Widget>[
                                  for (final PlayingCard card in _humanHand)
                                    TweenAnimationBuilder<double>(
                                      key: ObjectKey(card),
                                      tween: Tween<double>(begin: 0.92, end: 1),
                                      duration: const Duration(milliseconds: 340),
                                      curve: Curves.easeOutQuart,
                                      builder: (BuildContext context, double value, Widget? child) {
                                        return Transform.scale(scale: value, child: child);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: CardView(
                                          key: _keyForHumanCard(card),
                                          card: card,
                                          enabled:
                                              canInteract &&
                                              _isCardPlayableForHuman(card),
                                          onTap: () => _onHumanTapCard(card),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                  color: Colors.black.withOpacity(0.55),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      tween: Tween<double>(begin: 0.85, end: 1),
                      builder:
                          (BuildContext context, double value, Widget? child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Colors.black45, blurRadius: 18),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'Nouvelle carte',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
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
          if (_isRoundInfoOverlayVisible)
            Positioned(
              top: 22,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isRoundInfoOverlayVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _roundInfoOverlayMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_cardFlight != null)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(_flightNonce),
                  duration: _cardFlight!.duration,
                  curve: _cardFlight!.curve,
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (BuildContext context, double t, Widget? child) {
                    final double arc = sin(pi * t) * _cardFlight!.arcHeight;
                    final double dx = lerpDouble(_cardFlight!.begin.x, _cardFlight!.end.x, t) ?? _cardFlight!.end.x;
                    final double dy = (lerpDouble(_cardFlight!.begin.y, _cardFlight!.end.y, t) ?? _cardFlight!.end.y) - arc;
                    final double scale = lerpDouble(_cardFlight!.beginScale, _cardFlight!.endScale, t) ?? 1;

                    return Align(
                      alignment: Alignment(dx, dy),
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: _cardFlight!.face == _FlightCardFace.back
                      ? const CardBackView(width: 64, height: 96)
                      : CardView(
                          card: _cardFlight!.card!,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _botHandArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'Main du bot',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: _botHand.length),
          ],
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
    final bool shouldHighlightDraw = _shouldHighlightDrawPile();
    final bool canDraw = _canHumanDrawNow();
    final bool hasDiscard = _discardPile.isNotEmpty;

    return SizedBox(
      height: 210,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double drawPileWidth = 52;
          const double drawPileHeight = 72;
          const double horizontalMargin = 12;
          const double topMargin = 10;
          const double idealHorizontalOffset = 96;
          const double idealVerticalOffset = 44;
          final double maxHorizontalOffset = max(
            0,
            (constraints.maxWidth / 2) -
                (drawPileWidth / 2) -
                horizontalMargin,
          );
          final double maxVerticalOffset = max(
            0,
            (constraints.maxHeight / 2) -
                (drawPileHeight / 2) -
                topMargin,
          );
          final double drawHorizontalOffset = min(
            idealHorizontalOffset,
            maxHorizontalOffset,
          );
          final double drawVerticalOffset = min(
            idealVerticalOffset,
            maxVerticalOffset,
          );

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Défausse',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    if (hasDiscard)
                      Transform.scale(
                        scale: 1.08,
                        child: _DiscardPileView(
                          key: _discardPileKey,
                          cards: _discardPile,
                        ),
                      )
                    else
                      Transform.scale(
                        scale: 1.08,
                        child: const _EmptyCardSlot(label: 'Vide'),
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(-drawHorizontalOffset, -drawVerticalOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Pioche',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: canDraw ? _onHumanDraw : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          _drawPile.isNotEmpty
                              ? _DrawPileView(highlight: shouldHighlightDraw)
                              : const _EmptyCardSlot(label: '0'),
                          Positioned(
                            right: -8,
                            top: -10,
                            child: _CountBadge(count: _drawPile.length),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _ScorePill(label: 'Joueur', value: _humanScore),
        const SizedBox(width: 10),
        _ScorePill(label: 'Bot', value: _botScore),
      ],
    );
  }
}

class CardBackView extends StatelessWidget {
  const CardBackView({
    super.key,
    this.width = 52,
    this.height = 72,
  });

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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.18)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DrawPileView extends StatefulWidget {
  const _DrawPileView({required this.highlight});

  final bool highlight;

  @override
  State<_DrawPileView> createState() => _DrawPileViewState();
}

class _DrawPileViewState extends State<_DrawPileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.highlight) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DrawPileView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.highlight && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.highlight && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        final double glow =
        widget.highlight ? (0.35 + (_pulseController.value * 0.55)) : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              if (widget.highlight)
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(glow),
                  blurRadius: 22,
                  spreadRadius: 1.5,
                ),
            ],
          ),
          child: child,
        );
      },
      child: const CardBackView(width: 70, height: 100),
    );
  }
}

class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white38),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
    final Widget cardWidget = Container(
      width: 64,
      height: 96,
      decoration: BoxDecoration(
        color: card.isJoker
            ? (card.isRed ? Colors.red.shade50 : Colors.grey.shade200)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.amber : Colors.black26,
          width: enabled ? 3 : 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: card.isJoker
          ? Center(
        child: Text(
          card.isRed ? 'Joker\nRouge' : 'Joker\nNoir',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: card.suitColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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

    return GestureDetector(
      onTap: onTap,
      child: cardWidget,
    );
  }
}



class _DiscardPileView extends StatelessWidget {
  const _DiscardPileView({
    super.key,
    required this.cards,
  });

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    final List<PlayingCard> visible = cards.length <= 5
        ? cards
        : cards.sublist(cards.length - 5);

    return SizedBox(
      width: 84,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < visible.length; i++)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
              left: i * 1.8,
              top: i * 1.2,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                turns: (i.isEven ? -1 : 1) * 0.003 * i,
                child: CardView(card: visible[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuitChoiceTile extends StatelessWidget {
  const _SuitChoiceTile({
    required this.suit,
    required this.onTap,
  });

  final Suit suit;
  final VoidCallback onTap;

  String get _symbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get _name {
    switch (suit) {
      case Suit.spades:
        return 'pique';
      case Suit.hearts:
        return 'cœur';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trèfle';
    }
  }

  Color get _color {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

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
          border: Border.all(
            color: _color.withOpacity(0.55),
            width: 1.8,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(1, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _symbol,
              style: TextStyle(
                color: _color,
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EightSuitCard extends StatelessWidget {
  const _EightSuitCard({required this.suit});

  final Suit suit;

  String get _symbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  Color get _color {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

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
        children: <Widget>[
          Text(
            '8',
            style: TextStyle(
              color: _color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _symbol,
              style: TextStyle(
                color: _color,
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
