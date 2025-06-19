# Kayfoot 🇸🇳⚽

Application mobile Flutter pour la réservation de terrains de minifoot au Sénégal.

## 📱 Aperçu de l'application

Kayfoot est une application mobile développée en Flutter qui permet aux utilisateurs de réserver facilement des terrains de minifoot partout au Sénégal. L'application offre une interface intuitive, des paiements sécurisés via Mobile Money, et un système de notation transparent.

## ✨ Fonctionnalités principales

### 🏃‍♂️ Pour les Joueurs
- **Authentification sécurisée** : Inscription/connexion avec email ou téléphone
- **Recherche de terrains** : Trouvez des terrains par ville avec filtres avancés
- **Réservation en temps réel** : Sélectionnez votre créneau et payez instantanément
- **Paiement Mobile Money** : Orange Money, Wave, Free Money
- **QR Code d'accès** : Code unique pour confirmer votre réservation
- **Historique complet** : Consultez toutes vos réservations passées et futures
- **Système de notation** : Notez et commentez les terrains après utilisation
- **Profil personnalisé** : Gérez vos informations et statistiques

### 🏢 Pour les Gérants
- **Gestion de terrains** : Ajoutez et gérez vos terrains
- **Planning de disponibilités** : Définissez vos créneaux horaires
- **Suivi des réservations** : Consultez toutes les réservations en temps réel
- **Gestion des tarifs** : Fixez vos prix par heure
- **Équipements** : Listez les équipements disponibles

## 🛠️ Technologies utilisées

- **Framework** : Flutter 3.24.3
- **Langage** : Dart 3.5.3
- **Gestion d'état** : Provider
- **Stockage local** : SharedPreferences
- **Génération QR** : qr_flutter
- **Interface utilisateur** : Material Design 3
- **Architecture** : Clean Architecture avec séparation des responsabilités

## 📁 Structure du projet

```
lib/
├── constants/          # Constantes de l'application
│   └── app_constants.dart
├── models/            # Modèles de données
│   ├── user.dart
│   ├── terrain.dart
│   ├── reservation.dart
│   └── avis.dart
├── services/          # Services métier
│   ├── auth_service.dart
│   ├── terrain_service.dart
│   └── reservation_service.dart
├── screens/           # Écrans de l'application
│   ├── auth/         # Authentification
│   ├── home/         # Accueil
│   ├── terrain/      # Gestion des terrains
│   ├── booking/      # Réservation
│   ├── reservations/ # Historique
│   └── profile/      # Profil utilisateur
├── widgets/          # Composants réutilisables
└── main.dart         # Point d'entrée
```

## 🚀 Installation et exécution

### Prérequis
- Flutter SDK (3.24.3 ou supérieur)
- Dart SDK (3.5.3 ou supérieur)
- Android Studio / VS Code
- Émulateur Android ou device physique

### Installation
1. Clonez le repository
```bash
git clone [url-du-repo]
cd sama_minifoot
```

2. Installez les dépendances
```bash
flutter pub get
```

3. Lancez l'application
```bash
flutter run
```

## 📱 Écrans principaux

### 🔐 Authentification
- **Splash Screen** : Animation de chargement avec logo
- **Connexion** : Email/téléphone et mot de passe
- **Inscription** : Formulaire complet avec sélection de rôle

### 🏠 Accueil
- **Dashboard personnalisé** : Adapté au type d'utilisateur
- **Recherche rapide** : Barre de recherche intelligente
- **Terrains populaires** : Suggestions basées sur les notes
- **Actions rapides** : Accès direct aux fonctions principales

### ⚽ Terrains
- **Liste filtrée** : Recherche par ville, prix, équipements
- **Détails complets** : Photos, équipements, avis, disponibilités
- **Système de notation** : Étoiles et commentaires
- **Géolocalisation** : Localisation des terrains

### 📅 Réservation
- **Sélection de date** : Calendrier interactif
- **Créneaux disponibles** : Affichage en temps réel
- **Paiement Mobile Money** : Orange, Wave, Free
- **Confirmation** : Reçu avec QR code unique

### 📋 Historique
- **Réservations actives** : Matchs à venir avec QR code
- **Historique complet** : Toutes les réservations passées
- **Annulation** : Possible jusqu'à 2h avant le match
- **Téléchargement** : Reçus en PDF

### 👤 Profil
- **Informations personnelles** : Modification des données
- **Statistiques** : Matchs joués, temps de jeu, terrains visités
- **Paramètres** : Notifications, confidentialité
- **Déconnexion sécurisée**

## 💳 Système de paiement

L'application simule l'intégration avec les services de Mobile Money populaires au Sénégal :

- **Orange Money** : Principal opérateur mobile
- **Wave** : Service de paiement mobile populaire
- **Free Money** : Service de Free Sénégal
- **Espèces** : Paiement sur place

*Note: L'intégration réelle avec les APIs de paiement nécessite des accords commerciaux avec les prestataires.*

## 🎨 Design et UX

### Charte graphique
- **Couleur principale** : Vert (#2E7D32) - Représente le terrain de foot
- **Couleur secondaire** : Vert clair (#4CAF50)
- **Couleur accent** : Orange (#FFC107) - Rappel du drapeau sénégalais
- **Police** : Poppins - Moderne et lisible

### Principe de design
- **Material Design 3** : Interface moderne et familière
- **Navigation intuitive** : Bottom navigation et actions claires
- **Responsive** : Adaptation aux différentes tailles d'écran
- **Accessibilité** : Respect des standards d'accessibilité

## 🔒 Sécurité et données

### Protection des données
- **Authentification sécurisée** : Tokens et sessions
- **Stockage local chiffré** : Données sensibles protégées
- **Validation stricte** : Contrôles côté client et serveur
- **QR Codes uniques** : Sécurité des réservations

### Conformité
- Respect du RGPD pour les données personnelles
- Stockage local des données non sensibles
- Chiffrement des informations critiques

## 🌍 Contexte sénégalais

### Villes couvertes
L'application couvre les principales villes du Sénégal :
- Dakar, Thiès, Kaolack, Saint-Louis
- Ziguinchor, Diourbel, Tambacounda
- Kolda, Matam, Kaffrine, et plus...

### Adaptation locale
- **Interface en français** : Langue principale
- **Mobile Money** : Moyens de paiement locaux
- **Équipements locaux** : Terrain naturel/synthétique
- **Horaires adaptés** : Créneaux de 6h à 22h

## 🔮 Fonctionnalités futures

### Version 2.0
- [ ] Intégration GPS en temps réel
- [ ] Chat entre joueurs
- [ ] Tournois et compétitions
- [ ] Programme de fidélité
- [ ] Notifications push
- [ ] Mode hors-ligne

### Version 3.0
- [ ] Live streaming des matchs
- [ ] Analyse de performance
- [ ] Réseaux sociaux intégrés
- [ ] IA pour recommandations
- [ ] Support multilingue (Wolof, Pulaar, etc.)

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le projet
2. Créez une branche feature (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pushez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 📞 Contact

**Équipe SamaMinifoot**
- Email: contact@samaminifoot.sn
- Site web: https://samaminifoot.sn
- Twitter: @SamaMinifoot

---

*Développé avec ❤️ pour la communauté de minifoot du Sénégal* 🇸🇳

## 🙏 Remerciements

- La communauté Flutter pour les outils excellents
- Les joueurs de minifoot sénégalais pour l'inspiration
- Les gérants de terrains pour leurs retours précieux
- L'écosystème open source pour les packages utilisés

---

**Teranga** - *L'hospitalité sénégalaise dans chaque ligne de code* ⚽