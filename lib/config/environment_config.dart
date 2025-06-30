import 'dart:io';

class EnvironmentConfig {
  static final EnvironmentConfig _instance = EnvironmentConfig._internal();
  factory EnvironmentConfig() => _instance;
  EnvironmentConfig._internal();

  late Map<String, String> _config;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _config = {};
    
    // Try to load from environment variables first
    _loadFromEnvironment();
    
    // If no environment variables, use fallback values for development
    if (_config.isEmpty) {
      _loadFallbackConfig();
    }
    
    _isInitialized = true;
    print('🔧 Configuration initialisée avec ${_config.length} paramètres');
  }

  void _loadFromEnvironment() {
    final envVars = [
      'FIREBASE_ANDROID_API_KEY',
      'FIREBASE_IOS_API_KEY', 
      'FIREBASE_ANDROID_APP_ID',
      'FIREBASE_IOS_APP_ID',
      'FIREBASE_MESSAGING_SENDER_ID',
      'FIREBASE_PROJECT_ID',
      'FIREBASE_STORAGE_BUCKET',
      'FIREBASE_IOS_BUNDLE_ID',
      'FIREBASE_ANDROID_PACKAGE_NAME',
      'API_BASE_URL',
    ];

    for (String key in envVars) {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty) {
        _config[key] = value;
      }
    }
  }

  void _loadFallbackConfig() {
    // ⚠️ Ces valeurs temporaires pour le développement
    // DOIVENT être remplacées par de vraies variables d'environnement pour la production
    _config = {
      'FIREBASE_ANDROID_API_KEY': 'AIzaSyAmHkkBHFoSVyCKct7Og7oob40cFFho6rk',
      'FIREBASE_IOS_API_KEY': 'AIzaSyCOeDtK1jxWbR8zoNhlvTpicFpqRk2XYiE',
      'FIREBASE_ANDROID_APP_ID': '1:409307077227:android:3b7ad549443ac1addaaf2e',
      'FIREBASE_IOS_APP_ID': '1:409307077227:ios:c0177754a3fdcce3daaf2e',
      'FIREBASE_MESSAGING_SENDER_ID': '409307077227',
      'FIREBASE_PROJECT_ID': 'sama-minifoot-2024',
      'FIREBASE_STORAGE_BUCKET': 'sama-minifoot-2024.firebasestorage.app',
      'FIREBASE_IOS_BUNDLE_ID': 'com.example.kayfoot',
      'FIREBASE_ANDROID_PACKAGE_NAME': 'com.example.samaminifoot.sama_minifoot',
      'API_BASE_URL': 'https://api.samaminifoot.sn',
    };
    
    print('⚠️ ATTENTION: Utilisation de la configuration de développement');
    print('⚠️ Configurez les variables d\'environnement pour la production');
    print('⚠️ Consultez SECURITY_SETUP.md pour les instructions');
  }

  String get androidApiKey => _getConfig('FIREBASE_ANDROID_API_KEY');
  String get iosApiKey => _getConfig('FIREBASE_IOS_API_KEY');
  String get androidAppId => _getConfig('FIREBASE_ANDROID_APP_ID');
  String get iosAppId => _getConfig('FIREBASE_IOS_APP_ID');
  String get messagingSenderId => _getConfig('FIREBASE_MESSAGING_SENDER_ID');
  String get projectId => _getConfig('FIREBASE_PROJECT_ID');
  String get storageBucket => _getConfig('FIREBASE_STORAGE_BUCKET');
  String get iosBundleId => _getConfig('FIREBASE_IOS_BUNDLE_ID');
  String get androidPackageName => _getConfig('FIREBASE_ANDROID_PACKAGE_NAME');
  String get apiBaseUrl => _getConfig('API_BASE_URL');

  String _getConfig(String key) {
    if (!_isInitialized) {
      throw StateError('EnvironmentConfig must be initialized before use');
    }
    
    final value = _config[key];
    if (value == null || value.isEmpty) {
      throw StateError('Configuration key "$key" not found');
    }
    
    return value;
  }

  bool get isProduction => Platform.environment.containsKey('FIREBASE_ANDROID_API_KEY');

  void printConfigStatus() {
    print('📋 Status de la configuration:');
    print('  - Environnement: ${isProduction ? "Production" : "Développement"}');
    print('  - Project ID: ${projectId.length > 20 ? "${projectId.substring(0, 20)}..." : projectId}');
    print('  - Storage Bucket: ${storageBucket.length > 20 ? "${storageBucket.substring(0, 20)}..." : storageBucket}');
    
    if (!isProduction) {
      print('⚠️ CONFIGURER LES VARIABLES D\'ENVIRONNEMENT POUR LA PRODUCTION!');
    }
  }
}