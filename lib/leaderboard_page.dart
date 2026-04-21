import 'package:flutter/material.dart';

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
  late Future<List<PlayerProfile>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _leaderboardService.fetchTopPlayers(limit: 100);
  }

  Future<void> _refresh() async {
    setState(() {
      _leaderboardFuture = _leaderboardService.fetchTopPlayers(limit: 100);
    });
    await _leaderboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004F2C),
      appBar: AppBar(
        title: const Text('Classement'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<PlayerProfile>>(
          future: _leaderboardFuture,
          builder: (BuildContext context, AsyncSnapshot<List<PlayerProfile>> snapshot) {
            final List<PlayerProfile> players = snapshot.data ?? const <PlayerProfile>[];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: <Widget>[
                  PremiumPanel(
                    child: Text(
                      'Classement des joueurs connectés',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: PremiumColors.textDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      child: PremiumPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 34,
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: PremiumColors.textDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: (player.resolvedAvatarUrl == null ||
                                      player.resolvedAvatarUrl!.isEmpty)
                                  ? null
                                  : NetworkImage(player.resolvedAvatarUrl!),
                              child: (player.resolvedAvatarUrl == null ||
                                      player.resolvedAvatarUrl!.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    player.displayName,
                                    style: const TextStyle(
                                      color: PremiumColors.textDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Score ${player.score} • V ${player.wins} • D ${player.losses}',
                                    style: const TextStyle(color: PremiumColors.textDark),
                                  ),
                                  Text(
                                    'Crédit ${player.credits} • Parties ${player.totalGames}',
                                    style: TextStyle(
                                      color: PremiumColors.textDark.withOpacity(0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
