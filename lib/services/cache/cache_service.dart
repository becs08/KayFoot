import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static CacheService? _instance;
  static SharedPreferences? _prefs;

  CacheService._();

  static Future<CacheService> getInstance() async {
    if (_instance == null) {
      _instance = CacheService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Clés de cache
  static const String _userProfileKey = 'user_profile';
  static const String _userTeamsKey = 'user_teams';
  static const String _teamDetailsPrefix = 'team_details_';
  static const String _teamMembersPrefix = 'team_members_';
  static const String _friendsKey = 'user_friends';
  static const String _notificationsKey = 'user_notifications';
  static const String _lastUpdatePrefix = 'last_update_';

  // Durée de validité du cache (en millisecondes)
  static const int _cacheValidityDuration = 300000; // 5 minutes

  /// Vérifie si une donnée en cache est encore valide
  bool _isCacheValid(String key) {
    final lastUpdate = _prefs?.getInt('${_lastUpdatePrefix}$key') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastUpdate) < _cacheValidityDuration;
  }

  /// Met à jour le timestamp de dernière mise à jour
  void _updateTimestamp(String key) {
    _prefs?.setInt('${_lastUpdatePrefix}$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Sauvegarde une donnée en cache avec timestamp
  Future<void> _saveToCache(String key, String data) async {
    await _prefs?.setString(key, data);
    _updateTimestamp(key);
  }

  /// Récupère une donnée du cache si elle est valide
  String? _getFromCache(String key) {
    if (_isCacheValid(key)) {
      return _prefs?.getString(key);
    }
    return null;
  }

  // === PROFIL UTILISATEUR ===

  /// Sauvegarde le profil utilisateur
  Future<void> saveUserProfile(Map<String, dynamic> userProfile) async {
    await _saveToCache(_userProfileKey, jsonEncode(userProfile));
  }

  /// Récupère le profil utilisateur depuis le cache
  Map<String, dynamic>? getUserProfile() {
    final data = _getFromCache(_userProfileKey);
    if (data != null) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        print('Erreur décodage profil utilisateur: $e');
      }
    }
    return null;
  }

  /// Supprime le profil utilisateur du cache
  Future<void> clearUserProfile() async {
    await _prefs?.remove(_userProfileKey);
    await _prefs?.remove('${_lastUpdatePrefix}$_userProfileKey');
  }

  // === TEAMS DE L'UTILISATEUR ===

  /// Sauvegarde la liste des teams de l'utilisateur
  Future<void> saveUserTeams(List<Map<String, dynamic>> teams) async {
    await _saveToCache(_userTeamsKey, jsonEncode(teams));
  }

  /// Récupère la liste des teams de l'utilisateur depuis le cache
  List<Map<String, dynamic>>? getUserTeams() {
    final data = _getFromCache(_userTeamsKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Erreur décodage teams utilisateur: $e');
      }
    }
    return null;
  }

  /// Supprime les teams de l'utilisateur du cache
  Future<void> clearUserTeams() async {
    await _prefs?.remove(_userTeamsKey);
    await _prefs?.remove('${_lastUpdatePrefix}$_userTeamsKey');
  }

  // === DÉTAILS DES TEAMS ===

  /// Sauvegarde les détails d'une team
  Future<void> saveTeamDetails(String teamId, Map<String, dynamic> teamDetails) async {
    final key = '$_teamDetailsPrefix$teamId';
    await _saveToCache(key, jsonEncode(teamDetails));
  }

  /// Récupère les détails d'une team depuis le cache
  Map<String, dynamic>? getTeamDetails(String teamId) {
    final key = '$_teamDetailsPrefix$teamId';
    final data = _getFromCache(key);
    if (data != null) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        print('Erreur décodage détails team: $e');
      }
    }
    return null;
  }

  /// Supprime les détails d'une team du cache
  Future<void> clearTeamDetails(String teamId) async {
    final key = '$_teamDetailsPrefix$teamId';
    await _prefs?.remove(key);
    await _prefs?.remove('${_lastUpdatePrefix}$key');
  }

  // === MEMBRES DES TEAMS ===

  /// Sauvegarde les membres d'une team
  Future<void> saveTeamMembers(String teamId, List<Map<String, dynamic>> members) async {
    final key = '$_teamMembersPrefix$teamId';
    await _saveToCache(key, jsonEncode(members));
  }

  /// Récupère les membres d'une team depuis le cache
  List<Map<String, dynamic>>? getTeamMembers(String teamId) {
    final key = '$_teamMembersPrefix$teamId';
    final data = _getFromCache(key);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Erreur décodage membres team: $e');
      }
    }
    return null;
  }

  /// Supprime les membres d'une team du cache
  Future<void> clearTeamMembers(String teamId) async {
    final key = '$_teamMembersPrefix$teamId';
    await _prefs?.remove(key);
    await _prefs?.remove('${_lastUpdatePrefix}$key');
  }

  // === AMIS ===

  /// Sauvegarde la liste des amis
  Future<void> saveFriends(List<Map<String, dynamic>> friends) async {
    await _saveToCache(_friendsKey, jsonEncode(friends));
  }

  /// Récupère la liste des amis depuis le cache
  List<Map<String, dynamic>>? getFriends() {
    final data = _getFromCache(_friendsKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Erreur décodage amis: $e');
      }
    }
    return null;
  }

  /// Supprime les amis du cache
  Future<void> clearFriends() async {
    await _prefs?.remove(_friendsKey);
    await _prefs?.remove('${_lastUpdatePrefix}$_friendsKey');
  }

  // === NOTIFICATIONS ===

  /// Sauvegarde les notifications
  Future<void> saveNotifications(List<Map<String, dynamic>> notifications) async {
    await _saveToCache(_notificationsKey, jsonEncode(notifications));
  }

  /// Récupère les notifications depuis le cache
  List<Map<String, dynamic>>? getNotifications() {
    final data = _getFromCache(_notificationsKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Erreur décodage notifications: $e');
      }
    }
    return null;
  }

  /// Supprime les notifications du cache
  Future<void> clearNotifications() async {
    await _prefs?.remove(_notificationsKey);
    await _prefs?.remove('${_lastUpdatePrefix}$_notificationsKey');
  }

  // === GESTION GLOBALE DU CACHE ===

  /// Force l'invalidation d'une clé spécifique
  Future<void> invalidateCache(String key) async {
    await _prefs?.remove('${_lastUpdatePrefix}$key');
  }

  /// Vide tout le cache
  Future<void> clearAllCache() async {
    final keys = _prefs?.getKeys().where((key) => 
      key.startsWith(_userProfileKey) ||
      key.startsWith(_userTeamsKey) ||
      key.startsWith(_teamDetailsPrefix) ||
      key.startsWith(_teamMembersPrefix) ||
      key.startsWith(_friendsKey) ||
      key.startsWith(_notificationsKey) ||
      key.startsWith(_lastUpdatePrefix)
    ).toList() ?? [];
    
    for (String key in keys) {
      await _prefs?.remove(key);
    }
  }

  /// Invalide tout le cache lié aux teams
  Future<void> invalidateTeamsCache() async {
    await clearUserTeams();
    
    // Invalider tous les détails et membres de teams
    final keys = _prefs?.getKeys().where((key) => 
      key.startsWith(_teamDetailsPrefix) ||
      key.startsWith(_teamMembersPrefix)
    ).toList() ?? [];
    
    for (String key in keys) {
      await _prefs?.remove(key);
      if (key.startsWith(_teamDetailsPrefix)) {
        await _prefs?.remove('${_lastUpdatePrefix}$key');
      } else if (key.startsWith(_teamMembersPrefix)) {
        await _prefs?.remove('${_lastUpdatePrefix}$key');
      }
    }
  }

  /// Invalide le cache d'une team spécifique
  Future<void> invalidateTeamCache(String teamId) async {
    await clearTeamDetails(teamId);
    await clearTeamMembers(teamId);
    await clearUserTeams(); // Recharger aussi la liste des teams de l'utilisateur
  }

  /// Obtient la taille approximative du cache en octets
  int getCacheSize() {
    int size = 0;
    final keys = _prefs?.getKeys() ?? {};
    for (String key in keys) {
      final value = _prefs?.getString(key);
      if (value != null) {
        size += value.length;
      }
    }
    return size;
  }

  /// Obtient des statistiques sur le cache
  Map<String, dynamic> getCacheStats() {
    final keys = _prefs?.getKeys() ?? {};
    int userProfileSize = 0;
    int teamsSize = 0;
    int friendsSize = 0;
    int notificationsSize = 0;
    int totalEntries = 0;

    for (String key in keys) {
      final value = _prefs?.getString(key);
      if (value != null) {
        totalEntries++;
        if (key.contains('user_profile')) {
          userProfileSize += value.length;
        } else if (key.contains('team')) {
          teamsSize += value.length;
        } else if (key.contains('friends')) {
          friendsSize += value.length;
        } else if (key.contains('notifications')) {
          notificationsSize += value.length;
        }
      }
    }

    return {
      'totalEntries': totalEntries,
      'totalSize': getCacheSize(),
      'userProfileSize': userProfileSize,
      'teamsSize': teamsSize,
      'friendsSize': friendsSize,
      'notificationsSize': notificationsSize,
    };
  }
}