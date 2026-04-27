import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'game_card_avatar.dart';
import 'leaderboard_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  late Future<({List<PlayerProfile> players, int? usersCount, int? currentUserRank})>
      _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _loadLeaderboardData();
  }

  Future<void> _refresh() async {
    setState(() {
      _leaderboardFuture = _loadLeaderboardData();
    });
    await _leaderboardFuture;
  }

  Future<({List<PlayerProfile> players, int? usersCount, int? currentUserRank})>
      _loadLeaderboardData() async {
    final List<PlayerProfile> players = await _leaderboardService.fetchTopPlayers(limit: 100);
    final int? usersCount = await _leaderboardService.fetchRegisteredUsersCount();
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    int? currentUserRank;
    if (currentUid != null) {
      currentUserRank = await _leaderboardService.fetchPlayerRank(currentUid);
    }
    return (players: players, usersCount: usersCount, currentUserRank: currentUserRank);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF004F2C),
      appBar: AppBar(
        title: const Text('Classement'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<({List<PlayerProfile> players, int? usersCount, int? currentUserRank})>(
        future: _leaderboardFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<({List<PlayerProfile> players, int? usersCount, int? currentUserRank})>
              snapshot,
        ) {
          final List<PlayerProfile> players = snapshot.data?.players ?? const <PlayerProfile>[];
          final int? usersCount = snapshot.data?.usersCount;
          final int? currentUserRank = snapshot.data?.currentUserRank;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: <Widget>[
                PremiumPanel(
                  child: Text(
                    usersCount == null
                        ? 'Classement des joueurs connectés'
                        : 'Classement des joueurs connectés ($usersCount)',
                    style: textTheme.titleMedium?.copyWith(
                      color: PremiumColors.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PremiumPanel(
                  child: Text(
                    currentUserRank == null
                        ? 'Votre rang : vous n\'êtes pas encore classé. Jouez en mode pari pour entrer dans le classement.'
                        : 'Votre rang : #$currentUserRank',
                    style: textTheme.bodyMedium?.copyWith(
                      color: PremiumColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _LeaderboardHeader(),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(minHeight: 2),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Impossible de charger le classement pour le moment.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (players.isEmpty && snapshot.connectionState == ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Aucun joueur classé pour le moment.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ...List<Widget>.generate(players.length, (int index) {
                  final PlayerProfile player = players[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _LeaderboardRow(
                      player: player,
                      rank: index + 1,
                      isCurrentUser: currentUid != null && player.uid == currentUid,
                    ),
                  );
                }),
              ],
            ),
          );
        },
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
    required this.isCurrentUser,
  });

  final PlayerProfile player;
  final int rank;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: isCurrentUser ? Border.all(color: const Color(0xFF0B6D3A), width: 2) : null,
      ),
      child: PremiumPanel(
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
                GameCardAvatar.fromSelection(
                  size: 40,
                  rank: player.selectedCardAvatar.rank,
                  suit: player.selectedCardAvatar.suit,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              player.publicDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PremiumColors.textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B6D3A),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Vous',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
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
      ),
    );
  }
}
