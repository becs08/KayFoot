# API Documentation - SamaMinifoot

## Base URL
```
https://api.samaminifoot.sn/v1
```

## Authentication
L'API utilise l'authentification par token Bearer.

```http
Authorization: Bearer {token}
```

## Endpoints

### 🔐 Authentication

#### POST /auth/register
Inscription d'un nouvel utilisateur.

**Request Body:**
```json
{
  "nom": "Mamadou Diallo",
  "telephone": "771234567",
  "email": "mamadou@example.com",
  "motDePasse": "password123",
  "ville": "Dakar",
  "role": "joueur" // ou "gerant"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Inscription réussie",
  "data": {
    "user": {
      "id": "user_123",
      "nom": "Mamadou Diallo",
      "telephone": "771234567",
      "email": "mamadou@example.com",
      "ville": "Dakar",
      "role": "joueur",
      "dateCreation": "2024-01-15T10:30:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### POST /auth/login
Connexion d'un utilisateur.

**Request Body:**
```json
{
  "identifier": "mamadou@example.com", // email ou téléphone
  "motDePasse": "password123"
}
```

#### PUT /auth/profile
Mise à jour du profil utilisateur.

#### POST /auth/logout
Déconnexion de l'utilisateur.

### ⚽ Terrains

#### GET /terrains
Récupérer la liste des terrains.

**Query Parameters:**
- `ville` (optional): Filtrer par ville
- `page` (optional): Numéro de page (défaut: 1)
- `limit` (optional): Nombre d'éléments par page (défaut: 10)
- `search` (optional): Recherche textuelle

**Response:**
```json
{
  "success": true,
  "data": {
    "terrains": [
      {
        "id": "terrain_123",
        "nom": "Terrain Excellence Dakar",
        "description": "Terrain moderne avec éclairage LED",
        "ville": "Dakar",
        "adresse": "Plateau, Dakar",
        "latitude": 14.6937,
        "longitude": -17.4441,
        "gerantId": "gerant_456",
        "photos": ["https://api.samaminifoot.sn/photos/terrain_123_1.jpg"],
        "equipements": ["Éclairage", "Vestiaires", "Parking"],
        "prixHeure": 15000,
        "disponibilites": {
          "lundi": ["08:00-09:00", "09:00-10:00"],
          "mardi": ["16:00-17:00", "17:00-18:00"]
        },
        "notemoyenne": 4.5,
        "nombreAvis": 12,
        "dateCreation": "2024-01-10T08:00:00Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 5,
      "totalItems": 47,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

#### GET /terrains/{id}
Récupérer les détails d'un terrain spécifique.

#### POST /terrains
Créer un nouveau terrain (gérants uniquement).

#### PUT /terrains/{id}
Mettre à jour un terrain (gérants uniquement).

#### DELETE /terrains/{id}
Supprimer un terrain (gérants uniquement).

### 📅 Réservations

#### POST /reservations
Créer une nouvelle réservation.

**Request Body:**
```json
{
  "terrainId": "terrain_123",
  "date": "2024-01-20",
  "heureDebut": "16:00",
  "heureFin": "17:00",
  "modePaiement": "orange",
  "numeroTelephone": "771234567"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Réservation créée avec succès",
  "data": {
    "reservation": {
      "id": "res_789",
      "joueurId": "user_123",
      "terrainId": "terrain_123",
      "date": "2024-01-20T00:00:00Z",
      "heureDebut": "16:00",
      "heureFin": "17:00",
      "montant": 15000,
      "statut": "payee",
      "modePaiement": "orange",
      "transactionId": "tx_12345",
      "qrCode": "ABC123XYZ789",
      "dateCreation": "2024-01-15T10:30:00Z"
    },
    "recu": {
      "url": "https://api.samaminifoot.sn/recus/res_789.pdf"
    }
  }
}
```

#### GET /reservations
Récupérer les réservations de l'utilisateur.

**Query Parameters:**
- `statut` (optional): Filtrer par statut (enAttente, confirmee, payee, annulee, terminee)
- `dateDebut` (optional): Date de début (YYYY-MM-DD)
- `dateFin` (optional): Date de fin (YYYY-MM-DD)

#### GET /reservations/{id}
Récupérer les détails d'une réservation.

#### PUT /reservations/{id}/cancel
Annuler une réservation.

### 💳 Paiements

#### POST /payments/mobile-money
Traiter un paiement Mobile Money.

**Request Body:**
```json
{
  "montant": 15000,
  "modePaiement": "orange", // orange, wave, free
  "numeroTelephone": "771234567",
  "reservationId": "res_789"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Paiement traité avec succès",
  "data": {
    "transactionId": "tx_12345",
    "statut": "success",
    "montant": 15000,
    "dateTraitement": "2024-01-15T10:35:00Z"
  }
}
```

#### GET /payments/{transactionId}
Récupérer les détails d'une transaction.

### ⭐ Avis

#### POST /avis
Ajouter un avis sur un terrain.

**Request Body:**
```json
{
  "terrainId": "terrain_123",
  "reservationId": "res_789",
  "note": 5,
  "commentaire": "Excellent terrain, très bien entretenu !"
}
```

#### GET /terrains/{id}/avis
Récupérer les avis d'un terrain.

### 📊 Statistiques

#### GET /users/{id}/stats
Récupérer les statistiques d'un utilisateur.

**Response:**
```json
{
  "success": true,
  "data": {
    "matchsJoues": 25,
    "tempsJeu": 30, // en heures
    "terrainsVisites": 8,
    "montantDepense": 375000,
    "notesMoyennes": 4.2,
    "dernierMatch": "2024-01-10T16:00:00Z"
  }
}
```

## Codes d'erreur

### Erreurs d'authentification (401)
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Token d'authentification invalide"
  }
}
```

### Erreurs de validation (400)
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Données invalides",
    "details": {
      "telephone": ["Le numéro de téléphone est invalide"],
      "email": ["L'adresse email est requise"]
    }
  }
}
```

### Ressource non trouvée (404)
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Terrain non trouvé"
  }
}
```

### Conflit (409)
```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Ce créneau n'est plus disponible"
  }
}
```

### Erreur serveur (500)
```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Erreur interne du serveur"
  }
}
```

## Webhooks

### Confirmation de paiement
L'API envoie des webhooks pour confirmer les paiements.

**URL:** Configurée par l'application
**Method:** POST
**Body:**
```json
{
  "event": "payment.completed",
  "data": {
    "transactionId": "tx_12345",
    "reservationId": "res_789",
    "montant": 15000,
    "statut": "success",
    "timestamp": "2024-01-15T10:35:00Z"
  }
}
```

## Rate Limiting

- **Général:** 1000 requêtes/heure par utilisateur
- **Authentification:** 10 tentatives/minute
- **Paiements:** 5 requêtes/minute

## Environnements

### Production
- **Base URL:** `https://api.samaminifoot.sn/v1`
- **Documentation:** `https://docs.samaminifoot.sn`

### Staging
- **Base URL:** `https://staging-api.samaminifoot.sn/v1`
- **Documentation:** `https://staging-docs.samaminifoot.sn`

### Development
- **Base URL:** `http://localhost:3000/api/v1`
- **Documentation:** `http://localhost:3001/docs`

## SDK et bibliothèques

### Flutter/Dart
```dart
import 'package:sama_minifoot_api/sama_minifoot_api.dart';

final client = SamaMiniFootClient(
  baseUrl: 'https://api.samaminifoot.sn/v1',
  apiKey: 'your-api-key',
);

// Authentification
final authResult = await client.auth.login(
  identifier: 'user@example.com',
  password: 'password',
);

// Réservation
final reservation = await client.reservations.create(
  terrainId: 'terrain_123',
  date: DateTime.now(),
  heureDebut: '16:00',
  heureFin: '17:00',
);
```

## Support et contact

- **Email technique:** dev@samaminifoot.sn
- **Documentation:** https://docs.samaminifoot.sn
- **Status page:** https://status.samaminifoot.sn
- **GitHub:** https://github.com/samaminifoot/api