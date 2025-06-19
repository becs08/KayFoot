import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'SamaMinifoot';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'https://api.samaminifoot.sn';
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Colors
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );
  
  static const TextStyle subHeadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.black87,
  );
  
  // Spacing
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;
  
  // Border Radius
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double extraLargeRadius = 24.0;
  
  // Villes du Sénégal
  static const List<String> villes = [
    'Dakar',
    'Thiès',
    'Kaolack',
    'Saint-Louis',
    'Ziguinchor',
    'Diourbel',
    'Tambacounda',
    'Kolda',
    'Matam',
    'Kaffrine',
    'Kédougou',
    'Sédhiou',
    'Fatick',
    'Louga',
  ];
  
  // Équipements de terrain
  static const List<String> equipements = [
    'Éclairage',
    'Vestiaires',
    'Douches',
    'Parking',
    'Sécurité',
    'Buvette',
    'Toilettes',
    'Gradins',
    'Terrain synthétique',
    'Terrain naturel',
  ];
  
  // Créneaux horaires
  static const List<String> creneauxHoraires = [
    '06:00-07:00',
    '07:00-08:00',
    '08:00-09:00',
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
    '14:00-15:00',
    '15:00-16:00',
    '16:00-17:00',
    '17:00-18:00',
    '18:00-19:00',
    '19:00-20:00',
    '20:00-21:00',
    '21:00-22:00',
  ];
  
  // Messages
  static const String noInternetMessage = 'Aucune connexion internet disponible';
  static const String serverErrorMessage = 'Erreur du serveur. Veuillez réessayer';
  static const String genericErrorMessage = 'Une erreur est survenue';
  
  // Validation
  static const int minPasswordLength = 6;
  static const String phonePattern = r'^(77|78|76|75|70)\d{7}$';
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
}