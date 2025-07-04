import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled
}

class FriendRequest {
  final String id;
  final String senderId;
  final String senderUsername;
  final String senderName;
  final String? senderAvatar;
  final String receiverId;
  final String receiverUsername;
  final String receiverName;
  final String? receiverAvatar;
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? message;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.receiverUsername,
    required this.receiverName,
    this.receiverAvatar,
    required this.status,
    required this.sentAt,
    this.respondedAt,
    this.message,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderUsername: data['senderUsername'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatar: data['senderAvatar'],
      receiverId: data['receiverId'] ?? '',
      receiverUsername: data['receiverUsername'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverAvatar: data['receiverAvatar'],
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString() == 'FriendRequestStatus.${data['status']}',
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      message: data['message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverId': receiverId,
      'receiverUsername': receiverUsername,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'status': status.toString().split('.').last,
      'sentAt': Timestamp.fromDate(sentAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'message': message,
    };
  }

  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? senderUsername,
    String? senderName,
    String? senderAvatar,
    String? receiverId,
    String? receiverUsername,
    String? receiverName,
    String? receiverAvatar,
    FriendRequestStatus? status,
    DateTime? sentAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }

  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isDeclined => status == FriendRequestStatus.declined;
  bool get isCancelled => status == FriendRequestStatus.cancelled;
}