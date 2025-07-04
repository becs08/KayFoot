import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/social/friends_service.dart';
import '../../services/social/username_service.dart';
import '../../services/social/teams_service.dart';
import '../../services/Authentification/auth_service.dart';
import 'friends/friends_screen.dart';
import 'teams/teams_screen.dart';
import 'username_setup_screen.dart';
import 'notifications/notifications_screen.dart';

class SocialMainScreen extends StatefulWidget {
  const SocialMainScreen({Key? key}) : super(key: key);

  @override
  State<SocialMainScreen> createState() => _SocialMainScreenState();
}

class _SocialMainScreenState extends State<SocialMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendsService _friendsService = FriendsService();
  final UsernameService _usernameService = UsernameService();
  final TeamsService _teamsService = TeamsService();
  final AuthService _authService = AuthService();
  int _pendingRequestsCount = 0;
  int _notificationsCount = 0;
  bool _hasUsername = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkUsername();
    _loadPendingRequestsCount();
    _loadNotificationsCount();
  }

  Future<void> _checkUsername() async {
    // Recharger l'utilisateur pour avoir les dernières données
    await _authService.reloadCurrentUser();
    
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _hasUsername = currentUser.username != null && currentUser.username!.isNotEmpty;
    });

    if (!_hasUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUsernameSetup();
      });
    }
  }

  Future<void> _showUsernameSetup() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UsernameSetupScreen(isFirstTime: true),
        settings: const RouteSettings(name: '/username-setup'),
      ),
    );

    if (result == true) {
      setState(() {
        _hasUsername = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRequestsCount() async {
    try {
      final count = await _friendsService.getPendingRequestsCount();
      if (mounted) {
        setState(() {
          _pendingRequestsCount = count;
        });
      }
    } catch (e) {
      // Ignore errors for now
    }
  }

  Future<void> _loadNotificationsCount() async {
    try {
      // Compter les invitations reçues
      final invitationsSnapshot = await _teamsService.getUserInvitations().first;
      // Compter les demandes d'adhésion reçues
      final requestsSnapshot = await _teamsService.getTeamJoinRequests().first;
      
      final totalCount = invitationsSnapshot.length + requestsSnapshot.length;
      
      if (mounted) {
        setState(() {
          _notificationsCount = totalCount;
        });
      }
    } catch (e) {
      // Ignore errors for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Social',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  // Recharger le compteur après être revenu
                  _loadNotificationsCount();
                },
                icon: const Icon(Icons.notifications),
                tooltip: 'Notifications',
              ),
              if (_notificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
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
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 20),
                      const SizedBox(width: 8),
                      const Text('Amis'),
                      if (_pendingRequestsCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_pendingRequestsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, size: 20),
                      SizedBox(width: 8),
                      Text('Teams'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FriendsScreen(onRequestsChanged: _loadPendingRequestsCount),
          const TeamsScreen(),
        ],
      ),
    );
  }
}