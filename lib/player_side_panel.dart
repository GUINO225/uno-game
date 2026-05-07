import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'widgets/gino_popups.dart';

class PlayerSidePanel extends StatefulWidget {
  const PlayerSidePanel({
    super.key,
    this.onOpenLeaderboard,
    this.onOpenHistory,
    this.contextualGamePanel,
  });

  final VoidCallback? onOpenLeaderboard;
  final VoidCallback? onOpenHistory;
  final Widget? contextualGamePanel;

  @override
  State<PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends State<PlayerSidePanel> {
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  final LeaderboardService _leaderboardService = LeaderboardService.instance;
  Future<(PlayerProfile?, int?)>? _panelDataFuture;
  String? _panelDataUid;
  String? _promptedUid;
  String? _lastAuthUid;
  String? _justConnectedUid;

  Future<(PlayerProfile?, int?)> _loadPanelData() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return (null, null);
    }
    final PlayerProfile profile = await _profileService.createOrUpdateFromGoogleUser(user);
    int? rank;
    try {
      rank = await _leaderboardService.fetchPlayerRank(user.uid);
    } catch (e) {
      debugPrint('[PlayerSidePanel] rank unavailable for uid=${user.uid}: $e');
    }
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
    _refreshPanelData();
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (!mounted) {
        return;
      }
      _refreshPanelData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déconnexion réussie')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Déconnexion impossible: $e')),
      );
    }
  }

  void _refreshPanelData() {
    setState(() {
      _panelDataUid = null;
      _panelDataFuture = null;
    });
  }

  Future<(PlayerProfile?, int?)> _panelDataForCurrentUser() {
    final User? user = _authService.currentUser;
    final String? uid = user?.uid;
    if (_panelDataFuture != null && _panelDataUid == uid) {
      return _panelDataFuture!;
    }
    _panelDataUid = uid;
    _panelDataFuture = _loadPanelData();
    return _panelDataFuture!;
  }

  void _maybeSuggestProfileCustomization(PlayerProfile profile) {
    final User? user = _authService.currentUser;
    if (user == null) {
      return;
    }

    final bool shouldPrompt = _shouldPromptProfileCustomization(profile: profile, user: user);
    if (!shouldPrompt || _promptedUid == profile.uid) {
      return;
    }
    _promptedUid = profile.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final bool shouldEdit = await showDialog<bool>(
            barrierDismissible: true,
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                surfaceTintColor: Colors.transparent,
                backgroundColor: GinoPopupStyle.premiumDeepGreen.withOpacity(0.96),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: GinoPopupStyle.casinoGold.withOpacity(0.72)),
                ),
                shadowColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.28),
                title: Text(
                  'Personnalisez votre profil',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: GinoPopupStyle.textWhite,
                  ),
                ),
                content: Text(
                  'Pour garder votre anonymat, nous vous recommandons de changer votre pseudonyme et de choisir un avatar de carte. Vous pouvez le faire maintenant ou plus tard.',
                  style: GoogleFonts.poppins(
                    color: GinoPopupStyle.textWhite.withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: GinoPopupStyle.casinoGold,
                    ),
                    child: const Text('Plus tard'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.82),
                      foregroundColor: GinoPopupStyle.textWhite,
                      shadowColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Modifier maintenant'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!mounted) {
        return;
      }
      if (!shouldEdit) {
        await _profileService.dismissProfileCustomizationPrompt(uid: profile.uid);
        _refreshPanelData();
        return;
      }
      await _openProfileEditor(profile);
    });
  }

  bool _shouldPromptProfileCustomization({
    required PlayerProfile profile,
    required User user,
  }) {
    if (profile.hasCustomProfile) {
      return false;
    }
    final bool recentlyConnected = _justConnectedUid == profile.uid;
    if (recentlyConnected) {
      return true;
    }
    final bool hasDefaultIdentity = _looksLikeDefaultIdentity(profile, user);
    return hasDefaultIdentity;
  }

  bool _looksLikeDefaultIdentity(PlayerProfile profile, User user) {
    final String currentPublicName = _profileService.sanitizeDisplayName(
      profile.publicDisplayName,
      maxLength: 18,
    );
    if (currentPublicName.isEmpty) {
      return true;
    }
    final String googleName = _profileService.sanitizeDisplayName(
      user.displayName ?? '',
      maxLength: 18,
    );
    if (googleName.isNotEmpty && currentPublicName.toLowerCase() == googleName.toLowerCase()) {
      return true;
    }
    final String emailLocalPart = _profileService.sanitizeDisplayName(
      (user.email ?? '').split('@').first,
      maxLength: 18,
    );
    if (emailLocalPart.isNotEmpty &&
        currentPublicName.toLowerCase() == emailLocalPart.toLowerCase()) {
      return true;
    }
    return false;
  }

  Future<void> _openProfileEditor(PlayerProfile profile) async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return;
    }
    final bool? updated = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.38),
      builder: (BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: _PublicProfileEditorSheet(
          initialProfile: profile,
          onSave: (String displayName, String rank, String suit) async {
            await _profileService.updatePublicProfile(
              uid: user.uid,
              displayName: displayName,
              cardAvatarRank: rank,
              cardAvatarSuit: suit,
            );
          },
        ),
      ),
    );
    if (!mounted || updated != true) {
      return;
    }
    _refreshPanelData();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double mobileWidth = screenSize.width * 0.82;
    final double drawerWidth = screenSize.width >= 600
        ? mobileWidth.clamp(0, 410).toDouble()
        : mobileWidth.clamp(0, screenSize.width * 0.85).toDouble();

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
      ),
      child: SafeArea(
        left: false,
        child: StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
            final String? authUid = snapshot.data?.uid;
            if (_lastAuthUid != authUid) {
              _justConnectedUid = _lastAuthUid == null ? authUid : null;
              _lastAuthUid = authUid;
            }
            if (_panelDataUid != authUid) {
              _panelDataUid = authUid;
              _panelDataFuture = _loadPanelData();
            }
            return FutureBuilder<(PlayerProfile?, int?)>(
              future: _panelDataForCurrentUser(),
              builder:
                  (BuildContext context, AsyncSnapshot<(PlayerProfile?, int?)> snapshot) {
                final PlayerProfile? profile = snapshot.data?.$1;
                final int? rank = snapshot.data?.$2;
                if (profile != null) {
                  _maybeSuggestProfileCustomization(profile);
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ModernSideMenu(
                    child: Center(
                      child: CircularProgressIndicator(color: _SideMenuStyle.accentGreen),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return ModernSideMenu(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                      children: <Widget>[
                        const _SideMenuCloseRow(),
                        const SizedBox(height: 14),
                        const _SideMenuProfileHeader(),
                        const SizedBox(height: 18),
                        Text(
                          'Compte connecté, mais impossible de charger les données pour le moment.',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${snapshot.error}',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SideMenuActionButton(
                          label: 'Réessayer',
                          icon: Icons.refresh_rounded,
                          onPressed: _refreshPanelData,
                        ),
                      ],
                    ),
                  );
                }
                if (profile == null) {
                  return ModernSideMenu(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                      children: <Widget>[
                        const _SideMenuCloseRow(),
                        const SizedBox(height: 14),
                        const _SideMenuProfileHeader(),
                        if (widget.contextualGamePanel != null) ...<Widget>[
                          const SizedBox(height: 14),
                          widget.contextualGamePanel!,
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'Connectez-vous avec Google pour voir vos statistiques.',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SideMenuActionButton(
                          label: 'Connexion Google',
                          icon: Icons.g_mobiledata_rounded,
                          onPressed: _signIn,
                          primary: true,
                        ),
                        const SizedBox(height: 10),
                        _SideMenuActionButton(
                          label: 'Voir le classement',
                          icon: Icons.leaderboard_outlined,
                          onPressed: widget.onOpenLeaderboard,
                        ),
                        if (widget.onOpenHistory != null) ...<Widget>[
                          const SizedBox(height: 10),
                          _SideMenuActionButton(
                            label: 'Historique des parties',
                            icon: Icons.history_rounded,
                            onPressed: widget.onOpenHistory,
                          ),
                        ],
                      ],
                    ),
                  );
                }
                final List<_PlayerInfoTileData> accountTiles = <_PlayerInfoTileData>[
                  _PlayerInfoTileData(
                    icon: Icons.account_circle_outlined,
                    label: 'Pseudo',
                    value: _safeLabel(profile.publicDisplayName, fallback: 'Joueur'),
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
                  const _PlayerInfoTileData(
                    icon: Icons.verified_user_outlined,
                    label: 'Connexion',
                    value: 'Compte Google connecté',
                  ),
                ];
                return ModernSideMenu(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                    children: <Widget>[
                      const _SideMenuCloseRow(),
                      const SizedBox(height: 14),
                      _SideMenuProfileHeader(profile: profile),
                      if (widget.contextualGamePanel != null) ...<Widget>[
                        const SizedBox(height: 14),
                        widget.contextualGamePanel!,
                      ],
                      const SizedBox(height: 14),
                      _SideMenuStatsPanel(
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
                      const SizedBox(height: 12),
                      _SideMenuActionButton(
                        label: 'Modifier mon profil',
                        icon: Icons.edit_outlined,
                        onPressed: () => _openProfileEditor(profile),
                        primary: true,
                        trailingIcon: Icons.edit_outlined,
                      ),
                      const SizedBox(height: 10),
                      _SideMenuActionButton(
                        label: 'Voir le classement',
                        icon: Icons.leaderboard_outlined,
                        onPressed: widget.onOpenLeaderboard,
                      ),
                      if (widget.onOpenHistory != null) ...<Widget>[
                        const SizedBox(height: 10),
                        _SideMenuActionButton(
                          label: 'Historique des parties',
                          icon: Icons.history_rounded,
                          onPressed: widget.onOpenHistory,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _SideMenuActionButton(
                        label: 'Déconnexion',
                        icon: Icons.logout_rounded,
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SideMenuStyle {
  const _SideMenuStyle._();

  static const Color deepGreen = Color(0xEE04180F);
  static const Color accentGreen = Color(0xFF55F29A);
  static const Color softGreen = Color(0xFF0B6D3A);
}

class ModernSideMenu extends StatelessWidget {
  const ModernSideMenu({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _SideMenuStyle.deepGreen,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
            border: Border.all(color: _SideMenuStyle.accentGreen.withOpacity(0.34)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.26),
                blurRadius: 28,
                offset: const Offset(-10, 0),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned(
                top: 26,
                left: 18,
                child: _SideMenuDecorativeMark(
                  symbol: '♣',
                  size: 74,
                  angle: -0.16,
                ),
              ),
              const Positioned(
                top: 126,
                right: 16,
                child: _SideMenuDecorativeMark(
                  symbol: '♠',
                  size: 56,
                  angle: 0.18,
                ),
              ),
              const Positioned(
                bottom: 56,
                left: 22,
                child: _SideMenuDecorativeMark(
                  symbol: '♦',
                  size: 64,
                  angle: 0.14,
                ),
              ),
              Positioned(
                top: 210,
                left: -36,
                child: _BlurredCircle(size: 118, color: _SideMenuStyle.accentGreen),
              ),
              Positioned(
                bottom: 112,
                right: -44,
                child: _BlurredCircle(size: 136, color: _SideMenuStyle.softGreen),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SideMenuDecorativeMark extends StatelessWidget {
  const _SideMenuDecorativeMark({
    required this.symbol,
    required this.size,
    required this.angle,
  });

  final String symbol;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Text(
        symbol,
        style: GoogleFonts.poppins(
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: Colors.white.withOpacity(0.045),
          height: 1,
        ),
      ),
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  const _BlurredCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.08),
        ),
      ),
    );
  }
}

class _SideMenuCloseRow extends StatelessWidget {
  const _SideMenuCloseRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _SideMenuStyle.accentGreen.withOpacity(0.08),
              border: Border.all(color: _SideMenuStyle.accentGreen.withOpacity(0.34)),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _SideMenuProfileHeader extends StatelessWidget {
  const _SideMenuProfileHeader({this.profile});

  final PlayerProfile? profile;

  @override
  Widget build(BuildContext context) {
    final PlayerProfile? currentProfile = profile;
    final String? safeName = currentProfile == null
        ? null
        : _safeLabel(currentProfile.publicDisplayName, fallback: 'Joueur');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.075),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _SideMenuStyle.accentGreen.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          currentProfile == null
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _SideMenuStyle.accentGreen.withOpacity(0.12),
                    border: Border.all(color: _SideMenuStyle.accentGreen.withOpacity(0.36)),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                )
              : _PanelAvatar(profile: currentProfile, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Mon compte',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                if (safeName != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Connecte-toi pour sauvegarder ton profil et tes crédits.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.72),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideMenuStatsPanel extends StatelessWidget {
  const _SideMenuStatsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.065),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SideMenuStyle.accentGreen.withOpacity(0.22)),
      ),
      child: Column(children: children),
    );
  }
}

class _SideMenuActionButton extends StatelessWidget {
  const _SideMenuActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.trailingIcon = Icons.arrow_forward_ios_rounded,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final Color foreground = primary ? const Color(0xFF052016) : Colors.white;
    final Color background = primary
        ? _SideMenuStyle.accentGreen.withOpacity(onPressed == null ? 0.32 : 0.9)
        : Colors.white.withOpacity(onPressed == null ? 0.035 : 0.055);
    final Color border = primary
        ? _SideMenuStyle.accentGreen.withOpacity(0.72)
        : _SideMenuStyle.accentGreen.withOpacity(onPressed == null ? 0.14 : 0.34);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: foreground.withOpacity(onPressed == null ? 0.45 : 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: foreground.withOpacity(onPressed == null ? 0.45 : 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                trailingIcon,
                size: trailingIcon == Icons.arrow_forward_ios_rounded ? 15 : 18,
                color: foreground.withOpacity(onPressed == null ? 0.35 : 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _safeLabel(String? value, {required String fallback}) {
  final String cleaned = (value ?? '').trim();
  return cleaned.isEmpty ? fallback : cleaned;
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
        ? _SideMenuStyle.accentGreen.withOpacity(0.14)
        : Colors.white.withOpacity(0.06);

    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _SideMenuStyle.accentGreen.withOpacity(accent ? 0.32 : 0.14),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 220;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: Colors.white.withOpacity(0.78)),
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
                              color: Colors.white.withOpacity(0.68),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.94),
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
                                color: Colors.white.withOpacity(0.68),
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
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.94),
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
    return GameCardAvatar.fromSelection(
      size: size,
      rank: profile.selectedCardAvatar.rank,
      suit: profile.selectedCardAvatar.suit,
    );
  }
}

class _PublicProfileEditorSheet extends StatefulWidget {
  const _PublicProfileEditorSheet({
    required this.initialProfile,
    required this.onSave,
  });

  final PlayerProfile initialProfile;
  final Future<void> Function(String displayName, String rank, String suit) onSave;

  @override
  State<_PublicProfileEditorSheet> createState() => _PublicProfileEditorSheetState();
}

class _PublicProfileEditorSheetState extends State<_PublicProfileEditorSheet> {
  late final TextEditingController _displayNameController;
  late String _selectedRank;
  late String _selectedSuit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.initialProfile.publicDisplayName);
    _selectedRank = widget.initialProfile.selectedCardAvatar.rank;
    _selectedSuit = widget.initialProfile.selectedCardAvatar.suit;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _displayNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis ton pseudo.')),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await widget.onSave(name, _selectedRank, _selectedSuit);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible de mettre à jour le profil: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final EdgeInsets viewInsets = mediaQuery.viewInsets;
    final Size screenSize = mediaQuery.size;
    final double dialogWidth = (screenSize.width * 0.92).clamp(0, 520).toDouble();
    final double maxDialogHeight = screenSize.height - viewInsets.bottom - 32;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: maxDialogHeight < 320 ? screenSize.height * 0.88 : maxDialogHeight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xE60A2418),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF7CF7A9).withOpacity(0.28)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.32),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: const Color(0xFF44E57D).withOpacity(0.08),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Modifier mon profil',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFF2FFF5),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _saving ? null : () => Navigator.of(context).pop(false),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5CFF94).withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF7CF7A9).withOpacity(0.28),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFFE9FFF0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Pseudo public',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFDDFBE5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _displayNameController,
                        maxLength: 18,
                        cursorColor: const Color(0xFF7CF7A9),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFF4FFF6),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ton pseudo',
                          hintStyle: GoogleFonts.poppins(
                            color: const Color(0xFFF4FFF6).withOpacity(0.48),
                            fontWeight: FontWeight.w400,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF102F20).withOpacity(0.86),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: const Color(0xFF7CF7A9).withOpacity(0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: const Color(0xFF7CF7A9).withOpacity(0.42),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF74F29C), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Avatar carte',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFDDFBE5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102F20).withOpacity(0.72),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFF7CF7A9).withOpacity(0.34),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF65F794).withOpacity(0.23),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: GameCardAvatar.fromSelection(
                            rank: _selectedRank,
                            suit: _selectedSuit,
                            size: 72,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AvatarSelectorGrid<String>(
                        values: GameCardAvatarPalette.ranks,
                        selected: _selectedRank,
                        onSelected: (String rank) => setState(() => _selectedRank = rank),
                        labelBuilder: (String rank) => rank,
                      ),
                      const SizedBox(height: 12),
                      _AvatarSelectorGrid<String>(
                        values: GameCardAvatarPalette.suits,
                        selected: _selectedSuit,
                        onSelected: (String suit) => setState(() => _selectedSuit = suit),
                        labelBuilder: _suitLabel,
                        textColorBuilder: _suitColor,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: const Color(0xFFEFFFF3),
                                side: BorderSide(
                                  color: const Color(0xFF7CF7A9).withOpacity(0.68),
                                  width: 1.2,
                                ),
                                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _suitLabel(String suit) {
    return switch (suit) {
      'hearts' => '♥ cœur',
      'diamonds' => '♦ carreau',
      'spades' => '♠ pique',
      'clubs' => '♣ trèfle',
      _ => suit,
    };
  }

  static Color _suitColor(String suit) {
    return switch (suit) {
      'hearts' || 'diamonds' => const Color(0xFFFF7676),
      _ => const Color(0xFFEFFFF3),
    };
  }
}

class _AvatarSelectorGrid<T> extends StatelessWidget {
  const _AvatarSelectorGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    this.textColorBuilder,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T value) labelBuilder;
  final Color Function(T value)? textColorBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((T value) {
        final bool isSelected = value == selected;
        final Color baseTextColor = textColorBuilder?.call(value) ?? const Color(0xFFEFFFF3);
        return InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF0D2B1E).withOpacity(0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF89F7AD)
                    : const Color(0xFF7CF7A9).withOpacity(0.24),
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF55F58D).withOpacity(0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              labelBuilder(value),
              style: GoogleFonts.poppins(
                color: isSelected && textColorBuilder == null ? Colors.white : baseTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class PlayerSidePanelButton extends StatefulWidget {
  const PlayerSidePanelButton({
    super.key,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.only(top: 6, right: 10),
    this.wrapInAlign = true,
    this.showCredits = true,
    this.premiumSurface = false,
  });

  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final bool wrapInAlign;
  final bool showCredits;
  final bool premiumSurface;

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
    final Widget button = Padding(
      padding: widget.padding,
      child: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        initialData: _authService.currentUser,
        builder: (BuildContext context, AsyncSnapshot<User?> authSnapshot) {
          final User? user = authSnapshot.data;
          return FutureBuilder<PlayerProfile?>(
            future: _loadProfile(),
            builder: (BuildContext context, AsyncSnapshot<PlayerProfile?> snapshot) {
              final PlayerProfile? profile = snapshot.data;
              final GameCardAvatarData fallbackAvatar =
                  GameCardAvatarPalette.fromSeed(
                user?.uid ?? 'menu_guest',
                salt: 5,
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.showCredits && user != null) ...<Widget>[
                    _LiveCreditBadge(
                      uid: user.uid,
                      fallbackCredits: profile?.credits,
                      premiumSurface: widget.premiumSurface,
                    ),
                    const SizedBox(width: 6),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: widget.premiumSurface
                          ? Border.all(
                              color: const Color(0xFFE4B853)
                                  .withOpacity(0.36),
                              width: 1,
                            )
                          : null,
                      boxShadow: widget.premiumSurface
                          ? <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withOpacity(0.26),
                                blurRadius: 18,
                                offset: const Offset(0, 9),
                              ),
                              BoxShadow(
                                color: const Color(0xFF7CFF9B)
                                    .withOpacity(0.10),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Scaffold.of(context).openEndDrawer(),
                        child: Tooltip(
                          message: 'Menu joueur',
                          child: GameCardAvatar.fromSelection(
                            size: 52,
                            rank: profile?.selectedCardAvatar.rank ??
                                fallbackAvatar.rank,
                            suit: profile?.selectedCardAvatar.suit ??
                                fallbackAvatar.suit,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (!widget.wrapInAlign) {
      return button;
    }

    return Align(
      alignment: widget.alignment,
      child: button,
    );
  }
}

class _LiveCreditBadge extends StatelessWidget {
  const _LiveCreditBadge({
    required this.uid,
    this.fallbackCredits,
    this.premiumSurface = false,
  });

  final String uid;
  final int? fallbackCredits;
  final bool premiumSurface;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(uid)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data?.data();
        final int? liveCredits = (data?['credits'] as num?)?.toInt();
        final String creditsLabel = snapshot.connectionState == ConnectionState.waiting &&
                fallbackCredits == null
            ? '...'
            : '${liveCredits ?? fallbackCredits ?? 0}';
        return _CreditBadge(
          value: creditsLabel,
          premiumSurface: premiumSurface,
        );
      },
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.value, this.premiumSurface = false});

  final String value;
  final bool premiumSurface;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: premiumSurface
            ? const Color(0xFF031C12).withOpacity(0.70)
            : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: premiumSurface
              ? const Color(0xFFE4B853).withOpacity(0.42)
              : Colors.white.withOpacity(0.28),
          width: 1,
        ),
        boxShadow: premiumSurface
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF6BFF94).withOpacity(0.09),
                  blurRadius: 14,
                ),
              ]
            : null,
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
