import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'credit_coins_icon.dart';
import 'game_card_avatar.dart';
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
              return ListView(
                padding: const EdgeInsets.all(16),
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
              );
            }
            final List<_PlayerInfoTileData> accountTiles = <_PlayerInfoTileData>[
              _PlayerInfoTileData(
                icon: Icons.account_circle_outlined,
                label: 'Pseudo',
                value: _safeLabel(profile.displayName, fallback: 'Joueur'),
              ),
              _PlayerInfoTileData(
                icon: Icons.workspace_premium_rounded,
                label: 'Crédit',
                value: profile.credits.toString(),
                accent: true,
              ),
              _PlayerInfoTileData(
                icon: Icons.emoji_events_outlined,
                label: 'Victoires',
                value: profile.wins.toString(),
              ),
              _PlayerInfoTileData(
                icon: Icons.cancel_outlined,
                label: 'Défaites',
                value: profile.losses.toString(),
              ),
              _PlayerInfoTileData(
                icon: Icons.sports_esports_outlined,
                label: 'Parties',
                value: profile.totalGames.toString(),
              ),
              _PlayerInfoTileData(
                icon: Icons.leaderboard_outlined,
                label: 'Classement',
                value: rank == null ? '-' : '#$rank',
              ),
            ];
            if ((profile.email ?? '').isNotEmpty) {
              accountTiles.add(
                _PlayerInfoTileData(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: _safeLabel(profile.email, fallback: '-'),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              children: <Widget>[
                _AccountDrawerHeader(profile: profile),
                const SizedBox(height: 14),
                PremiumPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: List<Widget>.generate(accountTiles.length, (int index) {
                      final _PlayerInfoTileData tile = accountTiles[index];
                      return _PlayerInfoTile(
                        icon: tile.icon,
                        label: tile.label,
                        value: tile.value,
                        accent: tile.accent,
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

String _safeLabel(String? value, {required String fallback}) {
  final String cleaned = (value ?? '').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

class _AccountDrawerHeader extends StatelessWidget {
  const _AccountDrawerHeader({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final String safeName = _safeLabel(profile.displayName, fallback: 'Joueur');
    final String? safeEmail =
        (profile.email != null && profile.email!.trim().isNotEmpty)
            ? profile.email!.trim()
            : null;

    return PremiumPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          _PanelAvatar(profile: profile, size: 56),
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
                const SizedBox(height: 4),
                Text(
                  safeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: PremiumColors.textDark.withOpacity(0.92),
                  ),
                ),
                if (safeEmail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    safeEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PremiumColors.textDark.withOpacity(0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerInfoTileData {
  const _PlayerInfoTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;
}

class _PlayerInfoTile extends StatelessWidget {
  const _PlayerInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color tileColor = accent
        ? PremiumColors.accent.withOpacity(0.2)
        : Colors.white.withOpacity(0.7);

    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumColors.textDark.withOpacity(0.08)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 220;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: PremiumColors.textDark.withOpacity(0.82)),
              const SizedBox(width: 10),
              Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PremiumColors.textDark.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PremiumColors.textDark,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: <Widget>[
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
                              maxLines: 1,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanelAvatar extends StatelessWidget {
  const _PanelAvatar({
    required this.profile,
    required this.size,
  });

  final PlayerProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = profile.resolvedAvatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _generatedAvatar(),
        ),
      );
    }
    return _generatedAvatar();
  }

  Widget _generatedAvatar() {
    return GameCardAvatar(
      size: size,
      data: GameCardAvatarPalette.fromSeed(
        profile.id,
        salt: 2,
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

  Future<PlayerProfile?> _loadProfile() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return null;
    }
    return _profileService.createOrUpdateFromGoogleUser(user);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 10),
        child: FutureBuilder<PlayerProfile?>(
          future: _loadProfile(),
          builder: (BuildContext context, AsyncSnapshot<PlayerProfile?> snapshot) {
            final PlayerProfile? profile = snapshot.data;
            final String creditsLabel = snapshot.connectionState == ConnectionState.waiting
                ? '...'
                : '${profile?.credits ?? 0}';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _CreditBadge(value: creditsLabel),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: Tooltip(
                      message: 'Menu joueur',
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: GameCardAvatar(
                              size: 46,
                              data: GameCardAvatarPalette.fromSeed(
                                profile?.id ?? _authService.currentUser?.uid ?? 'menu_guest',
                                salt: 5,
                              ),
                            ),
                          ),
                        ),
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
            CreditCoinsIcon(
              size: 14,
              color: PremiumColors.accent.withOpacity(0.95),
            ),
            const SizedBox(width: 6),
            Text(
              'Crédit $value',
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
