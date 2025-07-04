import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentification/auth_service.dart';
import '../../models/user.dart';
import 'dart:math';

class UsernameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Générer un username unique basé sur le nom
  Future<String> generateUniqueUsername(String name) async {
    // Nettoyer le nom : enlever espaces, accents, caractères spéciaux
    String baseUsername = _cleanName(name);
    
    // Vérifier si le username de base est disponible
    if (await isUsernameAvailable(baseUsername)) {
      return baseUsername;
    }
    
    // Sinon, ajouter des chiffres aléatoirement
    for (int i = 1; i <= 999; i++) {
      String candidate = '$baseUsername$i';
      if (await isUsernameAvailable(candidate)) {
        return candidate;
      }
    }
    
    // En dernier recours, utiliser un nombre aléatoire
    final random = Random();
    String fallback = '$baseUsername${random.nextInt(9999)}';
    return fallback;
  }

  // Nettoyer le nom pour créer un username valide
  String _cleanName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]'), '') // Enlever tout sauf lettres et chiffres
        .substring(0, name.length > 15 ? 15 : name.length); // Limiter à 15 caractères
  }

  // Vérifier si un username est disponible
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // Assigner automatiquement un username à l'utilisateur actuel
  Future<String> ensureUserHasUsername() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Si l'utilisateur a déjà un username, le retourner
    if (currentUser.username != null && currentUser.username!.isNotEmpty) {
      return currentUser.username!;
    }

    // Générer un nouveau username
    final newUsername = await generateUniqueUsername(currentUser.nom);
    
    // Mettre à jour l'utilisateur avec le nouveau username
    await _firestore
        .collection('users')
        .doc(currentUser.id)
        .update({'username': newUsername});

    // Recharger l'utilisateur pour mettre à jour le cache local
    await _authService.reloadCurrentUser();

    return newUsername;
  }

  // Permettre à l'utilisateur de changer son username
  Future<bool> updateUsername(String newUsername) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Nettoyer le nouveau username
    final cleanUsername = _cleanName(newUsername);
    
    if (cleanUsername.length < 3) {
      throw Exception('Le nom d\'utilisateur doit contenir au moins 3 caractères');
    }

    // Vérifier la disponibilité
    if (!await isUsernameAvailable(cleanUsername)) {
      throw Exception('Ce nom d\'utilisateur est déjà pris');
    }

    // Mettre à jour
    await _firestore
        .collection('users')
        .doc(currentUser.id)
        .update({'username': cleanUsername});

    // Recharger l'utilisateur pour mettre à jour le cache local
    await _authService.reloadCurrentUser();

    return true;
  }

  // Suggestions de usernames basées sur le nom
  Future<List<String>> getUsernameSuggestions(String name) async {
    final baseName = _cleanName(name);
    final suggestions = <String>[];
    
    // Ajouter le nom de base s'il est disponible
    if (await isUsernameAvailable(baseName)) {
      suggestions.add(baseName);
    }
    
    // Ajouter des variantes
    for (int i = 1; i <= 5; i++) {
      final variant = '$baseName$i';
      if (await isUsernameAvailable(variant)) {
        suggestions.add(variant);
      }
    }
    
    // Ajouter des variantes avec des mots
    final words = ['foot', 'player', 'pro', 'star', 'king'];
    for (final word in words) {
      final variant = '$baseName$word';
      if (await isUsernameAvailable(variant) && suggestions.length < 8) {
        suggestions.add(variant);
      }
    }
    
    return suggestions;
  }
}