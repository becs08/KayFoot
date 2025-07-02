import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isLocationPermissionGranted = false;

  /// 📍 Obtenir la position actuelle de l'utilisateur
  Future<Position?> getCurrentPosition() async {
    try {
      print('📍 Demande de localisation...');

      // Vérifier si les services de localisation sont activés
      if (!await Geolocator.isLocationServiceEnabled()) {
        print('❌ Services de localisation désactivés');
        return null;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Permission de localisation refusée');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission de localisation refusée définitivement');
        return null;
      }

      // Obtenir la position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _isLocationPermissionGranted = true;
      print('✅ Position obtenue: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      return _currentPosition;
    } catch (e) {
      print("❌ Erreur lors de l'obtention de la position: $e");
      return null;
    }
  }

  /// 🔄 Obtenir la dernière position connue
  Future<Position?> getLastKnownPosition() async {
    try {
      if (_currentPosition != null) {
        return _currentPosition;
      }

      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        _currentPosition = lastPosition;
        print('📍 Dernière position connue: ${lastPosition.latitude}, ${lastPosition.longitude}');
      }
      return lastPosition;
    } catch (e) {
      print("❌ Erreur lors de l'obtention de la dernière position: $e");
      return null;
    }
  }

  /// 📏 Calculer la distance entre deux points en kilomètres
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convertir en kilomètres
  }

  /// 📏 Calculer la distance depuis la position actuelle vers un point
  double? calculateDistanceFromCurrent(double latitude, double longitude) {
    if (_currentPosition == null) return null;

    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  /// ✅ Vérifier si les permissions de localisation sont accordées
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;

  /// 📍 Obtenir la position actuelle (cached)
  Position? get currentPosition => _currentPosition;

  /// 🔄 Rafraîchir la position
  Future<Position?> refreshPosition() async {
    _currentPosition = null;
    return await getCurrentPosition();
  }

  /// 🏙️ Obtenir le nom de la ville approximatif basé sur les coordonnées du Sénégal
  String getApproximateCity(double latitude, double longitude) {
    // Coordonnées approximatives des principales villes du Sénégal
    final cities = {
      'Dakar': {'lat': 14.6937, 'lon': -17.4441},
      'Thiès': {'lat': 14.7886, 'lon': -16.9361},
      'Saint-Louis': {'lat': 16.0402, 'lon': -16.4897},
      'Kaolack': {'lat': 14.1592, 'lon': -16.0729},
      'Ziguinchor': {'lat': 12.5681, 'lon': -16.2739},
      'Diourbel': {'lat': 14.6521, 'lon': -16.2347},
      'Louga': {'lat': 15.6181, 'lon': -16.2245},
      'Tambacounda': {'lat': 13.7671, 'lon': -13.6681},
      'Kolda': {'lat': 12.8939, 'lon': -14.9401},
      'Mbour': {'lat': 14.4198, 'lon': -16.9692},
    };

    String closestCity = 'Dakar'; // Ville par défaut
    double minDistance = double.infinity;

    cities.forEach((cityName, coords) {
      final distance = calculateDistance(
        latitude,
        longitude,
        coords['lat']!,
        coords['lon']!,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestCity = cityName;
      }
    });

    return closestCity;
  }

  /// 🎯 Obtenir la ville de l'utilisateur basée sur sa position
  Future<String?> getUserCity() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    return getApproximateCity(position.latitude, position.longitude);
  }

  /// 📱 Ouvrir les paramètres de localisation de l'appareil
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// ⚙️ Ouvrir les paramètres d'autorisation de l'application
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// 🔍 Formater la distance pour l'affichage
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  /// 🎯 Obtenir les terrains triés par distance avec les distances calculées
  List<Map<String, dynamic>> addDistancesToTerrains(
    List<Map<String, dynamic>> terrains,
    Position userPosition,
  ) {
    return terrains.map((terrain) {
      final distance = calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        terrain['latitude'] as double,
        terrain['longitude'] as double,
      );

      return {
        ...terrain,
        'distance': distance,
        'distanceFormatted': formatDistance(distance),
      };
    }).toList()
      ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
  }
}

/// 🎯 Classe pour représenter un résultat de localisation
class LocationResult {
  final bool success;
  final Position? position;
  final String? errorMessage;

  LocationResult({
    required this.success,
    this.position,
    this.errorMessage,
  });
}
