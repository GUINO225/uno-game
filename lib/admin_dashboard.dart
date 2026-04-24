import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/gino_popups.dart';

class AdminAccessConfig {
  static const String login = 'GINO';
  static const String password = 'GINO89';
}

class LoginAdminPage extends StatefulWidget {
  const LoginAdminPage({super.key});

  @override
  State<LoginAdminPage> createState() => _LoginAdminPageState();
}

class _LoginAdminPageState extends State<LoginAdminPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final String login = _loginController.text.trim();
    final String password = _passwordController.text.trim();
    if (login == AdminAccessConfig.login && password == AdminAccessConfig.password) {
      Navigator.of(context).pushReplacementNamed('/admin-dashboard');
      return;
    }
    setState(() {
      _error = 'Accès refusé.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinoPopupStyle.screenGreen,
      body: Stack(
        children: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GinoPopupFrame(
                titleTag: 'Admin',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: _loginController,
                      style: GinoPopupStyle.baseText(fontSize: 16),
                      decoration: _inputDecoration('Login'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: GinoPopupStyle.baseText(fontSize: 16),
                      decoration: _inputDecoration('Mot de passe'),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: GinoPopupStyle.baseText(
                          color: const Color(0xFFFFD0D0),
                          fontSize: 13,
                          fontWeight: GinoPopupStyle.titleWeight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: GinoPopupButton(
                            label: 'Retour',
                            onPressed: () => Navigator.of(context).pop(),
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GinoPopupButton(label: 'Connexion', onPressed: _submit),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GinoPopupStyle.baseText(fontSize: 14, color: Colors.white70),
      filled: true,
      fillColor: GinoPopupStyle.screenGreen.withOpacity(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GinoPopupStyle.borderGreen),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GinoPopupStyle.borderGreen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GinoPopupStyle.accentGreen),
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _profiles =
      _db.collection('user_profiles');

  Future<void> _changeCredit({
    required BuildContext context,
    required String uid,
    required bool add,
  }) async {
    String amountInput = '';
    final int? amount = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoPopupFrame(
            titleTag: add ? '+ Crédit' : '- Crédit',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (String value) => amountInput = value,
                  style: GinoPopupStyle.baseText(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Montant',
                    hintStyle: GinoPopupStyle.baseText(fontSize: 14, color: Colors.white70),
                    filled: true,
                    fillColor: GinoPopupStyle.screenGreen.withOpacity(0.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GinoPopupStyle.borderGreen),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GinoPopupStyle.borderGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: GinoPopupStyle.accentGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GinoPopupButton(
                        label: 'Annuler',
                        isPrimary: false,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GinoPopupButton(
                        label: 'Valider',
                        onPressed: () {
                          final int? parsed = int.tryParse(amountInput.trim());
                          if (parsed == null || parsed <= 0) {
                            return;
                          }
                          FocusScope.of(dialogContext).unfocus();
                          Navigator.of(dialogContext).pop(parsed);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (amount == null || amount <= 0) {
      return;
    }
    if (add) {
      await adminAddCredit(uid: uid, amount: amount);
    } else {
      await adminRemoveCredit(uid: uid, amount: amount);
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(add ? 'Crédit ajouté.' : 'Crédit retiré.')),
    );
  }

  Future<void> adminAddCredit({required String uid, required int amount}) async {
    if (amount <= 0) {
      throw StateError('Montant invalide.');
    }
    final DocumentReference<Map<String, dynamic>> userRef = _profiles.doc(uid);
    final DocumentReference<Map<String, dynamic>> logRef = _db.collection('credit_logs').doc();
    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(userRef);
      if (!snap.exists) {
        throw StateError('Joueur introuvable.');
      }
      final int oldCredit = (snap.data()?['credits'] as num?)?.toInt() ?? 0;
      final int newCredit = oldCredit + amount;
      tx.update(userRef, <String, dynamic>{
        'credits': newCredit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(logRef, <String, dynamic>{
        'uid': uid,
        'type': 'add',
        'amount': amount,
        'oldCredit': oldCredit,
        'newCredit': newCredit,
        'reason': 'admin_dashboard',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> adminRemoveCredit({required String uid, required int amount}) async {
    if (amount <= 0) {
      throw StateError('Montant invalide.');
    }
    final DocumentReference<Map<String, dynamic>> userRef = _profiles.doc(uid);
    final DocumentReference<Map<String, dynamic>> logRef = _db.collection('credit_logs').doc();
    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(userRef);
      if (!snap.exists) {
        throw StateError('Joueur introuvable.');
      }
      final int oldCredit = (snap.data()?['credits'] as num?)?.toInt() ?? 0;
      final int newCredit = (oldCredit - amount).clamp(0, 1 << 31).toInt();
      tx.update(userRef, <String, dynamic>{
        'credits': newCredit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(logRef, <String, dynamic>{
        'uid': uid,
        'type': 'remove',
        'amount': amount,
        'oldCredit': oldCredit,
        'newCredit': newCredit,
        'reason': 'admin_dashboard',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinoPopupStyle.screenGreen,
      appBar: AppBar(
        backgroundColor: GinoPopupStyle.popupGreen,
        foregroundColor: GinoPopupStyle.textWhite,
        title: Text('Dashboard admin', style: GinoPopupStyle.baseText(fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _profiles.orderBy('wins', descending: true).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snapshot.data!.docs;
          int totalCredits = 0;
          int totalGames = 0;
          String bestPlayer = '-';
          int bestWins = -1;
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
            final Map<String, dynamic> data = doc.data();
            totalCredits += (data['credits'] as num?)?.toInt() ?? 0;
            totalGames += (data['totalGames'] as num?)?.toInt() ?? 0;
            final int wins = (data['wins'] as num?)?.toInt() ?? 0;
            if (wins > bestWins) {
              bestWins = wins;
              bestPlayer = (data['displayName'] as String?)?.trim().isNotEmpty == true
                  ? data['displayName'] as String
                  : doc.id;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(14),
            children: <Widget>[
              _infoCard(
                title: 'Résumé',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _summaryLine('Joueurs', '${docs.length}'),
                    _summaryLine('Crédits total', '$totalCredits'),
                    _summaryLine('Parties total', '$totalGames'),
                    _summaryLine('Meilleur joueur', bestPlayer),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _infoCard(
                title: 'Classement',
                child: Column(
                  children: docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                    final Map<String, dynamic> data = doc.data();
                    final String name = (data['displayName'] as String?)?.trim().isNotEmpty == true
                        ? data['displayName'] as String
                        : 'Joueur';
                    final String email = (data['email'] as String?) ?? '-';
                    final int credits = (data['credits'] as num?)?.toInt() ?? 0;
                    final int wins = (data['wins'] as num?)?.toInt() ?? 0;
                    final int losses = (data['losses'] as num?)?.toInt() ?? 0;
                    final int games = (data['totalGames'] as num?)?.toInt() ?? (wins + losses);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: GinoPopupStyle.screenGreen.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GinoPopupStyle.borderGreen, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: GinoPopupStyle.baseText(
                              fontSize: 16,
                              fontWeight: GinoPopupStyle.titleWeight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(email, style: GinoPopupStyle.baseText(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'Crédit: $credits • V: $wins • D: $losses • Parties: $games',
                            style: GinoPopupStyle.baseText(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: GinoPopupButton(
                                  label: '+ Crédit',
                                  onPressed: () => _changeCredit(
                                    context: context,
                                    uid: doc.id,
                                    add: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GinoPopupButton(
                                  label: '- Crédit',
                                  isPrimary: false,
                                  onPressed: () => _changeCredit(
                                    context: context,
                                    uid: doc.id,
                                    add: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GinoPopupStyle.popupGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GinoPopupStyle.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GinoPopupStyle.baseText(
              fontSize: 18,
              fontWeight: GinoPopupStyle.titleWeight,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label : $value',
        style: GinoPopupStyle.baseText(fontSize: 14),
      ),
    );
  }
}
