import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamEventType {
  match,
  training,
  meeting,
  social,
  tournament,
  other
}

enum TeamEventStatus {
  upcoming,
  ongoing,
  completed,
  cancelled
}

class TeamEvent {
  final String id;
  final String teamId;
  final String creatorId;
  final String creatorUsername;
  final String title;
  final String description;
  final TeamEventType type;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String? terrainId;
  final int maxParticipants;
  final List<String> participantIds;
  final List<String> invitedUserIds;
  final TeamEventStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  final bool isPublic;

  TeamEvent({
    required this.id,
    required this.teamId,
    required this.creatorId,
    required this.creatorUsername,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.location,
    this.terrainId,
    this.maxParticipants = 50,
    this.participantIds = const [],
    this.invitedUserIds = const [],
    this.status = TeamEventStatus.upcoming,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
    this.isPublic = true,
  });

  factory TeamEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamEvent(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorUsername: data['creatorUsername'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: TeamEventType.values.firstWhere(
        (e) => e.toString() == 'TeamEventType.${data['type']}',
        orElse: () => TeamEventType.other,
      ),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'],
      terrainId: data['terrainId'],
      maxParticipants: data['maxParticipants'] ?? 50,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      invitedUserIds: List<String>.from(data['invitedUserIds'] ?? []),
      status: TeamEventStatus.values.firstWhere(
        (e) => e.toString() == 'TeamEventStatus.${data['status']}',
        orElse: () => TeamEventStatus.upcoming,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'creatorId': creatorId,
      'creatorUsername': creatorUsername,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'location': location,
      'terrainId': terrainId,
      'maxParticipants': maxParticipants,
      'participantIds': participantIds,
      'invitedUserIds': invitedUserIds,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
      'isPublic': isPublic,
    };
  }

  TeamEvent copyWith({
    String? id,
    String? teamId,
    String? creatorId,
    String? creatorUsername,
    String? title,
    String? description,
    TeamEventType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? terrainId,
    int? maxParticipants,
    List<String>? participantIds,
    List<String>? invitedUserIds,
    TeamEventStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    bool? isPublic,
  }) {
    return TeamEvent(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      creatorId: creatorId ?? this.creatorId,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      terrainId: terrainId ?? this.terrainId,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantIds: participantIds ?? this.participantIds,
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  int get participantCount => participantIds.length;
  bool get isFull => participantCount >= maxParticipants;
  bool get isUpcoming => status == TeamEventStatus.upcoming;
  bool get isOngoing => status == TeamEventStatus.ongoing;
  bool get isCompleted => status == TeamEventStatus.completed;
  bool get isCancelled => status == TeamEventStatus.cancelled;

  bool isUserParticipating(String userId) {
    return participantIds.contains(userId);
  }

  bool isUserInvited(String userId) {
    return invitedUserIds.contains(userId);
  }

  Duration get duration => endDate.difference(startDate);
}