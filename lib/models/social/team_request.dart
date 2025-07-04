import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamRequestStatus {
  pending,
  accepted,
  declined,
  cancelled
}

enum TeamRequestType {
  joinRequest,  // Demande pour rejoindre une team privée
  invitation    // Invitation d'un admin vers un user
}

class TeamRequest {
  final String id;
  final String teamId;
  final String teamName;
  final String fromUserId;
  final String fromUsername;
  final String fromUserName;
  final String? fromUserAvatar;
  final String toUserId;
  final String toUsername;
  final String toUserName;
  final String? toUserAvatar;
  final TeamRequestType type;
  final TeamRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? respondedBy;

  TeamRequest({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromUserName,
    this.fromUserAvatar,
    required this.toUserId,
    required this.toUsername,
    required this.toUserName,
    this.toUserAvatar,
    required this.type,
    this.status = TeamRequestStatus.pending,
    this.message,
    required this.createdAt,
    this.respondedAt,
    this.respondedBy,
  });

  factory TeamRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamRequest(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      fromUserAvatar: data['fromUserAvatar'],
      toUserId: data['toUserId'] ?? '',
      toUsername: data['toUsername'] ?? '',
      toUserName: data['toUserName'] ?? '',
      toUserAvatar: data['toUserAvatar'],
      type: TeamRequestType.values.firstWhere(
        (e) => e.toString() == 'TeamRequestType.${data['type']}',
        orElse: () => TeamRequestType.joinRequest,
      ),
      status: TeamRequestStatus.values.firstWhere(
        (e) => e.toString() == 'TeamRequestStatus.${data['status']}',
        orElse: () => TeamRequestStatus.pending,
      ),
      message: data['message'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      respondedBy: data['respondedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserName': fromUserName,
      'fromUserAvatar': fromUserAvatar,
      'toUserId': toUserId,
      'toUsername': toUsername,
      'toUserName': toUserName,
      'toUserAvatar': toUserAvatar,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'respondedBy': respondedBy,
    };
  }

  TeamRequest copyWith({
    String? id,
    String? teamId,
    String? teamName,
    String? fromUserId,
    String? fromUsername,
    String? fromUserName,
    String? fromUserAvatar,
    String? toUserId,
    String? toUsername,
    String? toUserName,
    String? toUserAvatar,
    TeamRequestType? type,
    TeamRequestStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? respondedBy,
  }) {
    return TeamRequest(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserAvatar: fromUserAvatar ?? this.fromUserAvatar,
      toUserId: toUserId ?? this.toUserId,
      toUsername: toUsername ?? this.toUsername,
      toUserName: toUserName ?? this.toUserName,
      toUserAvatar: toUserAvatar ?? this.toUserAvatar,
      type: type ?? this.type,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
    );
  }

  bool get isPending => status == TeamRequestStatus.pending;
  bool get isAccepted => status == TeamRequestStatus.accepted;
  bool get isDeclined => status == TeamRequestStatus.declined;
  bool get isCancelled => status == TeamRequestStatus.cancelled;
  bool get isJoinRequest => type == TeamRequestType.joinRequest;
  bool get isInvitation => type == TeamRequestType.invitation;
}