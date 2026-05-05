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

      final Map<String, dynamic> data = await _fetchProfileRow(user.id);

      return PlayerProfile.fromMap(data);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=createOrUpdateFromGoogleUser uid=${user.id}');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.message=${error.message}');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.code=${error.code}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=createOrUpdateFromGoogleUser uid=${user.id}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
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

    debugPrint('[SUPABASE_PROFILE] update pseudo uid=$uid newName=$cleanedName');
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'display_name': cleanedName,
            'card_avatar_rank': cardAvatarRank,
            'card_avatar_suit': cardAvatarSuit,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', uid);
      debugPrint('[SUPABASE_PROFILE] update pseudo success');
      final Map<String, dynamic> data = await _fetchProfileRow(uid);
      debugPrint('[SUPABASE_PROFILE] reloaded display_name=${data['display_name']}');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=updatePublicProfile uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    }
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final String cleanedName = sanitizeDisplayName(displayName);
    if (cleanedName.isEmpty) {
      throw ArgumentError('Le pseudo ne peut pas être vide.');
    }
    debugPrint('[SUPABASE_PROFILE] update pseudo uid=$uid newName=$cleanedName');
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'display_name': cleanedName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', uid);
      debugPrint('[SUPABASE_PROFILE] update pseudo success');
      final Map<String, dynamic> data = await _fetchProfileRow(uid);
      debugPrint('[SUPABASE_PROFILE] reloaded display_name=${data['display_name']}');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=updateDisplayName uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    }
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
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('profiles')
          .select('id, email, display_name, photo_url, credits, wins, losses, games_played, card_avatar_rank, card_avatar_suit, created_at, last_login_at, profile_prompt_dismissed_at')
          .eq('id', uid);
      if (rows.isEmpty) {
        return null;
      }
      return PlayerProfile.fromMap(rows.first);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=getProfile uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.message=${error.message}');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.code=${error.code}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=getProfile uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    }
  }
  Future<int> getCredits(String uid) async {
    try {
      final Map<String, dynamic> data = await _client
          .from('profiles')
          .select('credits')
          .eq('id', uid)
          .single();
      return (data['credits'] as num?)?.toInt() ?? 0;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=getCredits uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.message=${error.message}');
      debugPrint('[SUPABASE_PROFILE_ERROR] PostgrestException.code=${error.code}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[SUPABASE_PROFILE_ERROR] context=getCredits uid=$uid');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.runtimeType=${error.runtimeType}');
      debugPrint('[SUPABASE_PROFILE_ERROR] error.toString()=${error.toString()}');
      debugPrint('[SUPABASE_PROFILE_ERROR] stackTrace=$stackTrace');
      rethrow;
    }
  }


  Future<Map<String, dynamic>> _fetchProfileRow(String uid) async {
    return await _client
        .from('profiles')
        .select('id, email, display_name, photo_url, credits, wins, losses, games_played, card_avatar_rank, card_avatar_suit, created_at, last_login_at, profile_prompt_dismissed_at')
        .eq('id', uid)
        .single();
  }

}
