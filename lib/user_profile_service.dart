import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'game_card_avatar.dart';
import 'player_profile.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');

  String sanitizeDisplayName(String value, {int maxLength = 18}) {
    final String singleSpaced = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleSpaced.isEmpty) {
      return '';
    }
    return singleSpaced.length <= maxLength
        ? singleSpaced
        : singleSpaced.substring(0, maxLength);
  }

  String suggestedNameFromUser(User user) {
    final String displayName = sanitizeDisplayName(user.displayName ?? '');
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final String emailName = sanitizeDisplayName((user.email ?? '').split('@').first);
    if (emailName.isNotEmpty) {
      return emailName;
    }
    return 'Joueur';
  }

  GameCardAvatarData defaultCardAvatarForUid(String uid) {
    return GameCardAvatarPalette.fromSeed(uid);
  }

  Future<PlayerProfile> createOrUpdateFromGoogleUser(User user) async {
    final String suggestedDisplayName = suggestedNameFromUser(user);
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(user.uid);
    final GameCardAvatarData defaultCardAvatar = defaultCardAvatarForUid(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(ref);
        if (!snapshot.exists) {
          tx.set(ref, <String, dynamic>{
            'uid': user.uid,
            'displayName': suggestedDisplayName,
            'email': user.email,
            'photoUrl': user.photoURL,
            'credits': 1000,
            'welcomeCreditsGranted': true,
            'wins': 0,
            'losses': 0,
            'totalGames': 0,
            'score': 0,
            'rankScore': 0,
            'cardAvatarRank': defaultCardAvatar.rank,
            'cardAvatarSuit': defaultCardAvatar.suit,
            'hasCustomProfile': false,
            'isRegistered': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
        final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
        final String existingDisplayName = (data['displayName'] as String? ?? '').trim();
        final bool hasCustomProfile = data['hasCustomProfile'] as bool? ?? false;

        tx.update(ref, <String, dynamic>{
          if (existingDisplayName.isEmpty && !hasCustomProfile)
            'displayName': suggestedDisplayName,
          if (data['wins'] == null) 'wins': 0,
          if (data['losses'] == null) 'losses': 0,
          if (data['totalGames'] == null) 'totalGames': 0,
          if (data['score'] == null) 'score': 0,
          if (data['rankScore'] == null) 'rankScore': data['score'] ?? 0,
          if (data['cardAvatarRank'] == null) 'cardAvatarRank': defaultCardAvatar.rank,
          if (data['cardAvatarSuit'] == null) 'cardAvatarSuit': defaultCardAvatar.suit,
          if (data['hasCustomProfile'] == null) 'hasCustomProfile': false,
          'email': user.email,
          'photoUrl': user.photoURL,
          'isRegistered': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[UserProfileService] createOrUpdateFromGoogleUser failed for uid=${user.uid}: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return PlayerProfile.fromMap(<String, dynamic>{
      'uid': user.uid,
      'displayName': data['displayName'] ?? suggestedDisplayName,
      'email': data['email'] ?? user.email,
      'photoUrl': data['photoUrl'] ?? user.photoURL,
      'avatarUrl': data['avatarUrl'],
      'credits': data['credits'] ?? 1000,
      'wins': data['wins'] ?? 0,
      'losses': data['losses'] ?? 0,
      'totalGames': data['totalGames'] ?? 0,
      'rankScore': data['rankScore'] ?? data['score'] ?? 0,
      'cardAvatarRank': data['cardAvatarRank'] ?? defaultCardAvatar.rank,
      'cardAvatarSuit': data['cardAvatarSuit'] ?? defaultCardAvatar.suit,
      'hasCustomProfile': data['hasCustomProfile'] ?? false,
      'profilePromptDismissedAt': data['profilePromptDismissedAt'],
      'createdAt': data['createdAt'] ?? Timestamp.fromDate(now),
      'lastLoginAt': data['lastLoginAt'] ?? Timestamp.fromDate(now),
    });
  }

  Future<void> updatePublicProfile({
    required String uid,
    required String displayName,
    required String cardAvatarRank,
    required String cardAvatarSuit,
  }) async {
    final String cleanedName = sanitizeDisplayName(displayName, maxLength: 18);
    if (cleanedName.isEmpty) {
      throw ArgumentError('Le pseudo ne peut pas être vide.');
    }
    if (!GameCardAvatarPalette.ranks.contains(cardAvatarRank)) {
      throw ArgumentError('Valeur de carte invalide.');
    }
    if (!GameCardAvatarPalette.suits.contains(cardAvatarSuit)) {
      throw ArgumentError('Symbole de carte invalide.');
    }

    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'displayName': cleanedName,
        'cardAvatarRank': cardAvatarRank,
        'cardAvatarSuit': cardAvatarSuit,
        'hasCustomProfile': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final String cleanedName = sanitizeDisplayName(displayName);
    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'displayName': cleanedName,
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> dismissProfileCustomizationPrompt({
    required String uid,
  }) async {
    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'profilePromptDismissedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<PlayerProfile?> getProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _profiles.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return PlayerProfile.fromMap(doc.data() ?? <String, dynamic>{});
  }
}
