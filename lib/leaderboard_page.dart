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
  late Future<List<PlayerProfile>> _leaderboardFuture;

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

  Future<List<PlayerProfile>> _loadLeaderboardData() async {
    return _leaderboardService.fetchTopPlayers(limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: PremiumColors.tableGreenDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        titleSpacing: 4,
        title: const Text(
          'Classement',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _LeaderboardBackground(
        child: SafeArea(
          child: FutureBuilder<List<PlayerProfile>>(
            future: _leaderboardFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<PlayerProfile>> snapshot,
            ) {
              final List<PlayerProfile> players =
                  snapshot.data ?? const <PlayerProfile>[];
              return RefreshIndicator(
                onRefresh: _refresh,
                color: PremiumColors.accentGreen,
                backgroundColor: PremiumColors.tableGreenDark,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double horizontalPadding =
                        constraints.maxWidth >= 720 ? 24 : 16;
                    final List<Widget> leaderboardItems = <Widget>[
                      const SizedBox(height: 4),
                      const _LeaderboardHeader(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (snapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Impossible de charger le classement pour le moment.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (players.isEmpty &&
                          snapshot.connectionState == ConnectionState.done)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Aucun joueur classé pour le moment.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            isCurrentUser:
                                currentUid != null && player.uid == currentUid,
                          ),
                        );
                      }),
                      const _LeaderboardFooter(),
                    ];
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        kToolbarHeight + 12,
                        horizontalPadding,
                        24,
                      ),
                      itemCount: leaderboardItems.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: leaderboardItems[index],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LeaderboardSidePanel extends StatefulWidget {
  const LeaderboardSidePanel({super.key, this.limit = 20});

  final int limit;

  @override
  State<LeaderboardSidePanel> createState() => _LeaderboardSidePanelState();
}

class _LeaderboardSidePanelState extends State<LeaderboardSidePanel> {
  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  late Future<List<PlayerProfile>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _leaderboardService.fetchTopPlayers(limit: widget.limit);
  }

  @override
  void didUpdateWidget(covariant LeaderboardSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.limit != widget.limit) {
      _leaderboardFuture = _leaderboardService.fetchTopPlayers(limit: widget.limit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    return _LeaderboardBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: DecoratedBox(
            decoration: PremiumGameDecorations.glassPanel(
              radius: 24,
              opacity: 0.72,
              borderColor: PremiumColors.accentGreen.withOpacity(0.22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FutureBuilder<List<PlayerProfile>>(
                future: _leaderboardFuture,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<PlayerProfile>> snapshot,
                ) {
                  final List<PlayerProfile> players =
                      snapshot.data ?? const <PlayerProfile>[];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.leaderboard_rounded,
                            color: PremiumColors.accent.withOpacity(0.92),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Classement',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _LeaderboardHeader(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (snapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Classement indisponible.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (players.isEmpty &&
                          snapshot.connectionState == ConnectionState.done)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Aucun joueur classé.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            isCurrentUser:
                                currentUid != null && player.uid == currentUid,
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _LeaderboardBackground extends StatelessWidget {
  const _LeaderboardBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0D5C3A),
            PremiumColors.tableGreenDark,
            Color(0xFF022819),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -90,
            left: -80,
            child: _LeaderboardGlow(size: 260, opacity: 0.13),
          ),
          const Positioned(
            right: -110,
            bottom: -130,
            child: _LeaderboardGlow(size: 310, opacity: 0.1),
          ),
          Positioned(
            top: 86,
            left: -30,
            child: _CardSuitMark(symbol: '♠', size: 142, opacity: 0.045),
          ),
          Positioned(
            top: 176,
            right: 18,
            child: _CardSuitMark(symbol: '♥', size: 96, opacity: 0.035),
          ),
          Positioned(
            left: 28,
            bottom: 118,
            child: _CardSuitMark(symbol: '♦', size: 88, opacity: 0.032),
          ),
          Positioned(
            right: 20,
            bottom: 30,
            child: _CardSuitMark(symbol: '♣', size: 128, opacity: 0.042),
          ),
          child,
        ],
      ),
    );
  }
}

class _LeaderboardGlow extends StatelessWidget {
  const _LeaderboardGlow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _CardSuitMark extends StatelessWidget {
  const _CardSuitMark({
    required this.symbol,
    required this.size,
    required this.opacity,
  });

  final String symbol;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: size,
          color: Colors.white.withOpacity(opacity),
          height: 1,
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader();

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(
          color: Colors.white.withOpacity(0.84),
          fontWeight: FontWeight.w500,
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumColors.accentGreen.withOpacity(0.14)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 36),
          const SizedBox(width: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.78),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Joueurs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              'V/D',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              'Score',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
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
    final bool isFirst = rank == 1;
    final Color borderColor = isFirst
        ? PremiumColors.accent.withOpacity(0.72)
        : PremiumColors.accentGreen.withOpacity(isCurrentUser ? 0.56 : 0.24);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isFirst ? PremiumColors.accent : Colors.black)
                .withOpacity(isFirst ? 0.16 : 0.14),
            blurRadius: isFirst ? 24 : 14,
            spreadRadius: isFirst ? 1 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF063420).withOpacity(isFirst ? 0.82 : 0.68),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isFirst ? 1.3 : 1),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 360;
            final double rankWidth = compact ? 30 : 36;
            final double avatarSize = compact ? 36 : 40;
            final double metricWidth = compact ? 38 : 48;
            final double scoreWidth = compact ? 42 : 52;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(width: rankWidth, child: _RankBadge(rank: rank)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: GameCardAvatar.fromSelection(
                    size: avatarSize,
                    rank: player.selectedCardAvatar.rank,
                    suit: player.selectedCardAvatar.suit,
                  ),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: PremiumColors.accentGreen.withOpacity(0.24),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: PremiumColors.accentGreen.withOpacity(0.42),
                                ),
                              ),
                              child: const Text(
                                'Vous',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
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
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: metricWidth,
                  child: Text(
                    '${player.wins}/${player.losses}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: scoreWidth,
                  child: Text(
                    '${player.score}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _scoreColor(player.score),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score > 0) {
      return PremiumColors.accentGreen;
    }
    if (score < 0) {
      return const Color(0xFFFF9A6C);
    }
    return Colors.white.withOpacity(0.74);
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final Color? medalColor = switch (rank) {
      1 => PremiumColors.accent,
      2 => const Color(0xFFC9D1D9),
      3 => const Color(0xFFC9864A),
      _ => null,
    };

    if (medalColor == null) {
      return Text(
        '#$rank',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: PremiumColors.accentGreen,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: medalColor.withOpacity(0.2),
          border: Border.all(color: medalColor.withOpacity(0.78)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: medalColor.withOpacity(rank == 1 ? 0.26 : 0.14),
              blurRadius: rank == 1 ? 14 : 8,
            ),
          ],
        ),
        child: Text(
          '#$rank',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: medalColor,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardFooter extends StatelessWidget {
  const _LeaderboardFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        'Le classement est mis à jour en temps réel.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.58),
          fontSize: 12,
        ),
      ),
    );
  }
}
