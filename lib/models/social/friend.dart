import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendUsername;
  final String friendName;
  final String? friendAvatar;
  final DateTime addedAt;
  final bool isBlocked;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendUsername,
    required this.friendName,
    this.friendAvatar,
    required this.addedAt,
    this.isBlocked = false,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend(
      id: doc.id,
      userId: data['userId'] ?? '',
      friendId: data['friendId'] ?? '',
      friendUsername: data['friendUsername'] ?? '',
      friendName: data['friendName'] ?? '',
      friendAvatar: data['friendAvatar'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isBlocked: data['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'friendId': friendId,
      'friendUsername': friendUsername,
      'friendName': friendName,
      'friendAvatar': friendAvatar,
      'addedAt': Timestamp.fromDate(addedAt),
      'isBlocked': isBlocked,
    };
  }

  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendUsername,
    String? friendName,
    String? friendAvatar,
    DateTime? addedAt,
    bool? isBlocked,
  }) {
    return Friend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      friendUsername: friendUsername ?? this.friendUsername,
      friendName: friendName ?? this.friendName,
      friendAvatar: friendAvatar ?? this.friendAvatar,
      addedAt: addedAt ?? this.addedAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}