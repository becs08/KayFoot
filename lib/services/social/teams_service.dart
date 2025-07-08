import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/social/team.dart';
import '../../models/social/team_member.dart';
import '../../models/social/team_post.dart';
import '../../models/social/team_event.dart';
import '../../models/social/team_request.dart';
import '../../models/user.dart';
import '../Authentification/auth_service.dart';
import '../cache/cache_service.dart';
import 'dart:math';

class TeamsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  CacheService? _cacheService;

  // Collections
  CollectionReference get _teamsCollection => _firestore.collection('teams');
  CollectionReference get _teamMembersCollection => _firestore.collection('teamMembers');
  CollectionReference get _teamPostsCollection => _firestore.collection('teamPosts');
  CollectionReference get _teamEventsCollection => _firestore.collection('teamEvents');
  CollectionReference get _teamRequestsCollection => _firestore.collection('teamRequests');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Initialiser le service de cache
  Future<void> _initCacheService() async {
    _cacheService ??= await CacheService.getInstance();
  }

  // Créer une nouvelle team
  Future<String> createTeam({
    required String name,
    required String description,
    TeamPrivacy privacy = TeamPrivacy.public,
    List<String> tags = const [],
    int maxMembers = 50,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si le nom de la team n'est pas déjà pris
      final existingTeam = await _teamsCollection
          .where('name', isEqualTo: name.trim())
          .get();

      if (existingTeam.docs.isNotEmpty) {
        throw Exception('Ce nom de team est déjà utilisé');
      }

      final now = DateTime.now();
      
      // Créer la team
      final team = Team(
        id: '',
        name: name.trim(),
        description: description.trim(),
        creatorId: currentUser.id,
        creatorUsername: currentUser.username ?? '',
        adminIds: [currentUser.id],
        privacy: privacy,
        createdAt: now,
        updatedAt: now,
        memberCount: 1,
        maxMembers: maxMembers,
        tags: tags,
      );

      final teamRef = await _teamsCollection.add(team.toFirestore());

      // Ajouter le créateur comme membre avec un ID spécifique pour faciliter les requêtes
      final teamMemberId = '${currentUser.id}_${teamRef.id}';
      final teamMember = TeamMember(
        id: teamMemberId,
        teamId: teamRef.id,
        userId: currentUser.id,
        username: currentUser.username ?? '',
        name: currentUser.nom,
        avatar: currentUser.photo,
        role: TeamMemberRole.creator,
        status: TeamMemberStatus.active,
        joinedAt: now,
        lastActiveAt: now,
      );

      await _teamMembersCollection.doc(teamMemberId).set(teamMember.toFirestore());

      // Invalider le cache des teams de l'utilisateur
      await _invalidateAllTeamsCache();

      return teamRef.id;
    } catch (e) {
      throw Exception('Erreur lors de la création de la team: $e');
    }
  }

  // Récupérer toutes les teams visibles publiquement (publiques et privées)
  Stream<List<Team>> getPublicTeams({
    String? searchQuery,
    List<String>? tags,
    int limit = 20,
  }) {
    Query query = _teamsCollection
        .where('privacy', whereIn: ['public', 'private'])
        .orderBy('memberCount', descending: true);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Note: Firestore ne supporte pas les recherches par contient
      // On pourrait implémenter une recherche plus sophistiquée avec Algolia
      query = query
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }

    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Team.fromFirestore(doc))
            .toList());
  }

  // Récupérer les teams de l'utilisateur avec cache
  Future<List<Team>> getUserTeamsCached({bool forceRefresh = false}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return [];

      await _initCacheService();

      // Essayer de récupérer depuis le cache d'abord
      if (!forceRefresh) {
        final cachedData = _cacheService?.getUserTeams();
        if (cachedData != null && cachedData.isNotEmpty) {
          print('📱 Teams utilisateur récupérées depuis le cache');
          return cachedData.map((teamData) => Team(
            id: teamData['id'],
            name: teamData['name'],
            description: teamData['description'],
            avatar: teamData['avatar'],
            creatorId: teamData['creatorId'],
            creatorUsername: teamData['creatorUsername'],
            adminIds: List<String>.from(teamData['adminIds']),
            privacy: TeamPrivacy.values.firstWhere(
              (e) => e.toString() == 'TeamPrivacy.${teamData['privacy']}',
              orElse: () => TeamPrivacy.public,
            ),
            createdAt: DateTime.parse(teamData['createdAt']),
            updatedAt: DateTime.parse(teamData['updatedAt']),
            memberCount: teamData['memberCount'],
            maxMembers: teamData['maxMembers'],
            settings: teamData['settings'],
            tags: List<String>.from(teamData['tags']),
          )).toList();
        }
      }

      // Récupérer depuis Firestore
      print('🔥 Récupération teams utilisateur depuis Firestore');
      final memberSnapshot = await _teamMembersCollection
          .where('userId', isEqualTo: currentUser.id)
          .where('status', isEqualTo: 'active')
          .get();

      final teamIds = memberSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['teamId'] as String)
          .toList();

      if (teamIds.isEmpty) return [];

      final teamsQuery = await _teamsCollection
          .where(FieldPath.documentId, whereIn: teamIds)
          .get();

      final teams = teamsQuery.docs
          .map((doc) => Team.fromFirestore(doc))
          .toList();

      // Sauvegarder dans le cache
      final teamsData = teams.map((team) => {
        'id': team.id,
        'name': team.name,
        'description': team.description,
        'avatar': team.avatar,
        'creatorId': team.creatorId,
        'creatorUsername': team.creatorUsername,
        'adminIds': team.adminIds,
        'privacy': team.privacy.toString().split('.').last,
        'createdAt': team.createdAt.toIso8601String(),
        'updatedAt': team.updatedAt.toIso8601String(),
        'memberCount': team.memberCount,
        'maxMembers': team.maxMembers,
        'settings': team.settings,
        'tags': team.tags,
      }).toList();

      await _cacheService?.saveUserTeams(teamsData);

      return teams;
    } catch (e) {
      print('Erreur getUserTeamsCached: $e');
      return [];
    }
  }

  // Récupérer les teams de l'utilisateur (Stream version pour l'UI)
  Stream<List<Team>> getUserTeams() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _teamMembersCollection
        .where('userId', isEqualTo: currentUser.id)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
      final teamIds = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['teamId'] as String)
          .toList();

      if (teamIds.isEmpty) return <Team>[];

      final teamsQuery = await _teamsCollection
          .where(FieldPath.documentId, whereIn: teamIds)
          .get();

      return teamsQuery.docs
          .map((doc) => Team.fromFirestore(doc))
          .toList();
    });
  }

  // Récupérer une team par ID avec cache
  Future<Team?> getTeamById(String teamId, {bool forceRefresh = false}) async {
    try {
      await _initCacheService();

      // Essayer de récupérer depuis le cache d'abord
      if (!forceRefresh) {
        final cachedData = _cacheService?.getTeamDetails(teamId);
        if (cachedData != null) {
          print('📱 Team $teamId récupérée depuis le cache');
          return Team(
            id: cachedData['id'],
            name: cachedData['name'],
            description: cachedData['description'],
            avatar: cachedData['avatar'],
            creatorId: cachedData['creatorId'],
            creatorUsername: cachedData['creatorUsername'],
            adminIds: List<String>.from(cachedData['adminIds']),
            privacy: TeamPrivacy.values.firstWhere(
              (e) => e.toString() == 'TeamPrivacy.${cachedData['privacy']}',
              orElse: () => TeamPrivacy.public,
            ),
            createdAt: DateTime.parse(cachedData['createdAt']),
            updatedAt: DateTime.parse(cachedData['updatedAt']),
            memberCount: cachedData['memberCount'],
            maxMembers: cachedData['maxMembers'],
            settings: cachedData['settings'],
            tags: List<String>.from(cachedData['tags']),
          );
        }
      }

      // Récupérer depuis Firestore
      print('🔥 Récupération team $teamId depuis Firestore');
      final doc = await _teamsCollection.doc(teamId).get();
      if (doc.exists) {
        final team = Team.fromFirestore(doc);
        
        // Synchroniser le compteur de membres si nécessaire
        await _syncMemberCount(teamId);
        
        // Récupérer le nom d'utilisateur du créateur si manquant
        if (team.creatorUsername.isEmpty) {
          final creatorDoc = await _usersCollection.doc(team.creatorId).get();
          if (creatorDoc.exists) {
            final creatorData = creatorDoc.data() as Map<String, dynamic>;
            await _teamsCollection.doc(teamId).update({
              'creatorUsername': creatorData['username'] ?? '',
            });
          }
        }
        
        // Retourner la team mise à jour
        final updatedDoc = await _teamsCollection.doc(teamId).get();
        final finalTeam = Team.fromFirestore(updatedDoc);

        // Sauvegarder dans le cache
        await _cacheService?.saveTeamDetails(teamId, {
          'id': finalTeam.id,
          'name': finalTeam.name,
          'description': finalTeam.description,
          'avatar': finalTeam.avatar,
          'creatorId': finalTeam.creatorId,
          'creatorUsername': finalTeam.creatorUsername,
          'adminIds': finalTeam.adminIds,
          'privacy': finalTeam.privacy.toString().split('.').last,
          'createdAt': finalTeam.createdAt.toIso8601String(),
          'updatedAt': finalTeam.updatedAt.toIso8601String(),
          'memberCount': finalTeam.memberCount,
          'maxMembers': finalTeam.maxMembers,
          'settings': finalTeam.settings,
          'tags': finalTeam.tags,
        });

        return finalTeam;
      }
      return null;
    } catch (e) {
      print('Erreur getTeamById: $e');
      return null;
    }
  }

  // Synchroniser le compteur de membres
  Future<void> _syncMemberCount(String teamId) async {
    try {
      final membersSnapshot = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('status', isEqualTo: 'active')
          .get();
      
      final actualCount = membersSnapshot.docs.length;
      
      await _teamsCollection.doc(teamId).update({
        'memberCount': actualCount,
      });
    } catch (e) {
      print('Erreur syncMemberCount: $e');
    }
  }

  // Récupérer les membres d'une team
  Stream<List<TeamMember>> getTeamMembers(String teamId) {
    return _teamMembersCollection
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'active')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamMember.fromFirestore(doc))
            .toList());
  }

  // Rejoindre une team (seulement pour les teams publiques)
  Future<void> joinTeam(String teamId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final team = await getTeamById(teamId);
      if (team == null) {
        throw Exception('Team non trouvée');
      }

      // Vérifier les permissions selon le type de team
      if (team.isPrivate) {
        throw Exception('Cette team est privée. Vous devez envoyer une demande d\'adhésion.');
      }

      if (team.isPersonal) {
        throw Exception('Cette team est personnelle. Vous devez être invité par un admin.');
      }

      if (!team.isPublic) {
        throw Exception('Vous ne pouvez pas rejoindre cette team directement.');
      }

      // Vérifier si l'utilisateur n'est pas déjà membre
      final existingMember = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: currentUser.id)
          .get();

      if (existingMember.docs.isNotEmpty) {
        throw Exception('Vous êtes déjà membre de cette team');
      }

      // Vérifier si la team n'est pas pleine
      if (team.isFull) {
        throw Exception('Cette team est complète');
      }

      final now = DateTime.now();

      // Ajouter le membre avec un ID spécifique
      final teamMemberId = '${currentUser.id}_$teamId';
      final teamMember = TeamMember(
        id: teamMemberId,
        teamId: teamId,
        userId: currentUser.id,
        username: currentUser.username ?? '',
        name: currentUser.nom,
        avatar: currentUser.photo,
        role: TeamMemberRole.member,
        status: TeamMemberStatus.active,
        joinedAt: now,
        lastActiveAt: now,
      );

      await _teamMembersCollection.doc(teamMemberId).set(teamMember.toFirestore());

      // Mettre à jour le compteur de membres
      await _teamsCollection.doc(teamId).update({
        'memberCount': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Invalider le cache
      await _invalidateTeamCache(teamId);
    } catch (e) {
      throw Exception('Erreur lors de l\'adhésion à la team: $e');
    }
  }

  // Quitter une team
  Future<void> leaveTeam(String teamId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final memberQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: currentUser.id)
          .get();

      if (memberQuery.docs.isEmpty) {
        throw Exception('Vous n\'êtes pas membre de cette team');
      }

      final member = TeamMember.fromFirestore(memberQuery.docs.first);
      
      if (member.isCreator) {
        throw Exception('Le créateur ne peut pas quitter la team. Transférez d\'abord la propriété ou supprimez la team.');
      }

      // Mettre à jour le statut du membre
      await memberQuery.docs.first.reference.update({
        'status': 'left',
        'lastActiveAt': Timestamp.now(),
      });

      // Mettre à jour le compteur de membres
      await _teamsCollection.doc(teamId).update({
        'memberCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.now(),
      });

      // Invalider le cache
      await _invalidateTeamCache(teamId);
    } catch (e) {
      throw Exception('Erreur lors de la sortie de la team: $e');
    }
  }

  // Ajouter un ami à une team
  Future<void> inviteFriendToTeam(String teamId, String friendId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur est admin de la team
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canManageMembers()) {
        throw Exception('Vous n\'avez pas les permissions pour inviter des membres');
      }

      // Vérifier si l'ami n'est pas déjà membre
      final existingMember = await getUserTeamMember(teamId, friendId);
      if (existingMember != null) {
        throw Exception('Cette personne est déjà membre de la team');
      }

      // Récupérer les infos de l'ami
      final friendDoc = await _usersCollection.doc(friendId).get();
      if (!friendDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }

      final friend = User.fromFirestore(friendDoc.data() as Map<String, dynamic>, friendDoc.id);
      final now = DateTime.now();

      // Ajouter le membre
      final teamMember = TeamMember(
        id: '',
        teamId: teamId,
        userId: friendId,
        username: friend.username ?? '',
        name: friend.nom,
        avatar: friend.photo,
        role: TeamMemberRole.member,
        status: TeamMemberStatus.active,
        joinedAt: now,
        lastActiveAt: now,
        joinedBy: currentUser.id,
      );

      await _teamMembersCollection.add(teamMember.toFirestore());

      // Mettre à jour le compteur de membres
      await _teamsCollection.doc(teamId).update({
        'memberCount': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Invalider le cache
      await _invalidateTeamCache(teamId);
    } catch (e) {
      throw Exception('Erreur lors de l\'invitation: $e');
    }
  }

  // Promouvoir un membre en admin
  Future<void> promoteToAdmin(String teamId, String userId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur est admin
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canManageMembers()) {
        throw Exception('Vous n\'avez pas les permissions pour promouvoir des membres');
      }

      // Récupérer le membre à promouvoir
      final memberToPromote = await getUserTeamMember(teamId, userId);
      if (memberToPromote == null) {
        throw Exception('Membre non trouvé');
      }

      // Mettre à jour le rôle
      final memberQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: userId)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        await memberQuery.docs.first.reference.update({
          'role': 'admin',
        });

        // Ajouter à la liste des admins de la team
        await _teamsCollection.doc(teamId).update({
          'adminIds': FieldValue.arrayUnion([userId]),
          'updatedAt': Timestamp.now(),
        });

        // Invalider le cache
        await _invalidateTeamCache(teamId);
      }
    } catch (e) {
      throw Exception('Erreur lors de la promotion: $e');
    }
  }

  // Supprimer un membre de la team
  Future<void> removeMember(String teamId, String userId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur est admin
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canManageMembers()) {
        throw Exception('Vous n\'avez pas les permissions pour supprimer des membres');
      }

      // Récupérer le membre à supprimer
      final memberToRemove = await getUserTeamMember(teamId, userId);
      if (memberToRemove == null) {
        throw Exception('Membre non trouvé');
      }

      if (memberToRemove.isCreator) {
        throw Exception('Impossible de supprimer le créateur de la team');
      }

      // Mettre à jour le statut du membre
      final memberQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: userId)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        await memberQuery.docs.first.reference.update({
          'status': 'banned',
          'lastActiveAt': Timestamp.now(),
        });

        // Retirer des admins si c'était un admin
        await _teamsCollection.doc(teamId).update({
          'adminIds': FieldValue.arrayRemove([userId]),
          'memberCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        });

        // Invalider le cache
        await _invalidateTeamCache(teamId);
      }
    } catch (e) {
      throw Exception('Erreur lors de la suppression du membre: $e');
    }
  }

  // Mettre à jour les informations de la team
  Future<void> updateTeam(String teamId, {
    String? name,
    String? description,
    String? avatar,
    TeamPrivacy? privacy,
    List<String>? tags,
    int? maxMembers,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur est admin
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canEditTeam()) {
        throw Exception('Vous n\'avez pas les permissions pour modifier cette team');
      }

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name.trim();
      if (description != null) updates['description'] = description.trim();
      if (avatar != null) updates['avatar'] = avatar;
      if (privacy != null) updates['privacy'] = privacy.toString().split('.').last;
      if (tags != null) updates['tags'] = tags;
      if (maxMembers != null) updates['maxMembers'] = maxMembers;

      await _teamsCollection.doc(teamId).update(updates);

      // Invalider le cache
      await _invalidateTeamCache(teamId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la team: $e');
    }
  }

  // Supprimer une team
  Future<void> deleteTeam(String teamId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur est le créateur
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canDeleteTeam()) {
        throw Exception('Seul le créateur peut supprimer la team');
      }

      final batch = _firestore.batch();

      // Supprimer tous les membres
      final membersQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .get();

      for (var doc in membersQuery.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer tous les posts
      final postsQuery = await _teamPostsCollection
          .where('teamId', isEqualTo: teamId)
          .get();

      for (var doc in postsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer tous les événements
      final eventsQuery = await _teamEventsCollection
          .where('teamId', isEqualTo: teamId)
          .get();

      for (var doc in eventsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer la team
      batch.delete(_teamsCollection.doc(teamId));

      await batch.commit();

      // Invalider le cache
      await _invalidateTeamCache(teamId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la team: $e');
    }
  }

  // Récupérer un membre spécifique d'une team avec cache
  Future<TeamMember?> getUserTeamMember(String teamId, String userId, {bool forceRefresh = false}) async {
    try {
      await _initCacheService();

      // Essayer de récupérer depuis le cache d'abord
      if (!forceRefresh) {
        final cachedMembers = _cacheService?.getTeamMembers(teamId);
        if (cachedMembers != null) {
          final memberData = cachedMembers.firstWhere(
            (member) => member['userId'] == userId && member['status'] == 'active',
            orElse: () => <String, dynamic>{},
          );
          
          if (memberData.isNotEmpty) {
            print('📱 Membre $userId de la team $teamId récupéré depuis le cache');
            return TeamMember(
              id: memberData['id'],
              teamId: memberData['teamId'],
              userId: memberData['userId'],
              username: memberData['username'],
              name: memberData['name'],
              avatar: memberData['avatar'],
              role: TeamMemberRole.values.firstWhere(
                (e) => e.toString() == 'TeamMemberRole.${memberData['role']}',
                orElse: () => TeamMemberRole.member,
              ),
              status: TeamMemberStatus.values.firstWhere(
                (e) => e.toString() == 'TeamMemberStatus.${memberData['status']}',
                orElse: () => TeamMemberStatus.active,
              ),
              joinedAt: DateTime.parse(memberData['joinedAt']),
              lastActiveAt: memberData['lastActiveAt'] != null 
                  ? DateTime.parse(memberData['lastActiveAt'])
                  : null,
              joinedBy: memberData['joinedBy'],
              permissions: memberData['permissions'],
            );
          }
        }
      }

      // Récupérer depuis Firestore
      final memberQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      if (memberQuery.docs.isNotEmpty) {
        final member = TeamMember.fromFirestore(memberQuery.docs.first);
        
        // Mettre à jour le cache des membres de cette team
        await _cacheTeamMembers(teamId);
        
        return member;
      }
      return null;
    } catch (e) {
      print('Erreur getUserTeamMember: $e');
      return null;
    }
  }

  // Mettre en cache tous les membres d'une team
  Future<void> _cacheTeamMembers(String teamId) async {
    try {
      final membersQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('status', isEqualTo: 'active')
          .get();

      final membersData = membersQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'teamId': data['teamId'],
          'userId': data['userId'],
          'username': data['username'],
          'name': data['name'],
          'avatar': data['avatar'],
          'role': data['role'],
          'status': data['status'],
          'joinedAt': (data['joinedAt'] as Timestamp).toDate().toIso8601String(),
          'lastActiveAt': data['lastActiveAt'] != null 
              ? (data['lastActiveAt'] as Timestamp).toDate().toIso8601String()
              : null,
          'joinedBy': data['joinedBy'],
          'permissions': data['permissions'],
        };
      }).toList();

      await _cacheService?.saveTeamMembers(teamId, membersData);
    } catch (e) {
      print('Erreur _cacheTeamMembers: $e');
    }
  }

  // Vérifier si l'utilisateur est membre d'une team
  Future<bool> isUserMemberOfTeam(String teamId, String userId) async {
    final member = await getUserTeamMember(teamId, userId);
    return member != null && member.isActive;
  }

  // Générer un code d'invitation
  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Méthode pour réparer une team existante
  Future<void> repairTeam(String teamId) async {
    try {
      final teamDoc = await _teamsCollection.doc(teamId).get();
      if (!teamDoc.exists) return;

      final teamData = teamDoc.data() as Map<String, dynamic>;
      final creatorId = teamData['creatorId'] as String;
      
      // Vérifier si le créateur est dans les membres
      final creatorMemberQuery = await _teamMembersCollection
          .where('teamId', isEqualTo: teamId)
          .where('userId', isEqualTo: creatorId)
          .get();
      
      if (creatorMemberQuery.docs.isEmpty) {
        // Ajouter le créateur comme membre
        final creatorDoc = await _usersCollection.doc(creatorId).get();
        if (creatorDoc.exists) {
          final creatorData = creatorDoc.data() as Map<String, dynamic>;
          final teamMemberId = '${creatorId}_$teamId';
          
          await _teamMembersCollection.doc(teamMemberId).set({
            'id': teamMemberId,
            'teamId': teamId,
            'userId': creatorId,
            'username': creatorData['username'] ?? '',
            'name': creatorData['nom'] ?? '',
            'avatar': creatorData['photo'],
            'role': 'creator',
            'status': 'active',
            'joinedAt': teamData['createdAt'] ?? Timestamp.now(),
            'lastActiveAt': Timestamp.now(),
          });
        }
      }
      
      // Synchroniser le compteur de membres
      await _syncMemberCount(teamId);
      
      // Mettre à jour le nom d'utilisateur du créateur si manquant
      if (teamData['creatorUsername'] == null || teamData['creatorUsername'].isEmpty) {
        final creatorDoc = await _usersCollection.doc(creatorId).get();
        if (creatorDoc.exists) {
          final creatorUserData = creatorDoc.data() as Map<String, dynamic>;
          await _teamsCollection.doc(teamId).update({
            'creatorUsername': creatorUserData['username'] ?? '',
          });
        }
      }
    } catch (e) {
      print('Erreur repairTeam: $e');
    }
  }

  // === MÉTHODES POUR LES DEMANDES ET INVITATIONS ===

  // Envoyer une demande pour rejoindre une team privée
  Future<void> requestToJoinTeam(String teamId, {String? message}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final team = await getTeamById(teamId);
      if (team == null) {
        throw Exception('Team non trouvée');
      }

      if (!team.isPrivate) {
        throw Exception('Vous pouvez rejoindre cette team directement');
      }

      // Vérifier si l'utilisateur n'est pas déjà membre
      final isMember = await isUserMemberOfTeam(teamId, currentUser.id);
      if (isMember) {
        throw Exception('Vous êtes déjà membre de cette team');
      }

      // Vérifier s'il n'y a pas déjà une demande en attente
      final existingRequest = await _teamRequestsCollection
          .where('teamId', isEqualTo: teamId)
          .where('fromUserId', isEqualTo: currentUser.id)
          .where('type', isEqualTo: 'joinRequest')
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Vous avez déjà une demande en attente pour cette team');
      }

      final now = DateTime.now();
      
      // Créer une demande pour chaque admin de la team
      for (String adminId in team.adminIds) {
        // Récupérer les infos de l'admin
        final adminDoc = await _usersCollection.doc(adminId).get();
        String adminUsername = '';
        String adminName = '';
        
        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminUsername = adminData['username'] ?? '';
          adminName = adminData['nom'] ?? '';
        }
        
        final request = TeamRequest(
          id: '',
          teamId: teamId,
          teamName: team.name,
          fromUserId: currentUser.id,
          fromUsername: currentUser.username ?? '',
          fromUserName: currentUser.nom,
          fromUserAvatar: currentUser.photo,
          toUserId: adminId,
          toUsername: adminUsername,
          toUserName: adminName,
          type: TeamRequestType.joinRequest,
          message: message,
          createdAt: now,
        );

        await _teamRequestsCollection.add(request.toFirestore());
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de la demande: $e');
    }
  }

  // Inviter un utilisateur par son pseudo
  Future<void> inviteUserToTeam(String teamId, String username, {String? message}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Vérifier si l'utilisateur peut inviter (admin ou créateur)
      final userMember = await getUserTeamMember(teamId, currentUser.id);
      if (userMember == null || !userMember.canManageMembers()) {
        throw Exception('Vous n\'avez pas les permissions pour inviter des membres');
      }

      // Trouver l'utilisateur par son pseudo
      final userQuery = await _usersCollection
          .where('username', isEqualTo: username)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Utilisateur avec le pseudo "$username" non trouvé');
      }

      final targetUserData = userQuery.docs.first.data() as Map<String, dynamic>;
      final targetUserId = userQuery.docs.first.id;

      // Vérifier si l'utilisateur n'est pas déjà membre
      final isMember = await isUserMemberOfTeam(teamId, targetUserId);
      if (isMember) {
        throw Exception('Cet utilisateur est déjà membre de la team');
      }

      // Vérifier s'il n'y a pas déjà une invitation en attente
      final existingInvitation = await _teamRequestsCollection
          .where('teamId', isEqualTo: teamId)
          .where('toUserId', isEqualTo: targetUserId)
          .where('type', isEqualTo: 'invitation')
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        throw Exception('Une invitation est déjà en attente pour cet utilisateur');
      }

      final team = await getTeamById(teamId);
      if (team == null) {
        throw Exception('Team non trouvée');
      }

      final now = DateTime.now();
      final invitation = TeamRequest(
        id: '',
        teamId: teamId,
        teamName: team.name,
        fromUserId: currentUser.id,
        fromUsername: currentUser.username ?? '',
        fromUserName: currentUser.nom,
        fromUserAvatar: currentUser.photo,
        toUserId: targetUserId,
        toUsername: targetUserData['username'] ?? '',
        toUserName: targetUserData['nom'] ?? '',
        toUserAvatar: targetUserData['photo'],
        type: TeamRequestType.invitation,
        message: message,
        createdAt: now,
      );

      await _teamRequestsCollection.add(invitation.toFirestore());
    } catch (e) {
      throw Exception('Erreur lors de l\'invitation: $e');
    }
  }

  // Accepter une demande ou invitation
  Future<void> acceptTeamRequest(String requestId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final requestDoc = await _teamRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Demande non trouvée');
      }

      final request = TeamRequest.fromFirestore(requestDoc);

      // Vérifier les permissions
      if (request.isJoinRequest) {
        // Seuls les admins peuvent accepter les demandes d'adhésion
        final userMember = await getUserTeamMember(request.teamId, currentUser.id);
        if (userMember == null || !userMember.canManageMembers()) {
          throw Exception('Vous n\'avez pas les permissions pour accepter cette demande');
        }
      } else if (request.isInvitation) {
        // Seul l'utilisateur invité peut accepter l'invitation
        if (request.toUserId != currentUser.id) {
          throw Exception('Vous ne pouvez accepter que vos propres invitations');
        }
      }

      final now = DateTime.now();

      // Mettre à jour la demande
      await _teamRequestsCollection.doc(requestId).update({
        'status': 'accepted',
        'respondedAt': Timestamp.fromDate(now),
        'respondedBy': currentUser.id,
      });

      // Supprimer toutes les autres demandes en attente de ce même utilisateur pour cette team
      if (request.isJoinRequest) {
        final otherRequests = await _teamRequestsCollection
            .where('teamId', isEqualTo: request.teamId)
            .where('fromUserId', isEqualTo: request.fromUserId)
            .where('type', isEqualTo: 'joinRequest')
            .where('status', isEqualTo: 'pending')
            .get();
        
        for (var doc in otherRequests.docs) {
          if (doc.id != requestId) {
            await doc.reference.update({
              'status': 'cancelled',
              'respondedAt': Timestamp.fromDate(now),
              'respondedBy': currentUser.id,
            });
          }
        }
      }

      // Ajouter l'utilisateur à la team
      final userId = request.isJoinRequest ? request.fromUserId : request.toUserId;
      final userData = request.isJoinRequest 
          ? {
              'username': request.fromUsername,
              'name': request.fromUserName,
              'avatar': request.fromUserAvatar,
            }
          : {
              'username': request.toUsername,
              'name': request.toUserName,
              'avatar': request.toUserAvatar,
            };

      final teamMemberId = '${userId}_${request.teamId}';
      final teamMember = TeamMember(
        id: teamMemberId,
        teamId: request.teamId,
        userId: userId,
        username: userData['username'] ?? '',
        name: userData['name'] ?? '',
        avatar: userData['avatar'],
        role: TeamMemberRole.member,
        status: TeamMemberStatus.active,
        joinedAt: now,
        lastActiveAt: now,
        joinedBy: currentUser.id,
      );

      await _teamMembersCollection.doc(teamMemberId).set(teamMember.toFirestore());

      // Mettre à jour le compteur de membres
      await _teamsCollection.doc(request.teamId).update({
        'memberCount': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Invalider le cache
      await _invalidateTeamCache(request.teamId);
    } catch (e) {
      throw Exception('Erreur lors de l\'acceptation: $e');
    }
  }

  // Décliner une demande ou invitation
  Future<void> declineTeamRequest(String requestId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final requestDoc = await _teamRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Demande non trouvée');
      }

      final request = TeamRequest.fromFirestore(requestDoc);

      // Vérifier les permissions
      if (request.isJoinRequest) {
        // Seuls les admins peuvent décliner les demandes d'adhésion
        final userMember = await getUserTeamMember(request.teamId, currentUser.id);
        if (userMember == null || !userMember.canManageMembers()) {
          throw Exception('Vous n\'avez pas les permissions pour décliner cette demande');
        }
      } else if (request.isInvitation) {
        // Seul l'utilisateur invité peut décliner l'invitation
        if (request.toUserId != currentUser.id) {
          throw Exception('Vous ne pouvez décliner que vos propres invitations');
        }
      }

      final now = DateTime.now();

      // Mettre à jour la demande
      await _teamRequestsCollection.doc(requestId).update({
        'status': 'declined',
        'respondedAt': Timestamp.fromDate(now),
        'respondedBy': currentUser.id,
      });
    } catch (e) {
      throw Exception('Erreur lors du refus: $e');
    }
  }

  // Récupérer les demandes reçues pour les teams de l'utilisateur (pour les admins)
  Stream<List<TeamRequest>> getTeamJoinRequests() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _teamRequestsCollection
        .where('toUserId', isEqualTo: currentUser.id)
        .where('type', isEqualTo: 'joinRequest')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamRequest.fromFirestore(doc))
            .toList());
  }

  // Récupérer les demandes pour une team spécifique (pour les admins)
  Stream<List<TeamRequest>> getTeamJoinRequestsForTeam(String teamId) {
    return _teamRequestsCollection
        .where('teamId', isEqualTo: teamId)
        .where('type', isEqualTo: 'joinRequest')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamRequest.fromFirestore(doc))
            .toList());
  }

  // Récupérer les invitations reçues par l'utilisateur
  Stream<List<TeamRequest>> getUserInvitations() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _teamRequestsCollection
        .where('toUserId', isEqualTo: currentUser.id)
        .where('type', isEqualTo: 'invitation')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamRequest.fromFirestore(doc))
            .toList());
  }

  // Invalider le cache d'une team spécifique
  Future<void> _invalidateTeamCache(String teamId) async {
    await _initCacheService();
    await _cacheService?.invalidateTeamCache(teamId);
    print('🗑️ Cache invalidé pour la team $teamId');
  }

  // Invalider tout le cache des teams
  Future<void> _invalidateAllTeamsCache() async {
    await _initCacheService();
    await _cacheService?.invalidateTeamsCache();
    print('🗑️ Cache de toutes les teams invalidé');
  }
}