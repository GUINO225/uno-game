import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'game_card_avatar.dart';
import 'leaderboard_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';

final RouteObserver<ModalRoute<dynamic>> leaderboardRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with RouteAware {
  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  bool _isLoading = true;
  String? _errorMessage;
  List<PlayerProfile> _players = const <PlayerProfile>[];
  bool _didSubscribeRoute = false;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard(reason: 'initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSubscribeRoute) {
      return;
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      leaderboardRouteObserver.subscribe(this, route);
      _didSubscribeRoute = true;
    }
  }

  @override
  void dispose() {
    if (_didSubscribeRoute) {
      leaderboardRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadLeaderboard(reason: 'didPopNext');
  }

  Future<void> _loadLeaderboard({
    required String reason,
    bool showLoader = true,
  }) async {
    debugPrint('[LeaderboardPage] chargement classement démarré (reason=$reason)');
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<PlayerProfile> players =
          await _leaderboardService.fetchTopPlayers(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() {
        _players = players;
        _isLoading = false;
        _errorMessage = null;
      });
      debugPrint('[LeaderboardPage] classement reçu (${players.length} entrées)');
    } catch (error, stackTrace) {
      debugPrint('[LeaderboardPage] erreur classement: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _refresh() async {
    await _loadLeaderboard(reason: 'pull-to-refresh', showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFF004F2C),
      appBar: AppBar(
        title: const Text('Classement'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: <Widget>[
            PremiumPanel(
              child: Text(
                'Classement des joueurs connectés',
                style: textTheme.titleMedium?.copyWith(
                      color: PremiumColors.textDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            const _LeaderboardHeader(),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Impossible de charger le classement pour le moment.',
                        style: TextStyle(
                          color: PremiumColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: PremiumColors.textDark.withOpacity(0.78),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _loadLeaderboard(reason: 'retry-button'),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _errorMessage == null && _players.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Aucun joueur classé pour le moment.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ...List<Widget>.generate(_players.length, (int index) {
              final PlayerProfile player = _players[index];
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _LeaderboardRow(player: player, rank: index + 1),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 34),
          const SizedBox(width: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Joueur',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            'V/D',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 16),
          Text(
            'Score',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.player,
    required this.rank,
  });

  final PlayerProfile player;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final String safeDisplayName = player.displayName.trim().isEmpty
        ? 'Joueur inconnu'
        : player.effectivePseudo.trim();

    return PremiumPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 330;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: PremiumColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ProfileAvatar(player: player, size: 40, seedSalt: rank),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      safeDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PremiumColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Parties ${player.totalGames} • Crédit ${player.credits}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PremiumColors.textDark.withOpacity(0.78),
                        fontSize: 12,
                      ),
                    ),
                    if (compact) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'V ${player.wins} • D ${player.losses} • Score ${player.score}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PremiumColors.textDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '${player.wins}/${player.losses}',
                  style: const TextStyle(
                    color: PremiumColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${player.score}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: PremiumColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.player,
    required this.size,
    required this.seedSalt,
  });

  final PlayerProfile player;
  final double size;
  final int seedSalt;

  @override
  Widget build(BuildContext context) {
    return _generatedAvatar();
  }

  Widget _generatedAvatar() {
    return GameCardAvatar(
      size: size,
      data: GameCardAvatarPalette.fromSeed(
        player.id,
        salt: seedSalt,
      ),
    );
  }
}
