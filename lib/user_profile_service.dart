import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'player_profile.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');

  static const int minPseudoLength = 2;
  static const int maxPseudoLength = 20;

  String suggestedNameFromUser(User user) {
    final String displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final String emailName = (user.email ?? '').split('@').first.trim();
    if (emailName.isNotEmpty) {
      return emailName;
    }
    return 'Joueur';
  }

  Future<PlayerProfile> createOrUpdateFromGoogleUser(User user) async {
    debugPrint('[UserProfileService] profile load started for uid=${user.uid}');
    final String suggestedDisplayName = suggestedNameFromUser(user);
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(ref);
        if (!snapshot.exists) {
          tx.set(ref, <String, dynamic>{
            'uid': user.uid,
            'pseudo': suggestedDisplayName,
            'displayName': suggestedDisplayName,
            'email': user.email,
            'photoUrl': user.photoURL,
            'avatarUrl': user.photoURL,
            'credits': 1000,
            'wins': 0,
            'losses': 0,
            'totalGames': 0,
            'score': 0,
            'rankScore': 0,
            'isRegistered': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          return;
        }
        final String existingDisplayName =
            (snapshot.data()?['displayName'] as String?)?.trim() ?? '';
        final String existingPseudo =
            (snapshot.data()?['pseudo'] as String?)?.trim() ?? '';
        tx.update(ref, <String, dynamic>{
          if (existingDisplayName.isEmpty) 'displayName': suggestedDisplayName,
          if (existingPseudo.isEmpty) 'pseudo': suggestedDisplayName,
          'email': user.email,
          'photoUrl': user.photoURL,
          'avatarUrl': user.photoURL,
          'isRegistered': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[UserProfileService] Firestore transaction failed for uid=${user.uid}: ${error.code} - ${error.message}\n$stackTrace',
      );
      rethrow;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final PlayerProfile profile = PlayerProfile.fromMap(<String, dynamic>{
      'uid': user.uid,
      'pseudo': data['pseudo'] ?? data['displayName'] ?? suggestedDisplayName,
      'displayName': data['displayName'] ?? suggestedDisplayName,
      'email': data['email'] ?? user.email,
      'photoUrl': data['photoUrl'] ?? user.photoURL,
      'avatarUrl': data['avatarUrl'] ?? user.photoURL,
      'credits': data['credits'] ?? 1000,
      'wins': data['wins'] ?? 0,
      'losses': data['losses'] ?? 0,
      'totalGames': data['totalGames'] ?? 0,
      'rankScore': data['rankScore'] ?? data['score'] ?? 0,
      'createdAt': data['createdAt'] ?? Timestamp.fromDate(now),
      'lastLoginAt': data['lastLoginAt'] ?? Timestamp.fromDate(now),
    });
    debugPrint(
      '[UserProfileService] profile loaded for uid=${user.uid} pseudo=${profile.effectivePseudo}',
    );
    return profile;
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'pseudo': displayName,
        'displayName': displayName,
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String? validatePseudo(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Le pseudo ne peut pas être vide.';
    }
    if (trimmed.length < minPseudoLength) {
      return 'Le pseudo doit contenir au moins $minPseudoLength caractères.';
    }
    if (trimmed.length > maxPseudoLength) {
      return 'Le pseudo doit contenir au maximum $maxPseudoLength caractères.';
    }
    return null;
  }

  Future<void> updatePseudo({
    required String uid,
    required String pseudo,
  }) async {
    final String? validationError = validatePseudo(pseudo);
    if (validationError != null) {
      throw StateError(validationError);
    }
    final String cleaned = pseudo.trim();
    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'pseudo': cleaned,
        'displayName': cleaned,
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<PlayerProfile?> watchProfile(String uid) {
    return _profiles.doc(uid).snapshots().map((DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!doc.exists) {
        return null;
      }
      return PlayerProfile.fromMap(doc.data() ?? <String, dynamic>{});
    });
  }

  Future<PlayerProfile?> getProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _profiles.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return PlayerProfile.fromMap(doc.data() ?? <String, dynamic>{});
  }
}
