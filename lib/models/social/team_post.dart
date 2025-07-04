import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamPostType {
  text,
  image,
  reservation,
  event,
  announcement
}

class TeamPost {
  final String id;
  final String teamId;
  final String authorId;
  final String authorUsername;
  final String authorName;
  final String? authorAvatar;
  final TeamPostType type;
  final String content;
  final List<String>? imageUrls;
  final String? reservationId;
  final String? eventId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> likedBy;
  final int commentCount;
  final bool isPinned;
  final bool isDeleted;

  TeamPost({
    required this.id,
    required this.teamId,
    required this.authorId,
    required this.authorUsername,
    required this.authorName,
    this.authorAvatar,
    required this.type,
    required this.content,
    this.imageUrls,
    this.reservationId,
    this.eventId,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    this.likedBy = const [],
    this.commentCount = 0,
    this.isPinned = false,
    this.isDeleted = false,
  });

  factory TeamPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamPost(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      authorName: data['authorName'] ?? '',
      authorAvatar: data['authorAvatar'],
      type: TeamPostType.values.firstWhere(
        (e) => e.toString() == 'TeamPostType.${data['type']}',
        orElse: () => TeamPostType.text,
      ),
      content: data['content'] ?? '',
      imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : null,
      reservationId: data['reservationId'],
      eventId: data['eventId'],
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'type': type.toString().split('.').last,
      'content': content,
      'imageUrls': imageUrls,
      'reservationId': reservationId,
      'eventId': eventId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'likedBy': likedBy,
      'commentCount': commentCount,
      'isPinned': isPinned,
      'isDeleted': isDeleted,
    };
  }

  TeamPost copyWith({
    String? id,
    String? teamId,
    String? authorId,
    String? authorUsername,
    String? authorName,
    String? authorAvatar,
    TeamPostType? type,
    String? content,
    List<String>? imageUrls,
    String? reservationId,
    String? eventId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? likedBy,
    int? commentCount,
    bool? isPinned,
    bool? isDeleted,
  }) {
    return TeamPost(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      reservationId: reservationId ?? this.reservationId,
      eventId: eventId ?? this.eventId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likedBy: likedBy ?? this.likedBy,
      commentCount: commentCount ?? this.commentCount,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  int get likesCount => likedBy.length;
  
  bool isLikedBy(String userId) {
    return likedBy.contains(userId);
  }
}