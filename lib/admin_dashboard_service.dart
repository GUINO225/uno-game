import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'player_profile.dart';

class AdminAccessState {
  const AdminAccessState({
    required this.isAllowed,
    required this.reason,
  });

  final bool isAllowed;
  final String reason;
}

class AdminTransactionRecord {
  const AdminTransactionRecord({
    required this.id,
    required this.targetUserId,
    required this.targetPseudo,
    required this.amount,
    required this.adminId,
    required this.adminEmail,
    required this.operationType,
    required this.createdAt,
  });

  final String id;
  final String targetUserId;
  final String targetPseudo;
  final int amount;
  final String adminId;
  final String adminEmail;
  final String operationType;
  final DateTime? createdAt;

  factory AdminTransactionRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return AdminTransactionRecord(
      id: doc.id,
      targetUserId: data['targetUserId'] as String? ?? '',
      targetPseudo: data['targetPseudo'] as String? ?? 'Joueur',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      adminId: data['adminId'] as String? ?? '',
      adminEmail: data['adminEmail'] as String? ?? '',
      operationType: data['operationType'] as String? ?? 'credit_add',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminDashboardService {
  AdminDashboardService._();

  static final AdminDashboardService instance = AdminDashboardService._();

  static const Set<String> _fallbackAllowedAdminEmails = <String>{
    'admin@uno-game.local',
  };

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');

  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance.collection('admin_transactions');

  Future<AdminAccessState> checkAdminAccess(User user) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _profiles.doc(user.uid).get();
    final Map<String, dynamic> profile = doc.data() ?? <String, dynamic>{};
    final String role = (profile['role'] as String? ?? 'player').trim();
    final String email = (user.email ?? '').trim().toLowerCase();
    final bool emailAllowed =
        email.isNotEmpty && _fallbackAllowedAdminEmails.contains(email);

    if (role == 'admin' || emailAllowed) {
      return const AdminAccessState(
        isAllowed: true,
        reason: '',
      );
    }

    if (user.email == null || user.email!.trim().isEmpty) {
      return const AdminAccessState(
        isAllowed: false,
        reason: 'Compte non autorisé: email administrateur requis.',
      );
    }

    return const AdminAccessState(
      isAllowed: false,
      reason: 'Accès refusé: rôle administrateur requis.',
    );
  }

  Stream<List<PlayerProfile>> watchAllPlayers() {
    return _profiles
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return PlayerProfile.fromMap(doc.data());
          })
          .toList(growable: false);
    });
  }

  Stream<List<AdminTransactionRecord>> watchTransactions() {
    return _transactions
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .map(AdminTransactionRecord.fromDoc)
          .toList(growable: false);
    });
  }

  Future<void> addCreditsToPlayer({
    required User adminUser,
    required String targetUserId,
    required int amount,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0.');
    }

    final DocumentReference<Map<String, dynamic>> adminRef =
        _profiles.doc(adminUser.uid);
    final DocumentReference<Map<String, dynamic>> playerRef =
        _profiles.doc(targetUserId);
    final DocumentReference<Map<String, dynamic>> transactionRef =
        _transactions.doc();

    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> adminDoc =
          await tx.get(adminRef);
      final Map<String, dynamic> adminData =
          adminDoc.data() ?? <String, dynamic>{};

      final String adminRole = (adminData['role'] as String? ?? 'player').trim();
      final String adminEmail = (adminUser.email ?? '').trim().toLowerCase();
      final bool emailAllowed = adminEmail.isNotEmpty &&
          _fallbackAllowedAdminEmails.contains(adminEmail);
      if (adminRole != 'admin' && !emailAllowed) {
        throw StateError('Action non autorisée.');
      }

      final DocumentSnapshot<Map<String, dynamic>> playerDoc =
          await tx.get(playerRef);
      if (!playerDoc.exists) {
        throw StateError('Joueur introuvable.');
      }

      final Map<String, dynamic> playerData =
          playerDoc.data() ?? <String, dynamic>{};
      final int currentCredits =
          (playerData['credits'] as num?)?.toInt() ?? 0;
      final int nextCredits = currentCredits + amount;
      final String pseudo = (playerData['pseudo'] as String?)?.trim().isNotEmpty ==
              true
          ? (playerData['pseudo'] as String)
          : (playerData['displayName'] as String? ?? 'Joueur');

      tx.set(playerRef, <String, dynamic>{
        'uid': targetUserId,
        'credits': nextCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(transactionRef, <String, dynamic>{
        'targetUserId': targetUserId,
        'targetPseudo': pseudo,
        'amount': amount,
        'adminId': adminUser.uid,
        'adminEmail': adminUser.email,
        'operationType': 'credit_add',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
