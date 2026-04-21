import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'game_card_avatar.dart';
import 'leaderboard_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';
import 'user_profile_service.dart';

class _PanelRefreshBus extends ChangeNotifier {
  void requestRefresh(String reason) {
    _lastReason = reason;
    notifyListeners();
  }

  String _lastReason = 'unknown';
  String get lastReason => _lastReason;
}

final _PanelRefreshBus _panelRefreshBus = _PanelRefreshBus();

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
  late Future<PlayerProfile?> _profileFuture;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    _panelRefreshBus.addListener(_onRefreshRequested);
    _profileFuture = _loadProfile(reason: 'initState');
  }

  @override
  void dispose() {
    _panelRefreshBus.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    _refreshProfile(reason: _panelRefreshBus.lastReason);
  }

  Future<int?> _loadRank(String uid) async {
    return _leaderboardService.fetchPlayerRank(uid);
  }

  void _refreshProfile({required String reason}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _profileLoadError = null;
      _profileFuture = _loadProfile(reason: reason);
    });
  }

  Future<PlayerProfile?> _loadProfile({required String reason}) async {
    debugPrint('[MENU] chargement démarré (reason=$reason)');
    final User? user = _authService.currentUser;
    debugPrint('[AUTH] currentUser uid = ${user?.uid ?? 'null'}');
    if (user == null) {
      debugPrint('[MENU] aucun utilisateur authentifié');
      return null;
    }
    try {
      final PlayerProfile profile = await _profileService.createOrUpdateFromGoogleUser(user);
      debugPrint(
        '[MENU] document utilisateur reçu uid=${profile.uid} pseudo=${profile.effectivePseudo} credits=${profile.credits}',
      );
      return profile;
    } catch (error, stackTrace) {
      debugPrint(
        '[MENU] erreur $error\n$stackTrace',
      );
      try {
        final PlayerProfile? existingProfile = await _profileService.getProfile(user.uid);
        if (existingProfile != null) {
          debugPrint('[MENU] fallback profil local Firestore utilisé');
          return existingProfile;
        }
      } catch (fallbackError, fallbackStackTrace) {
        debugPrint('[MENU] erreur fallback profil $fallbackError\n$fallbackStackTrace');
      }
      _profileLoadError = '$error';
      return PlayerProfile(
        uid: user.uid,
        pseudo: _profileService.suggestedNameFromUser(user),
        displayName: _profileService.suggestedNameFromUser(user),
        email: user.email,
        photoUrl: user.photoURL,
        avatarUrl: user.photoURL,
      );
    }
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
    setState(() {
      _profileFuture = _loadProfile(reason: 'post-sign-in');
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _profileFuture = _loadProfile(reason: 'post-sign-out');
    });
  }

  Future<void> _promptPseudoEdition(PlayerProfile profile) async {
    final TextEditingController controller = TextEditingController(
      text: profile.effectivePseudo,
    );
    String? error;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Modifier le pseudo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    maxLength: UserProfileService.maxPseudoLength,
                    decoration: InputDecoration(
                      labelText: 'Pseudo',
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setDialogState(() => error = null);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String? validation =
                        _profileService.validatePseudo(controller.text);
                    if (validation != null) {
                      setDialogState(() => error = validation);
                      return;
                    }
                    await _profileService.updatePseudo(
                      uid: profile.uid,
                      pseudo: controller.text,
                    );
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pseudo mis à jour.')),
    );
    setState(() {
      _profileFuture = _loadProfile(reason: 'pseudo-updated');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: FutureBuilder<PlayerProfile?>(
          future: _profileFuture,
          builder: (BuildContext context, AsyncSnapshot<PlayerProfile?> snapshot) {
            final PlayerProfile? profile = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && profile == null) {
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
                    'Erreur de chargement du menu: ${snapshot.error}',
                    style: GoogleFonts.poppins(
                      color: PremiumColors.textDark.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _refreshProfile(reason: 'retry-error-state'),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              );
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
                  if (_profileLoadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Erreur: $_profileLoadError',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenLeaderboard,
                    icon: const Icon(Icons.leaderboard_outlined),
                    label: const Text('Voir le classement'),
                  ),
                ],
              );
            }
            return StreamBuilder<PlayerProfile?>(
              stream: _profileService.watchProfile(profile.uid),
              initialData: profile,
              builder: (BuildContext context, AsyncSnapshot<PlayerProfile?> profileSnapshot) {
                final PlayerProfile activeProfile = profileSnapshot.data ?? profile;
                final List<_PlayerInfoTileData> accountTiles = <_PlayerInfoTileData>[
                  _PlayerInfoTileData(
                    icon: Icons.account_circle_outlined,
                    label: 'Pseudo',
                    value: _safeLabel(activeProfile.effectivePseudo, fallback: 'Joueur'),
                  ),
                  _PlayerInfoTileData(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Crédit',
                    value: activeProfile.credits.toString(),
                    accent: true,
                  ),
                  _PlayerInfoTileData(
                    icon: Icons.emoji_events_outlined,
                    label: 'Victoires',
                    value: activeProfile.wins.toString(),
                  ),
                  _PlayerInfoTileData(
                    icon: Icons.cancel_outlined,
                    label: 'Défaites',
                    value: activeProfile.losses.toString(),
                  ),
                  _PlayerInfoTileData(
                    icon: Icons.sports_esports_outlined,
                    label: 'Parties',
                    value: activeProfile.totalGames.toString(),
                  ),
                ];
                if ((activeProfile.email ?? '').isNotEmpty) {
                  accountTiles.add(
                    _PlayerInfoTileData(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: _safeLabel(activeProfile.email, fallback: '-'),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                  children: <Widget>[
                    _AccountDrawerHeader(
                      profile: activeProfile,
                      onEditPseudo: () => _promptPseudoEdition(activeProfile),
                    ),
                const SizedBox(height: 14),
                PremiumPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: <Widget>[
                      ...List<Widget>.generate(accountTiles.length, (int index) {
                        final _PlayerInfoTileData tile = accountTiles[index];
                        return _PlayerInfoTile(
                          icon: tile.icon,
                          label: tile.label,
                          value: tile.value,
                          accent: tile.accent,
                          isLast: false,
                        );
                      }),
                      FutureBuilder<int?>(
                        future: _loadRank(activeProfile.uid),
                        builder: (BuildContext context, AsyncSnapshot<int?> rankSnapshot) {
                          final String rankLabel = rankSnapshot.connectionState == ConnectionState.waiting
                              ? '...'
                              : (rankSnapshot.data == null ? '-' : '#${rankSnapshot.data}');
                          return _PlayerInfoTile(
                            icon: Icons.leaderboard_outlined,
                            label: 'Classement',
                            value: rankLabel,
                            isLast: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _refreshProfile(reason: 'manual-reload-tap'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recharger le profil'),
                ),
                const SizedBox(height: 8),
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
  const _AccountDrawerHeader({
    required this.profile,
    required this.onEditPseudo,
  });

  final PlayerProfile profile;
  final VoidCallback onEditPseudo;

  @override
  Widget build(BuildContext context) {
    final String safeName = _safeLabel(profile.effectivePseudo, fallback: 'Joueur');
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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onEditPseudo,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Modifier le pseudo'),
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
    final String? avatarUrl = profile.resolvedAvatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 10),
        child: StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          initialData: _authService.currentUser,
          builder: (BuildContext context, AsyncSnapshot<User?> authSnapshot) {
            final User? user = authSnapshot.data;
            if (user == null) {
              return _PanelQuickActions(
                creditsLabel: '0',
                avatar: GameCardAvatar(
                  size: 28,
                  data: GameCardAvatarPalette.fromSeed('menu_guest', salt: 5),
                ),
              );
            }
            return StreamBuilder<PlayerProfile?>(
              stream: _profileService.watchProfile(user.uid),
              builder: (BuildContext context, AsyncSnapshot<PlayerProfile?> profileSnapshot) {
                final PlayerProfile? profile = profileSnapshot.data;
                final String creditsLabel = profile == null ? '...' : '${profile.credits}';
                final Widget avatar = _PanelAvatar(
                  profile: profile ??
                      PlayerProfile(
                        uid: user.uid,
                        pseudo: user.displayName ?? 'Joueur',
                        displayName: user.displayName ?? 'Joueur',
                        photoUrl: user.photoURL,
                        avatarUrl: user.photoURL,
                      ),
                  size: 28,
                );
                return _PanelQuickActions(
                  creditsLabel: creditsLabel,
                  avatar: avatar,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PanelQuickActions extends StatelessWidget {
  const _PanelQuickActions({
    required this.creditsLabel,
    required this.avatar,
  });

  final String creditsLabel;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CreditBadge(value: creditsLabel),
        const SizedBox(width: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _panelRefreshBus.requestRefresh('drawer-opened');
              Scaffold.of(context).openEndDrawer();
            },
            child: Tooltip(
              message: 'Menu joueur',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(child: avatar),
              ),
            ),
          ),
        ),
      ],
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
