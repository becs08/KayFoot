import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social/friend.dart';
import '../../models/social/friend_request.dart';
import '../../models/user.dart';
import '../Authentification/auth_service.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Collections
  CollectionReference get _friendsCollection => _firestore.collection('friends');
  CollectionReference get _friendRequestsCollection => _firestore.collection('friendRequests');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Rechercher un utilisateur par username
  Future<User?> searchUserByUsername(String username) async {
    try {
      final querySnapshot = await _usersCollection
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return User.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la recherche d\'utilisateur: $e');
    }
  }

  // Vérifier si un username est disponible
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await searchUserByUsername(username);
      return result == null;
    } catch (e) {
      return false;
    }
  }

  // Envoyer une demande d'ami
  Future<void> sendFriendRequest({
    required String receiverUsername,
    String? message,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Rechercher l'utilisateur destinataire
      final receiver = await searchUserByUsername(receiverUsername);
      if (receiver == null) {
        throw Exception('Utilisateur non trouvé');
      }

      if (receiver.id == currentUser.id) {
        throw Exception('Vous ne pouvez pas vous ajouter vous-même');
      }

      // Vérifier si ils ne sont pas déjà amis
      final isAlreadyFriend = await areFriends(currentUser.id, receiver.id);
      if (isAlreadyFriend) {
        throw Exception('Vous êtes déjà amis');
      }

      // Vérifier s'il n'y a pas déjà une demande en attente
      final existingRequest = await _getExistingFriendRequest(currentUser.id, receiver.id);
      if (existingRequest != null && existingRequest.isPending) {
        throw Exception('Une demande d\'ami est déjà en attente');
      }

      // Créer la demande d'ami
      final friendRequest = FriendRequest(
        id: '',
        senderId: currentUser.id,
        senderUsername: currentUser.username ?? '',
        senderName: currentUser.nom,
        senderAvatar: currentUser.photo,
        receiverId: receiver.id,
        receiverUsername: receiver.username ?? '',
        receiverName: receiver.nom,
        receiverAvatar: receiver.photo,
        status: FriendRequestStatus.pending,
        sentAt: DateTime.now(),
        message: message,
      );

      await _friendRequestsCollection.add(friendRequest.toFirestore());
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de la demande: $e');
    }
  }

  // Récupérer les demandes d'ami reçues
  Stream<List<FriendRequest>> getReceivedFriendRequests() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('receiverId', isEqualTo: currentUser.id)
        .where('status', isEqualTo: 'pending')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc))
            .toList());
  }

  // Récupérer les demandes d'ami envoyées
  Stream<List<FriendRequest>> getSentFriendRequests() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('senderId', isEqualTo: currentUser.id)
        .where('status', isEqualTo: 'pending')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc))
            .toList());
  }

  // Accepter une demande d'ami
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final requestDoc = await _friendRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Demande d\'ami non trouvée');
      }

      final request = FriendRequest.fromFirestore(requestDoc);
      
      // Mettre à jour le statut de la demande
      await _friendRequestsCollection.doc(requestId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.now(),
      });

      // Créer l'amitié dans les deux sens
      final batch = _firestore.batch();

      // Ajouter l'ami pour l'expéditeur
      final friend1 = Friend(
        id: '',
        userId: request.senderId,
        friendId: request.receiverId,
        friendUsername: request.receiverUsername,
        friendName: request.receiverName,
        friendAvatar: request.receiverAvatar,
        addedAt: DateTime.now(),
      );

      // Ajouter l'ami pour le destinataire
      final friend2 = Friend(
        id: '',
        userId: request.receiverId,
        friendId: request.senderId,
        friendUsername: request.senderUsername,
        friendName: request.senderName,
        friendAvatar: request.senderAvatar,
        addedAt: DateTime.now(),
      );

      batch.set(_friendsCollection.doc(), friend1.toFirestore());
      batch.set(_friendsCollection.doc(), friend2.toFirestore());

      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de l\'acceptation de la demande: $e');
    }
  }

  // Refuser une demande d'ami
  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _friendRequestsCollection.doc(requestId).update({
        'status': 'declined',
        'respondedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Erreur lors du refus de la demande: $e');
    }
  }

  // Annuler une demande d'ami envoyée
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _friendRequestsCollection.doc(requestId).update({
        'status': 'cancelled',
        'respondedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'annulation de la demande: $e');
    }
  }

  // Récupérer la liste des amis
  Stream<List<Friend>> getFriends() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _friendsCollection
        .where('userId', isEqualTo: currentUser.id)
        .where('isBlocked', isEqualTo: false)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friend.fromFirestore(doc))
            .toList());
  }

  // Supprimer un ami
  Future<void> removeFriend(String friendId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Supprimer l'amitié dans les deux sens
      final batch = _firestore.batch();

      // Supprimer pour l'utilisateur actuel
      final friend1Query = await _friendsCollection
          .where('userId', isEqualTo: currentUser.id)
          .where('friendId', isEqualTo: friendId)
          .get();

      // Supprimer pour l'ami
      final friend2Query = await _friendsCollection
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUser.id)
          .get();

      for (var doc in friend1Query.docs) {
        batch.delete(doc.reference);
      }

      for (var doc in friend2Query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'ami: $e');
    }
  }

  // Bloquer un ami
  Future<void> blockFriend(String friendId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final friendQuery = await _friendsCollection
          .where('userId', isEqualTo: currentUser.id)
          .where('friendId', isEqualTo: friendId)
          .get();

      for (var doc in friendQuery.docs) {
        await doc.reference.update({'isBlocked': true});
      }
    } catch (e) {
      throw Exception('Erreur lors du blocage de l\'ami: $e');
    }
  }

  // Débloquer un ami
  Future<void> unblockFriend(String friendId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final friendQuery = await _friendsCollection
          .where('userId', isEqualTo: currentUser.id)
          .where('friendId', isEqualTo: friendId)
          .get();

      for (var doc in friendQuery.docs) {
        await doc.reference.update({'isBlocked': false});
      }
    } catch (e) {
      throw Exception('Erreur lors du déblocage de l\'ami: $e');
    }
  }

  // Vérifier si deux utilisateurs sont amis
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final friendQuery = await _friendsCollection
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .where('isBlocked', isEqualTo: false)
          .get();

      return friendQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Récupérer une demande d'ami existante
  Future<FriendRequest?> _getExistingFriendRequest(String senderId, String receiverId) async {
    try {
      final querySnapshot = await _friendRequestsCollection
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return FriendRequest.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Compter les demandes en attente
  Future<int> getPendingRequestsCount() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return 0;

      final querySnapshot = await _friendRequestsCollection
          .where('receiverId', isEqualTo: currentUser.id)
          .where('status', isEqualTo: 'pending')
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}