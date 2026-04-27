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
  Future<(PlayerProfile?, int?)>? _panelDataFuture;
  String? _panelDataUid;
  String? _promptedUid;

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
    await _authService.signOut();
    if (!mounted) {
      return;
    }
    _refreshPanelData();
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
    if (profile.hasCustomProfile) {
      return;
    }
    if (_promptedUid == profile.uid) {
      return;
    }
    _promptedUid = profile.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final bool shouldEdit = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Personnalise ton profil'),
                content: const Text(
                  'Choisis un pseudo et un avatar de carte pour rester discret dans le classement.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Plus tard'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Modifier maintenant'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!mounted || !shouldEdit) {
        return;
      }
      await _openProfileEditor(profile);
    });
  }

  Future<void> _openProfileEditor(PlayerProfile profile) async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return;
    }
    final bool? updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _PublicProfileEditorSheet(
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
    return Drawer(
      child: SafeArea(
        child: StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
            final String? authUid = snapshot.data?.uid;
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
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
                        'Compte connecté, mais impossible de charger les données pour le moment.',
                        style: GoogleFonts.poppins(
                          color: PremiumColors.textDark.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${snapshot.error}',
                        style: GoogleFonts.poppins(
                          color: PremiumColors.textDark.withOpacity(0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refreshPanelData,
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
                    ElevatedButton.icon(
                      onPressed: () => _openProfileEditor(profile),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier mon profil'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenLeaderboard,
                      icon: const Icon(Icons.leaderboard_outlined),
                      label: const Text('Voir le classement'),
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
  const _AccountDrawerHeader({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final String safeName = _safeLabel(profile.publicDisplayName, fallback: 'Joueur');

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
                    fontWeight: FontWeight.w700,
                    color: PremiumColors.textDark.withOpacity(0.92),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compte Google connecté',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: PremiumColors.textDark.withOpacity(0.72),
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
    final Color tileColor =
        accent ? PremiumColors.accent.withOpacity(0.2) : Colors.white.withOpacity(0.7);

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
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A4A2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4EC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1B8B4A), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Modifier mon profil',
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: PremiumColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pseudo public',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: PremiumColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _displayNameController,
                      maxLength: 18,
                      style: GoogleFonts.poppins(
                        color: PremiumColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ton pseudo',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2D8D55)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2D8D55)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0B6D3A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Avatar carte',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: PremiumColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8EF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFB9DDBE)),
                        ),
                        child: GameCardAvatar.fromSelection(
                          rank: _selectedRank,
                          suit: _selectedSuit,
                          size: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AvatarSelectorGrid<String>(
                      values: GameCardAvatarPalette.ranks,
                      selected: _selectedRank,
                      onSelected: (String rank) => setState(() => _selectedRank = rank),
                      labelBuilder: (String rank) => rank,
                    ),
                    const SizedBox(height: 10),
                    _AvatarSelectorGrid<String>(
                      values: GameCardAvatarPalette.suits,
                      selected: _selectedSuit,
                      onSelected: (String suit) => setState(() => _selectedSuit = suit),
                      labelBuilder: _suitLabel,
                      textColorBuilder: _suitColor,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0B6D3A),
                              side: const BorderSide(color: Color(0xFF0B6D3A), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B6D3A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
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
      'hearts' || 'diamonds' => const Color(0xFFD32F2F),
      _ => const Color(0xFF151515),
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
        return ChoiceChip(
          label: Text(
            labelBuilder(value),
            style: TextStyle(
              color: textColorBuilder?.call(value) ?? const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
            ),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFFE7F6EA),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? const Color(0xFF0B6D3A) : const Color(0xFFD6D6D6),
            width: isSelected ? 1.8 : 1,
          ),
          showCheckmark: false,
          onSelected: (_) => onSelected(value),
        );
      }).toList(growable: false),
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
            return StreamBuilder<User?>(
              stream: _authService.authStateChanges,
              builder: (BuildContext context, AsyncSnapshot<User?> _) {
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
                          child: GameCardAvatar.fromSelection(
                            size: 52,
                            rank: profile?.selectedCardAvatar.rank ??
                                GameCardAvatarPalette.fromSeed(
                                  _authService.currentUser?.uid ?? 'menu_guest',
                                  salt: 5,
                                ).rank,
                            suit: profile?.selectedCardAvatar.suit ??
                                GameCardAvatarPalette.fromSeed(
                                  _authService.currentUser?.uid ?? 'menu_guest',
                                  salt: 5,
                                ).suit,
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
