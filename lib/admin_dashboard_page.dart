import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_dashboard_service.dart';
import 'app_logo.dart';
import 'auth_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';

class AdminDashboardGatePage extends StatelessWidget {
  const AdminDashboardGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.tableGreenDark,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withOpacity(0.09),
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<User?>(
              stream: AuthService.instance.authStateChanges,
              builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final User? user = snapshot.data;
                if (user == null) {
                  return _AdminSignInRequired(
                    onSignIn: () async {
                      final GoogleAuthResult result =
                          await AuthService.instance.signInWithGoogle();
                      if (!context.mounted || result.isSuccess) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.errorMessage ?? 'Connexion impossible.')),
                      );
                    },
                  );
                }

                return FutureBuilder<AdminAccessState>(
                  future: AdminDashboardService.instance.checkAdminAccess(user),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<AdminAccessState> accessSnapshot,
                  ) {
                    if (accessSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final AdminAccessState? state = accessSnapshot.data;
                    if (state == null || !state.isAllowed) {
                      return _AdminAccessDenied(
                        reason: state?.reason ?? 'Accès interdit.',
                      );
                    }

                    return AdminDashboardPage(adminUser: user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.adminUser});

  final User adminUser;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Retour jeu',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Column(
                    children: <Widget>[
                      AppLogo(size: 86),
                      SizedBox(height: 2),
                      Text(
                        'Admin dashboard',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Déconnecté de l\'espace admin.')),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher pseudo, email, identifiant',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: _buildPlayersTable(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTransactionsPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersTable() {
    return Card(
      color: Colors.white.withOpacity(0.95),
      child: StreamBuilder<List<PlayerProfile>>(
        stream: AdminDashboardService.instance.watchAllPlayers(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<PlayerProfile>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<PlayerProfile> allPlayers = snapshot.data ?? <PlayerProfile>[];
          final List<PlayerProfile> filteredPlayers = allPlayers.where((PlayerProfile player) {
            if (_query.isEmpty) {
              return true;
            }
            final String text =
                '${player.displayName} ${player.email ?? ''} ${player.uid}'.toLowerCase();
            return text.contains(_query);
          }).toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Joueurs (${filteredPlayers.length})',
                  style: const TextStyle(
                    color: PremiumColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Avatar')),
                        DataColumn(label: Text('Pseudo')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('UID')),
                        DataColumn(label: Text('Rôle')),
                        DataColumn(label: Text('Crédits')),
                        DataColumn(label: Text('Victoires')),
                        DataColumn(label: Text('Défaites')),
                        DataColumn(label: Text('Créé le')),
                        DataColumn(label: Text('Dernière activité')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: filteredPlayers.map((PlayerProfile player) {
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(CircleAvatar(
                              backgroundImage: player.resolvedAvatarUrl == null
                                  ? null
                                  : NetworkImage(player.resolvedAvatarUrl!),
                              child: player.resolvedAvatarUrl == null
                                  ? Text(player.displayName.isEmpty ? '?' : player.displayName[0])
                                  : null,
                            )),
                            DataCell(Text(player.displayName)),
                            DataCell(Text(player.email ?? '-')),
                            DataCell(SelectableText(player.uid)),
                            DataCell(Text(player.role)),
                            DataCell(Text('${player.credits}')),
                            DataCell(Text('${player.wins}')),
                            DataCell(Text('${player.losses}')),
                            DataCell(Text(_formatDate(player.createdAt))),
                            DataCell(Text(_formatDate(player.lastLoginAt))),
                            DataCell(
                              ElevatedButton(
                                onPressed: () => _openCreditDialog(player),
                                child: const Text('Envoyer'),
                              ),
                            ),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionsPanel() {
    return Card(
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Historique admin',
              style: TextStyle(
                color: PremiumColors.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<AdminTransactionRecord>>(
                stream: AdminDashboardService.instance.watchTransactions(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<AdminTransactionRecord>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<AdminTransactionRecord> transactions =
                      snapshot.data ?? <AdminTransactionRecord>[];
                  if (transactions.isEmpty) {
                    return const Center(child: Text('Aucune opération admin.'));
                  }
                  return ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final AdminTransactionRecord tx = transactions[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${tx.targetPseudo} • +${tx.amount} crédits',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text('UID: ${tx.targetUserId}'),
                            Text('Admin: ${tx.adminEmail.isEmpty ? tx.adminId : tx.adminEmail}'),
                            Text('Type: ${tx.operationType}'),
                            Text('Date: ${_formatDate(tx.createdAt, withTime: true)}'),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreditDialog(PlayerProfile player) async {
    final TextEditingController amountController = TextEditingController();
    String? validationMessage;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Envoyer des crédits à ${player.displayName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      hintText: 'Ex: 250',
                    ),
                    onChanged: (_) {
                      setDialogState(() {
                        validationMessage = null;
                      });
                    },
                  ),
                  if (validationMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      validationMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final int? amount = int.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      setDialogState(() {
                        validationMessage = 'Veuillez saisir un montant entier positif.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final int amount = int.parse(amountController.text.trim());
    try {
      await AdminDashboardService.instance.addCreditsToPlayer(
        adminUser: widget.adminUser,
        targetUserId: player.uid,
        amount: amount,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Crédits envoyés avec succès (+$amount).')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi: $e')),
      );
    }
  }

  String _formatDate(DateTime? value, {bool withTime = false}) {
    if (value == null) {
      return '-';
    }
    final DateFormat formatter =
        withTime ? DateFormat('yyyy-MM-dd HH:mm') : DateFormat('yyyy-MM-dd');
    return formatter.format(value.toLocal());
  }
}

class _AdminSignInRequired extends StatelessWidget {
  const _AdminSignInRequired({required this.onSignIn});

  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        color: Colors.white.withOpacity(0.92),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Accès administrateur',
                style: TextStyle(
                  color: PremiumColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connectez-vous avec un compte administrateur autorisé.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Connexion admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        color: Colors.white.withOpacity(0.92),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline_rounded, size: 42, color: PremiumColors.textDark),
              const SizedBox(height: 8),
              const Text(
                'Accès refusé',
                style: TextStyle(
                  color: PremiumColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
