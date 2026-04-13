# huit

Application Flutter de jeu de cartes (solo + duel en ligne via Firebase).

## Configuration Firebase minimale (Android)

Le mode duel utilise Firestore. Sans configuration Firebase valide, le mode solo reste utilisable, mais le mode duel échouera.

### 1) Ajouter le fichier Android Firebase

1. Créer un projet Firebase (ou réutiliser un existant).
2. Enregistrer l'application Android avec l'`applicationId` de l'app (`com.example.huit` dans ce repo).
3. Télécharger `google-services.json`.
4. Copier le fichier dans:

```text
android/app/google-services.json
```

### 2) Plugins Gradle requis

Ce repo applique déjà les plugins nécessaires:

- `com.google.gms.google-services` dans `android/settings.gradle.kts`
- `com.google.gms.google-services` dans `android/app/build.gradle.kts`

### 3) Initialisation Firebase côté Flutter

L'application initialise Firebase au démarrage avec deux chemins possibles:

- **Chemin A (recommandé Android natif):** `Firebase.initializeApp()` via `google-services.json`
- **Chemin B (fallback via options):** `Firebase.initializeApp(options: ...)` avec `--dart-define`

Les options Android (fallback) sont lues depuis `lib/firebase_config.dart`.

### 4) Variables minimales pour le fallback `--dart-define`

Exemple de lancement:

```bash
flutter run \
  --dart-define=FIREBASE_ANDROID_API_KEY=xxx \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:1234567890:android:abcdef \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=mon-projet-id \
  --dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=mon-projet-id.firebasestorage.app
```

Les 4 premières valeurs sont obligatoires pour le fallback (`API_KEY`, `APP_ID`, `MESSAGING_SENDER_ID`, `PROJECT_ID`).

### 5) Vérification rapide

- Lancer l'app.
- Ouvrir **Mode Duel (en ligne)**.
- Créer/rejoindre une partie: si Firestore est configuré, l'écran duel doit fonctionner sans erreur `[core/no-app]`.
