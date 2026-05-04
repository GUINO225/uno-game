# MIGRATION SUPABASE — Phase 0

## Déjà fait côté Supabase (dashboard)
- Projet Supabase créé.
- URL du projet récupérée.
- Publishable key récupérée.
- Table `public.duel_games` créée.
- RLS activé sur `public.duel_games`.
- Policies minimales créées pour `authenticated`:
  - `select`
  - `insert`
  - `update`

## Changements ajoutés dans Flutter
- Dépendance `supabase_flutter` ajoutée dans `pubspec.yaml`.
- Fichier `lib/config/backend_flags.dart` ajouté avec tous les flags Supabase à `false`.
- Initialisation Supabase préparée dans `lib/main.dart` avec:
  - `SUPABASE_URL` (URL projet)
  - `SUPABASE_PUBLISHABLE_KEY` (publishable key)
- Initialisation conditionnelle: Supabase ne s'initialise pas tant que tous les flags restent à `false`.
- Service `lib/services/supabase_game_service.dart` ajouté avec les méthodes préparées:
  - `createRoom`
  - `joinRoom`
  - `listenRoom`
- Aucune interface branchée sur Supabase tant que les flags sont désactivés.
- Firebase et Firebase Hosting conservés, sans suppression.

## Prochaines étapes
1. Ajouter Supabase Auth (anonymous ou email/OAuth) derrière `useSupabaseAuth`.
2. Mapper strictement le schéma `duel_games` (types, contraintes, statuts) avec le modèle Flutter.
3. Activer progressivement `useSupabaseGameWrite` puis `useSupabaseGameRead` sur un environnement de test.
4. Brancher la création/rejoint de room dans le flux duel, tout en gardant un fallback Firebase.
5. Ajouter gestion d'erreurs réseau/retry et états de reconnexion realtime.
6. Ajouter tests d'intégration pour création/rejoint/écoute de room.
7. Préparer Phase 1: credits/ranking avec tables dédiées + politiques RLS fines.
