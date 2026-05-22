# App rendu Android

Release Flutter Android genere le 2026-05-22 avec :

```sh
flutter build apk --release --split-per-abi
```

Version application : `2.4.0+1`

## Fichiers

- `app-arm64-v8a-release.apk` : telephones Android recents.
- `app-armeabi-v7a-release.apk` : anciens appareils Android 32 bits.
- `app-x86_64-release.apk` : emulateurs Android x86_64.

L'APK universel genere localement depasse la limite GitHub de 100 MB par fichier. Les APKs par architecture sont donc fournis dans ce dossier.

## SHA-256

```text
5590eb6b31f5c61bf0d5888b4df6116a9e5bc588c602e393d52ed0d4ce3593f4  app-armeabi-v7a-release.apk
4b5d7464a0dd43ce4bb5b57b43f4241e977e68a5cb738596fea242386a5d7a9b  app-arm64-v8a-release.apk
dbdb73110891a85d1d3adae7774a5e49c2610c3e35aa19c419db4c11c30f53a7  app-x86_64-release.apk
```
