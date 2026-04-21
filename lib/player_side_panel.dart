import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                    const Text(
                      'Profil joueur',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text('Connectez-vous avec Google pour voir vos statistiques.'),
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text(
                  'Profil joueur',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: (profile.resolvedAvatarUrl == null ||
                              profile.resolvedAvatarUrl!.isEmpty)
                          ? null
                          : NetworkImage(profile.resolvedAvatarUrl!),
                      child: (profile.resolvedAvatarUrl == null ||
                              profile.resolvedAvatarUrl!.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if ((profile.email ?? '').isNotEmpty)
                            Text(
                              profile.email!,
                              style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Crédit: ${profile.credits}', style: const TextStyle(color: PremiumColors.textDark)),
                      Text('Victoires: ${profile.wins}', style: const TextStyle(color: PremiumColors.textDark)),
                      Text('Défaites: ${profile.losses}', style: const TextStyle(color: PremiumColors.textDark)),
                      Text('Parties: ${profile.totalGames}', style: const TextStyle(color: PremiumColors.textDark)),
                      Text('Score global: ${profile.score}', style: const TextStyle(color: PremiumColors.textDark)),
                      Text(
                        'Position classement: ${rank == null ? "-" : "#$rank"}',
                        style: const TextStyle(color: PremiumColors.textDark),
                      ),
                      if (profile.lastLoginAt != null)
                        Text(
                          'Dernière connexion: ${profile.lastLoginAt!.toLocal()}',
                          style: TextStyle(color: PremiumColors.textDark.withOpacity(0.75), fontSize: 12),
                        ),
                    ],
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

class PlayerSidePanelButton extends StatelessWidget {
  const PlayerSidePanelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: const Icon(Icons.account_circle_outlined, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
