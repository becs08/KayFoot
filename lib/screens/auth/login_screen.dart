import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final result = await authService.signIn(
        identifier: _identifierController.text.trim(),
        motDePasse: _passwordController.text,
      );

      if (result.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppConstants.largePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppConstants.extraLargePadding),
                
                // Logo et titre
                _buildHeader(),
                
                SizedBox(height: AppConstants.extraLargePadding),
                
                // Formulaire de connexion
                _buildLoginForm(),
                
                SizedBox(height: AppConstants.largePadding),
                
                // Bouton de connexion
                _buildLoginButton(),
                
                SizedBox(height: AppConstants.mediumPadding),
                
                // Lien vers l'inscription
                _buildRegisterLink(),
                
                SizedBox(height: AppConstants.largePadding),
                
                // Connexion avec les réseaux sociaux (optionnel)
                _buildSocialLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Icon(
            Icons.sports_soccer,
            size: 50,
            color: Colors.white,
          ),
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        Text(
          'Bienvenue sur ${AppConstants.appName}',
          style: AppConstants.headingStyle.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        Text(
          'Connectez-vous pour réserver votre terrain',
          style: AppConstants.bodyStyle.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Champ email/téléphone
        TextFormField(
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email ou téléphone',
            hintText: 'Entrez votre email ou numéro',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre email ou téléphone';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Champ mot de passe
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            hintText: 'Entrez votre mot de passe',
            prefixIcon: Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre mot de passe';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        // Mot de passe oublié
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              // TODO: Implémenter la récupération de mot de passe
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fonctionnalité à venir'),
                ),
              );
            },
            child: Text('Mot de passe oublié ?'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(
                'Se connecter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pas encore de compte ? ',
          style: AppConstants.bodyStyle,
        ),
        GestureDetector(
          onTap: _navigateToRegister,
          child: Text(
            'S\'inscrire',
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.mediumPadding),
              child: Text(
                'Ou continuer avec',
                style: AppConstants.bodyStyle.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connexion Google à venir')),
                  );
                },
                icon: Icon(Icons.g_mobiledata, color: Colors.red),
                label: Text('Google'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            SizedBox(width: AppConstants.mediumPadding),
            
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connexion Facebook à venir')),
                  );
                },
                icon: Icon(Icons.facebook, color: Colors.blue),
                label: Text('Facebook'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}