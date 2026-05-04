# Migration Duel/Paris Firebase -> Supabase

## A. Fichiers utilisant encore Firebase
- `lib/duel_mode.dart`
- `lib/auth_service.dart`
- `lib/main.dart`
- `lib/user_profile_service.dart`
- `lib/stats_service.dart`
- `lib/leaderboard_service.dart`
- `lib/leaderboard_page.dart`
- `lib/game_history_page.dart`
- `lib/player_side_panel.dart`
- `lib/admin_dashboard.dart`
- `lib/firebase_config.dart`
- `lib/firebase_options.dart`

## B. Nouveau schéma Supabase
Voir `supabase/migrations/20260504_duel_paris_full_supabase.sql`.

## C/D. Plan de remplacement service par service
1. Auth: `AuthService` -> Supabase Auth Google OAuth, plus de `FirebaseAuth`.
2. Profiles/Credits/Stats: `UserProfileService` + `StatsService` -> tables `profiles`, `credit_transactions`, RPC `apply_duel_bet_result`.
3. Duel realtime: `GameService` (dans `duel_mode.dart`) -> `SupabaseGameService` pour create/join/listen/actions/chat/presence.
4. Presence: remplacer `SimplePresenceService` Firestore par writes `duel_presence` + Supabase Realtime Presence.
5. Leaderboard/history: `LeaderboardService` et `GameHistoryPage` -> views/tables Supabase.
6. Nettoyage: supprimer branches hybrides et flags temporaires après bascule complète.

## E. Tests manuels à exécuter
- Créer room
- Rejoindre room
- Jouer une carte
- Piocher
- Proposer pari
- Accepter pari
- Gagner/perdre
- Abandon
- Revanche
- Chat
- Classement
- Historique

