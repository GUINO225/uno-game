# huit

Application Flutter de jeu de cartes (solo + duel en ligne via Firebase).

## Pourquoi tu as l'erreur actuelle

Le message `Firebase non configuré` dans ton écran Duel (web) veut dire que Firebase n'a pas été initialisé pour la plateforme en cours (dans ta photo: **Web**).

---

## Configuration Firebase minimale (Android + Web)

Le mode duel utilise Firestore. Sans Firebase valide, le mode solo marche, mais le mode duel échoue.

### 1) Créer/ouvrir ton projet Firebase

1. Va sur la console Firebase.
2. Crée un projet (ou ouvre le tien).
3. Active **Cloud Firestore** (mode test au début, puis règles sécurisées ensuite).

### 2) Configurer Android

1. Dans Firebase > Project settings > General > Your apps, ajoute une app Android.
2. Mets l'`applicationId` exact: `com.example.huit` (ou ton vrai id si tu l'as changé).
3. Télécharge `google-services.json`.
4. Place le fichier ici:

```text
android/app/google-services.json
```

Les plugins Gradle sont déjà posés dans ce repo:
- `android/settings.gradle.kts`
- `android/app/build.gradle.kts`

### 3) Configurer Web (IMPORTANT pour ton erreur actuelle)

1. Dans Firebase > Project settings > General > Your apps, ajoute une app **Web**.
2. Firebase te donne un bloc `firebaseConfig` avec des clés comme:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `authDomain` (souvent utile)
   - `storageBucket` (optionnel)
   - `measurementId` (optionnel)

### 4) Lancer l'app avec les bonnes variables `--dart-define`

## Web (Chrome)

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_WEB_API_KEY=xxx \
  --dart-define=FIREBASE_WEB_APP_ID=1:1234567890:web:abcdef \
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_WEB_PROJECT_ID=mon-projet-id \
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN=mon-projet-id.firebaseapp.com \
  --dart-define=FIREBASE_WEB_STORAGE_BUCKET=mon-projet-id.firebasestorage.app \
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID=G-XXXXXXXXXX
```

## Android (émulateur/téléphone)

```bash
flutter run \
  --dart-define=FIREBASE_ANDROID_API_KEY=xxx \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:1234567890:android:abcdef \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=mon-projet-id \
  --dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=mon-projet-id.firebasestorage.app
```

### 5) Vérification rapide

- Lance en web avec les variables ci-dessus.
- Ouvre **Mode Duel**.
- Si Firebase est bien configuré, l'erreur `Firebase non configuré` disparaît et les opérations Firestore (create/join) fonctionnent.

---

## Astuce (plus simple à long terme)

Utilise `flutterfire configure` pour générer automatiquement un vrai `firebase_options.dart` pour Android/Web/iOS. Ça évite de passer plein de `--dart-define` à chaque lancement.
