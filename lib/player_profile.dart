import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_card_avatar.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.avatarUrl,
    this.credits = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalGamesValue,
    this.rankScore = 0,
    this.cardAvatarRank = '',
    this.cardAvatarSuit = '',
    this.hasCustomProfile = false,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? avatarUrl;
  final int credits;
  final int wins;
  final int losses;
  final int? totalGamesValue;
  final int rankScore;
  final String cardAvatarRank;
  final String cardAvatarSuit;
  final bool hasCustomProfile;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  int get totalGames => totalGamesValue ?? (wins + losses);
  double get winRatio => totalGames == 0 ? 0 : wins / totalGames;
  String get id => uid;
  int get score => rankScore;

  String get publicDisplayName {
    final String cleaned = displayName.trim();
    return cleaned.isEmpty ? 'Joueur' : cleaned;
  }

  GameCardAvatarData get selectedCardAvatar {
    if (GameCardAvatarPalette.ranks.contains(cardAvatarRank) &&
        GameCardAvatarPalette.suits.contains(cardAvatarSuit)) {
      return GameCardAvatarPalette.fromSelection(
        rank: cardAvatarRank,
        suit: cardAvatarSuit,
      );
    }
    return GameCardAvatarPalette.fromSeed(uid);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'avatarUrl': avatarUrl,
      'credits': credits,
      'wins': wins,
      'losses': losses,
      'totalGames': totalGames,
      'score': score,
      'rankScore': rankScore,
      'cardAvatarRank': cardAvatarRank,
      'cardAvatarSuit': cardAvatarSuit,
      'hasCustomProfile': hasCustomProfile,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!.toUtc()),
      'lastLoginAt': lastLoginAt == null ? null : Timestamp.fromDate(lastLoginAt!.toUtc()),
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    final String uid = map['uid'] as String? ?? '';
    final String rank = map['cardAvatarRank'] as String? ?? '';
    final String suit = map['cardAvatarSuit'] as String? ?? '';
    final GameCardAvatarData fallback = GameCardAvatarPalette.fromSeed(uid);
    return PlayerProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Joueur',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      avatarUrl: map['avatarUrl'] as String? ?? map['photoUrl'] as String?,
      credits: (map['credits'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      totalGamesValue: (map['totalGames'] as num?)?.toInt(),
      rankScore:
          (map['rankScore'] as num?)?.toInt() ??
          (map['score'] as num?)?.toInt() ??
          (((map['wins'] as num?)?.toInt() ?? 0) * 3) -
              ((map['losses'] as num?)?.toInt() ?? 0),
      cardAvatarRank:
          GameCardAvatarPalette.ranks.contains(rank) ? rank : fallback.rank,
      cardAvatarSuit:
          GameCardAvatarPalette.suits.contains(suit) ? suit : fallback.suit,
      hasCustomProfile: map['hasCustomProfile'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}
