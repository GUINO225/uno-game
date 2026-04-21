import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'leaderboard_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';
import 'user_profile_service.dart';

class PlayerSidePanel extends StatefulWidget {
  const PlayerSidePanel({
    super.key,
    this.onOpenLeaderboard,
  });

  final VoidCallback? onOpenLeaderboard;

  @override
  State<PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends State<PlayerSidePanel> {
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  final LeaderboardService _leaderboardService = LeaderboardService.instance;

  Future<(PlayerProfile?, int?)> _loadPanelData() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return (null, null);
    }
    final PlayerProfile profile = await _profileService.createOrUpdateFromGoogleUser(user);
    final int? rank = await _leaderboardService.fetchPlayerRank(user.uid);
    return (profile, rank);
  }

  Future<void> _signIn() async {
    final GoogleAuthResult result = await _authService.signInWithGoogle();
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Connexion Google impossible.')),
      );
      return;
    }
    setState(() {});
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: FutureBuilder<(PlayerProfile?, int?)>(
          future: _loadPanelData(),
          builder: (BuildContext context, AsyncSnapshot<(PlayerProfile?, int?)> snapshot) {
            final PlayerProfile? profile = snapshot.data?.$1;
            final int? rank = snapshot.data?.$2;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (profile == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Mon compte',
                      style: GoogleFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: PremiumColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connectez-vous avec Google pour voir vos statistiques.',
                      style: GoogleFonts.poppins(
                        color: PremiumColors.textDark.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _signIn,
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text('Connexion Google'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenLeaderboard,
                      icon: const Icon(Icons.leaderboard_outlined),
                      label: const Text('Voir le classement'),
                    ),
                  ],
                ),
              );
            }
            final List<_AccountInfoTile> accountTiles = <_AccountInfoTile>[
              _AccountInfoTile(
                icon: Icons.account_circle_outlined,
                label: 'Pseudo',
                value: profile.displayName,
              ),
              _AccountInfoTile(
                icon: Icons.workspace_premium_rounded,
                label: 'Crédit',
                value: profile.credits.toString(),
              ),
              _AccountInfoTile(
                icon: Icons.emoji_events_outlined,
                label: 'Victoires',
                value: profile.wins.toString(),
              ),
              _AccountInfoTile(
                icon: Icons.cancel_outlined,
                label: 'Défaites',
                value: profile.losses.toString(),
              ),
              _AccountInfoTile(
                icon: Icons.sports_esports_outlined,
                label: 'Parties',
                value: profile.totalGames.toString(),
              ),
              _AccountInfoTile(
                icon: Icons.leaderboard_outlined,
                label: 'Classement',
                value: rank == null ? '-' : '#$rank',
              ),
            ];
            if ((profile.email ?? '').isNotEmpty) {
              accountTiles.add(
                _AccountInfoTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: profile.email!,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              children: <Widget>[
                PremiumPanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: PremiumColors.panelSoft,
                        backgroundImage: (profile.resolvedAvatarUrl == null ||
                                profile.resolvedAvatarUrl!.isEmpty)
                            ? null
                            : NetworkImage(profile.resolvedAvatarUrl!),
                        child: (profile.resolvedAvatarUrl == null || profile.resolvedAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person_rounded, color: PremiumColors.textDark)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Mon compte',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: PremiumColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.displayName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: PremiumColors.textDark.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: List<Widget>.generate(accountTiles.length, (int index) {
                      return _AccountInfoTile(
                        icon: accountTiles[index].icon,
                        label: accountTiles[index].label,
                        value: accountTiles[index].value,
                        isLast: index == accountTiles.length - 1,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onOpenLeaderboard,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Page Classement'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Déconnexion'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountInfoTile extends StatelessWidget {
  const _AccountInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumColors.textDark.withOpacity(0.08)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: PremiumColors.textDark.withOpacity(0.82)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PremiumColors.textDark.withOpacity(0.75),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PremiumColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSidePanelButton extends StatefulWidget {
  const PlayerSidePanelButton({super.key});

  @override
  State<PlayerSidePanelButton> createState() => _PlayerSidePanelButtonState();
}

class _PlayerSidePanelButtonState extends State<PlayerSidePanelButton> {
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;

  Future<int?> _loadCredits() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return null;
    }
    final PlayerProfile profile = await _profileService.createOrUpdateFromGoogleUser(user);
    return profile.credits;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 10),
        child: FutureBuilder<int?>(
          future: _loadCredits(),
          builder: (BuildContext context, AsyncSnapshot<int?> snapshot) {
            final String creditsLabel = snapshot.connectionState == ConnectionState.waiting
                ? '...'
                : '${snapshot.data ?? 0}';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _CreditBadge(value: creditsLabel),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.32)),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.monetization_on_outlined,
              size: 17,
              color: PremiumColors.accent.withOpacity(0.95),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
