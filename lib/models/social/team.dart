import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamPrivacy {
  public,    // Tout le monde peut voir et rejoindre
  private,   // Tout le monde peut voir, mais doit demander à rejoindre
  personal   // Visible seulement par les membres, invitation uniquement
}

class Team {
  final String id;
  final String name;
  final String description;
  final String? avatar;
  final String creatorId;
  final String creatorUsername;
  final List<String> adminIds;
  final TeamPrivacy privacy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;
  final int maxMembers;
  final Map<String, dynamic>? settings;
  final List<String> tags;

  Team({
    required this.id,
    required this.name,
    required this.description,
    this.avatar,
    required this.creatorId,
    required this.creatorUsername,
    required this.adminIds,
    this.privacy = TeamPrivacy.public,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 1,
    this.maxMembers = 50,
    this.settings,
    this.tags = const [],
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      avatar: data['avatar'],
      creatorId: data['creatorId'] ?? '',
      creatorUsername: data['creatorUsername'] ?? '',
      adminIds: List<String>.from(data['adminIds'] ?? []),
      privacy: TeamPrivacy.values.firstWhere(
        (e) => e.toString() == 'TeamPrivacy.${data['privacy']}',
        orElse: () => TeamPrivacy.public,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: data['memberCount'] ?? 1,
      maxMembers: data['maxMembers'] ?? 50,
      settings: data['settings'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'avatar': avatar,
      'creatorId': creatorId,
      'creatorUsername': creatorUsername,
      'adminIds': adminIds,
      'privacy': privacy.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'settings': settings,
      'tags': tags,
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? avatar,
    String? creatorId,
    String? creatorUsername,
    List<String>? adminIds,
    TeamPrivacy? privacy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
    int? maxMembers,
    Map<String, dynamic>? settings,
    List<String>? tags,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      creatorId: creatorId ?? this.creatorId,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      adminIds: adminIds ?? this.adminIds,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      settings: settings ?? this.settings,
      tags: tags ?? this.tags,
    );
  }

  bool get isPublic => privacy == TeamPrivacy.public;
  bool get isPrivate => privacy == TeamPrivacy.private;
  bool get isPersonal => privacy == TeamPrivacy.personal;
  bool get isFull => memberCount >= maxMembers;
  
  // Helper methods pour les permissions
  bool get canBeSeenByAnyone => isPublic || isPrivate;
  bool get requiresRequestToJoin => isPrivate;
  bool get isInviteOnly => isPersonal;
}