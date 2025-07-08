import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';

class UserService {
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache des utilisateurs pour éviter les requêtes répétées
  final Map<String, User> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Récupère un utilisateur par son ID
  Future<User?> getUserById(String userId) async {
    try {
      // Vérifier le cache
      if (_userCache.containsKey(userId)) {
        final cachedTime = _cacheTimestamps[userId];
        if (cachedTime != null && 
            DateTime.now().difference(cachedTime) < _cacheExpiry) {
          print('👤 Utilisateur récupéré depuis le cache: $userId');
          return _userCache[userId];
        }
      }

      print('👤 Récupération utilisateur depuis Firestore: $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('❌ Utilisateur $userId non trouvé');
        return null;
      }

      final user = User.fromFirestore(doc.data()!, doc.id);
      
      // Mettre en cache
      _userCache[userId] = user;
      _cacheTimestamps[userId] = DateTime.now();

      print('✅ Utilisateur récupéré: ${user.nom} (${user.email}) et mis en cache');
      return user;

    } catch (e) {
      print('❌ Erreur getUserById: $e');
      return null;
    }
  }

  /// Récupère plusieurs utilisateurs par leurs IDs
  Future<Map<String, User>> getUsersByIds(List<String> userIds) async {
    try {
      final result = <String, User>{};
      final idsToFetch = <String>[];

      // Vérifier le cache d'abord
      for (final userId in userIds) {
        if (_userCache.containsKey(userId)) {
          final cachedTime = _cacheTimestamps[userId];
          if (cachedTime != null && 
              DateTime.now().difference(cachedTime) < _cacheExpiry) {
            result[userId] = _userCache[userId]!;
            continue;
          }
        }
        idsToFetch.add(userId);
      }

      // Récupérer les utilisateurs manquants
      if (idsToFetch.isNotEmpty) {
        print('👥 Récupération de ${idsToFetch.length} utilisateurs depuis Firestore');

        // Firestore limite les requêtes "whereIn" à 10 éléments
        const batchSize = 10;
        for (int i = 0; i < idsToFetch.length; i += batchSize) {
          final batch = idsToFetch.skip(i).take(batchSize).toList();
          
          final query = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in query.docs) {
            final user = User.fromFirestore(doc.data(), doc.id);
            result[doc.id] = user;
            
            // Mettre en cache
            _userCache[doc.id] = user;
            _cacheTimestamps[doc.id] = DateTime.now();
          }
        }
      }

      print('✅ ${result.length} utilisateurs récupérés au total');
      return result;

    } catch (e) {
      print('❌ Erreur getUsersByIds: $e');
      return {};
    }
  }

  /// Recherche des utilisateurs par nom ou email
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.length < 2) return [];

      print('🔍 Recherche utilisateurs: "$query"');

      // Recherche par nom (case-insensitive)
      final queryLower = query.toLowerCase();
      
      final querySnapshot = await _firestore
          .collection('users')
          .where('nom', isGreaterThanOrEqualTo: queryLower)
          .where('nom', isLessThan: queryLower + 'z')
          .limit(20)
          .get();

      final users = querySnapshot.docs.map((doc) {
        final user = User.fromFirestore(doc.data(), doc.id);
        
        // Mettre en cache
        _userCache[doc.id] = user;
        _cacheTimestamps[doc.id] = DateTime.now();
        
        return user;
      }).toList();

      print('✅ ${users.length} utilisateurs trouvés');
      return users;

    } catch (e) {
      print('❌ Erreur searchUsers: $e');
      return [];
    }
  }

  /// Vide le cache des utilisateurs
  void clearCache() {
    _userCache.clear();
    _cacheTimestamps.clear();
    print('🗑️ Cache utilisateurs vidé');
  }

  /// Précharge les utilisateurs pour une liste de réservations
  Future<void> preloadUsersForReservations(List<String> joueurIds) async {
    final uniqueIds = joueurIds.toSet().toList();
    await getUsersByIds(uniqueIds);
    print('🚀 ${uniqueIds.length} utilisateurs préchargés');
  }

  /// Récupère un utilisateur depuis le cache (synchrone)
  User? getCachedUser(String userId) {
    if (_userCache.containsKey(userId)) {
      final cachedTime = _cacheTimestamps[userId];
      if (cachedTime != null && 
          DateTime.now().difference(cachedTime) < _cacheExpiry) {
        return _userCache[userId];
      }
    }
    return null;
  }

  /// Force le rechargement d'un utilisateur spécifique
  Future<User?> reloadUser(String userId) async {
    // Supprimer du cache d'abord
    _userCache.remove(userId);
    _cacheTimestamps.remove(userId);
    
    // Recharger depuis Firestore
    return await getUserById(userId);
  }
}