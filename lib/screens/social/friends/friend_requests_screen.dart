import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../models/social/friend_request.dart';
import '../../../services/social/friends_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendsService _friendsService = FriendsService();
  final Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    if (_processingRequests.contains(request.id)) return;

    setState(() {
      _processingRequests.add(request.id);
    });

    try {
      await _friendsService.acceptFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous êtes maintenant ami avec ${request.senderName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(request.id);
      });
    }
  }

  Future<void> _declineRequest(FriendRequest request) async {
    if (_processingRequests.contains(request.id)) return;

    setState(() {
      _processingRequests.add(request.id);
    });

    try {
      await _friendsService.declineFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande refusée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(request.id);
      });
    }
  }

  Future<void> _cancelRequest(FriendRequest request) async {
    if (_processingRequests.contains(request.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: Text('Voulez-vous annuler votre demande d\'ami à ${request.receiverName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.errorColor,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _processingRequests.add(request.id);
    });

    try {
      await _friendsService.cancelFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande annulée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(request.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Demandes d\'amis'),
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: AppConstants.primaryColor,
              unselectedLabelColor: Colors.white.withOpacity(0.8),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Reçues'),
                Tab(text: 'Envoyées'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Demandes reçues
          StreamBuilder<List<FriendRequest>>(
            stream: _friendsService.getReceivedFriendRequests(),
            builder: (context, snapshot) {
              return _buildRequestsList(
                snapshot,
                isReceived: true,
                emptyMessage: 'Aucune demande d\'ami reçue',
                emptySubtitle: 'Les demandes que vous recevez apparaîtront ici',
              );
            },
          ),
          
          // Demandes envoyées
          StreamBuilder<List<FriendRequest>>(
            stream: _friendsService.getSentFriendRequests(),
            builder: (context, snapshot) {
              return _buildRequestsList(
                snapshot,
                isReceived: false,
                emptyMessage: 'Aucune demande d\'ami envoyée',
                emptySubtitle: 'Les demandes que vous envoyez apparaîtront ici',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    AsyncSnapshot<List<FriendRequest>> snapshot, {
    required bool isReceived,
    required String emptyMessage,
    required String emptySubtitle,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur lors du chargement',
              style: AppConstants.subHeadingStyle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final requests = snapshot.data ?? [];

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReceived ? Icons.inbox : Icons.outbox,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              style: AppConstants.subHeadingStyle.copyWith(
                color: Colors.grey.shade600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, isReceived);
      },
    );
  }

  Widget _buildRequestCard(FriendRequest request, bool isReceived) {
    final isProcessing = _processingRequests.contains(request.id);
    final user = isReceived ? request.senderName : request.receiverName;
    final username = isReceived ? request.senderUsername : request.receiverUsername;
    final avatar = isReceived ? request.senderAvatar : request.receiverAvatar;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          user.isNotEmpty ? user[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _getFormattedDate(request.sentAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isReceived)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _declineRequest(request),
                        icon: const Icon(Icons.close, color: Colors.red),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _acceptRequest(request),
                        icon: const Icon(Icons.check, color: Colors.green),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  )
                else
                  IconButton(
                    onPressed: () => _cancelRequest(request),
                    icon: const Icon(Icons.cancel_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
              ],
            ),
            
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.message!,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}