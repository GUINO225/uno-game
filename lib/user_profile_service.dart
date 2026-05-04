import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'game_card_avatar.dart';
import 'player_profile.dart';
import 'supabase_user_photo.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  SupabaseClient get _client => Supabase.instance.client;


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
    final String displayName = sanitizeDisplayName((user.userMetadata?['full_name'] as String?) ?? '');
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

  Future<PlayerProfile> createOrUpdateFromGoogleUser(
    User user, {
    bool force = false,
  }) async {
    final String suggestedDisplayName = suggestedNameFromUser(user);
    final DateTime now = DateTime.now().toUtc();

    try {
      final Map<String, dynamic> profilePayload = <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'display_name': suggestedDisplayName,
        'photo_url': supabaseUserPhotoUrl(user),
        'credits': 1000,
        'wins': 0,
        'losses': 0,
        'games_played': 0,
      };

      await _client.from('profiles').upsert(profilePayload, onConflict: 'id');

      final Map<String, dynamic> data = await _client
          .from('profiles')
          .select('id, email, display_name, photo_url, credits, wins, losses, games_played')
          .eq('id', user.id)
          .single();

      return PlayerProfile.fromMap(<String, dynamic>{
        'uid': data['id'] ?? user.id,
        'displayName': data['display_name'] ?? suggestedDisplayName,
        'email': data['email'] ?? user.email,
        'photoUrl': data['photo_url'] ?? supabaseUserPhotoUrl(user),
        'credits': data['credits'] ?? 1000,
        'wins': data['wins'] ?? 0,
        'losses': data['losses'] ?? 0,
        'totalGames': data['games_played'] ?? 0,
        'createdAt': now,
        'lastLoginAt': now,
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[UserProfileService] createOrUpdateFromGoogleUser failed for uid=${user.id}: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': uid,
      'display_name': cleanedName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final String cleanedName = sanitizeDisplayName(displayName);
    await _client.from('profiles').upsert(<String, dynamic>{
      'id': uid,
      'display_name': cleanedName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<void> dismissProfileCustomizationPrompt({
    required String uid,
  }) async {
    await _client.from('profiles').upsert(<String, dynamic>{
      'id': uid,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<PlayerProfile?> getProfile(String uid) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('profiles')
        .select('id, email, display_name, photo_url, credits, wins, losses, games_played')
        .eq('id', uid);
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, dynamic> data = rows.first;
    return PlayerProfile.fromMap(<String, dynamic>{
      'uid': data['id'] ?? uid,
      'displayName': data['display_name'] ?? 'Joueur',
      'email': data['email'],
      'photoUrl': data['photo_url'],
      'credits': data['credits'] ?? 1000,
      'wins': data['wins'] ?? 0,
      'losses': data['losses'] ?? 0,
      'totalGames': data['games_played'] ?? 0,
    });
  }
}
