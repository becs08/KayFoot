# 🔐 Configuration Sécurisée - Sama Minifoot

## ⚠️ IMPORTANT: Variables d'Environnement

Ce projet utilise maintenant des variables d'environnement pour protéger les clés sensibles Firebase. **Ne jamais** committer les vraies clés dans le code source.

## 📋 Configuration Requise

### 1. Créer le fichier .env

Copiez le fichier `.env.example` vers `.env` et remplacez les valeurs:

```bash
cp .env.example .env
```

Puis éditez le fichier `.env` avec vos vraies valeurs Firebase:

```env
# Firebase Android Configuration
FIREBASE_ANDROID_API_KEY=AIzaSyAmHkkBHFoSVyCKct7Og7oob40cFFho6rk
FIREBASE_ANDROID_APP_ID=1:409307077227:android:3b7ad549443ac1addaaf2e
FIREBASE_ANDROID_PACKAGE_NAME=com.example.samaminifoot.sama_minifoot

# Firebase iOS Configuration  
FIREBASE_IOS_API_KEY=AIzaSyCOeDtK1jxWbR8zoNhlvTpicFpqRk2XYiE
FIREBASE_IOS_APP_ID=1:409307077227:ios:c0177754a3fdcce3daaf2e
FIREBASE_IOS_BUNDLE_ID=com.example.kayfoot

# Firebase Common Configuration
FIREBASE_MESSAGING_SENDER_ID=409307077227
FIREBASE_PROJECT_ID=sama-minifoot-2024
FIREBASE_STORAGE_BUCKET=sama-minifoot-2024.firebasestorage.app

# API Configuration
API_BASE_URL=https://api.samaminifoot.sn
```

### 2. Configuration Google Services

#### Android
1. Copiez `android/app/google-services.json.template` vers `android/app/google-services.json`
2. Remplacez toutes les valeurs `REPLACE_WITH_YOUR_*` par vos vraies valeurs Firebase

#### iOS  
1. Téléchargez `GoogleService-Info.plist` depuis Firebase Console
2. Placez-le dans `ios/Runner/GoogleService-Info.plist`

### 3. Variables d'Environnement (Production)

Pour la production, configurez les variables d'environnement au niveau du système:

#### Linux/macOS:
```bash
export FIREBASE_ANDROID_API_KEY="votre_cle_android"
export FIREBASE_IOS_API_KEY="votre_cle_ios"
export FIREBASE_PROJECT_ID="votre_project_id"
# ... autres variables
```

#### Windows:
```cmd
set FIREBASE_ANDROID_API_KEY=votre_cle_android
set FIREBASE_IOS_API_KEY=votre_cle_ios
set FIREBASE_PROJECT_ID=votre_project_id
```

#### Docker:
```yaml
environment:
  - FIREBASE_ANDROID_API_KEY=votre_cle_android
  - FIREBASE_IOS_API_KEY=votre_cle_ios
  - FIREBASE_PROJECT_ID=votre_project_id
```

## 🚫 Fichiers à NE JAMAIS Committer

Les fichiers suivants contiennent des informations sensibles et sont dans `.gitignore`:

- `.env`
- `.env.local`
- `.env.production`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase-config.json`

## ✅ Vérification de Sécurité

Avant de committer, vérifiez:

1. **Aucune clé API dans le code**: 
   ```bash
   grep -r "AIza" lib/ --exclude-dir=.git
   ```

2. **Fichiers sensibles ignorés**:
   ```bash
   git status --ignored
   ```

3. **Variables d'environnement configurées**:
   - Le app affiche "Production" au démarrage
   - Pas de messages "ATTENTION: Utilisation de la configuration de développement"

## 🔧 Développement

### Mode Développement
- Si aucune variable d'environnement n'est configurée, l'app utilise des valeurs de fallback
- Un message d'avertissement s'affiche dans les logs
- **Ces valeurs de fallback doivent être remplacées pour la production**

### Mode Production
- Variables d'environnement requises
- Validation automatique des clés
- Aucun message d'avertissement

## 🆘 Dépannage

### Erreur "Configuration key not found"
- Vérifiez que le fichier `.env` existe
- Vérifiez que toutes les variables sont définies
- Redémarrez l'application

### Erreur Firebase
- Vérifiez que les clés API sont correctes
- Vérifiez que le projet Firebase est actif
- Vérifiez la configuration du package name/bundle ID

### Variables d'environnement non chargées
- Redémarrez votre IDE
- Vérifiez le format du fichier `.env`
- Utilisez des guillemets pour les valeurs avec espaces

## 📞 Support

En cas de problème avec la configuration sécurisée:
1. Vérifiez ce guide
2. Consultez les logs de l'application
3. Vérifiez la configuration Firebase Console

---

**⚠️ RAPPEL IMPORTANT**: Ne jamais committer de vraies clés API ou fichiers de configuration Firebase dans le repository Git!