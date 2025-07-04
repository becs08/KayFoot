import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamMemberRole {
  member,
  admin,
  creator
}

enum TeamMemberStatus {
  active,
  inactive,
  banned,
  left
}

class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final String username;
  final String name;
  final String? avatar;
  final TeamMemberRole role;
  final TeamMemberStatus status;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final String? joinedBy; // ID de l'utilisateur qui a ajouté ce membre
  final Map<String, dynamic>? permissions;

  TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.username,
    required this.name,
    this.avatar,
    this.role = TeamMemberRole.member,
    this.status = TeamMemberStatus.active,
    required this.joinedAt,
    this.lastActiveAt,
    this.joinedBy,
    this.permissions,
  });

  factory TeamMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamMember(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      name: data['name'] ?? '',
      avatar: data['avatar'],
      role: TeamMemberRole.values.firstWhere(
        (e) => e.toString() == 'TeamMemberRole.${data['role']}',
        orElse: () => TeamMemberRole.member,
      ),
      status: TeamMemberStatus.values.firstWhere(
        (e) => e.toString() == 'TeamMemberStatus.${data['status']}',
        orElse: () => TeamMemberStatus.active,
      ),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      joinedBy: data['joinedBy'],
      permissions: data['permissions'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'userId': userId,
      'username': username,
      'name': name,
      'avatar': avatar,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'joinedBy': joinedBy,
      'permissions': permissions,
    };
  }

  TeamMember copyWith({
    String? id,
    String? teamId,
    String? userId,
    String? username,
    String? name,
    String? avatar,
    TeamMemberRole? role,
    TeamMemberStatus? status,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    String? joinedBy,
    Map<String, dynamic>? permissions,
  }) {
    return TeamMember(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      joinedBy: joinedBy ?? this.joinedBy,
      permissions: permissions ?? this.permissions,
    );
  }

  bool get isCreator => role == TeamMemberRole.creator;
  bool get isAdmin => role == TeamMemberRole.admin || role == TeamMemberRole.creator;
  bool get isMember => role == TeamMemberRole.member;
  bool get isActive => status == TeamMemberStatus.active;
  bool get isBanned => status == TeamMemberStatus.banned;
  bool get hasLeft => status == TeamMemberStatus.left;

  bool canManageMembers() {
    return isAdmin && isActive;
  }

  bool canEditTeam() {
    return isAdmin && isActive;
  }

  bool canDeleteTeam() {
    return isCreator && isActive;
  }
}