import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firestore_init_service.dart';
import 'firebase_options.dart'; // Assurez-vous d'avoir ce fichier
import 'constants/app_constants.dart';
import 'models/user.dart'; // Assurez-vous que votre modèle User.dart est correct et correspond à PigeonUserDetails
import 'services/Authentification/auth_service.dart';
import 'config/environment_config.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialiser la configuration d'environnement
    print('⚙️ Initialisation de la configuration...');
    await EnvironmentConfig().initialize();
    EnvironmentConfig().printConfigStatus();

    // Initialiser Firebase
    print('🔥 Initialisation de Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('✅ Firebase initialisé avec succès');

    // Initialiser les services
    print('🔧 Initialisation de AuthService...');
    await AuthService().initialize();
    print('✅ AuthService initialisé avec succès');

    if (kDebugMode) {
      try {
        print('🚀 === INITIALISATION KAY FOOT ===');

        // Initialiser seulement les terrains (utilisateurs modifiés manuellement)
        await FirestoreInitService.initializeTestData();

        print('✅ Toutes les initialisations terminées');
        print('💡 Structure automatique pour nouveaux utilisateurs activée');
      } catch (e) {
        print('⚠️ Erreur lors des initialisations: $e');
      }
    }

    runApp(KayFoot());
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              const Text(
                'Erreur d\'initialisation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Erreur: $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class KayFoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppConstants.primaryColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
            brightness: Brightness.light,
          ),
          useMaterial3: true,

          // AppBar Theme
          appBarTheme: AppBarTheme(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: AppConstants.subHeadingStyle.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),

          // Button Themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              ),
              textStyle: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          // Input Decoration Theme
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              borderSide: BorderSide(color: AppConstants.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              borderSide: BorderSide(color: AppConstants.errorColor),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppConstants.mediumPadding,
              vertical: AppConstants.smallPadding,
            ),
          ),

          // Card Theme
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: AppConstants.mediumPadding,
              vertical: AppConstants.smallPadding,
            ),
          ),
        ),
        home: AuthWrapper(),
        routes: {
          '/splash': (context) => SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/home': (context) => HomeScreen(),
        },
      ),
    );
  }
}

// Wrapper pour gérer l'authentification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Pendant le chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }

        // Si l'utilisateur est connecté
        if (snapshot.hasData && snapshot.data != null) {
          // IMPORTANT : Vérifiez la propriété 'nom' de votre modèle User
          // S'il n'y a pas de propriété 'nom' directement sur l'objet User, cela pourrait causer des problèmes.
          // Assurez-vous que snapshot.data! est bien un objet 'User' avec la propriété 'nom'.
          print('🔑 Utilisateur connecté: ${snapshot.data!.nom}');
          return HomeScreen();
        }

        // Sinon, afficher la page de connexion
        print('🔒 Aucun utilisateur connecté');
        return LoginScreen();
      },
    );
  }
}

class AppProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
