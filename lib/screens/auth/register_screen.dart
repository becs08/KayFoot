import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedVille = AppConstants.villes.first;
  UserRole _selectedRole = UserRole.joueur;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showError('Vous devez accepter les conditions d\'utilisation');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final result = await authService.signUp(
        nom: _nomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        email: _emailController.text.trim(),
        motDePasse: _passwordController.text,
        ville: _selectedVille,
        role: _selectedRole,
      );

      if (result.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur d\'inscription: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppConstants.largePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête
                _buildHeader(),
                
                SizedBox(height: AppConstants.largePadding),
                
                // Sélection du rôle
                _buildRoleSelection(),
                
                SizedBox(height: AppConstants.mediumPadding),
                
                // Formulaire d'inscription
                _buildRegistrationForm(),
                
                SizedBox(height: AppConstants.mediumPadding),
                
                // Acceptation des conditions
                _buildTermsAcceptance(),
                
                SizedBox(height: AppConstants.largePadding),
                
                // Bouton d'inscription
                _buildRegisterButton(),
                
                SizedBox(height: AppConstants.mediumPadding),
                
                // Lien de connexion
                _buildLoginLink(),
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
        Text(
          'Créer un compte',
          style: AppConstants.headingStyle.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        Text(
          'Rejoignez la communauté SamaMinifoot',
          style: AppConstants.bodyStyle.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Je suis :',
          style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        Row(
          children: [
            Expanded(
              child: RadioListTile<UserRole>(
                title: Text('Joueur'),
                subtitle: Text('Réserver des terrains'),
                value: UserRole.joueur,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                activeColor: AppConstants.primaryColor,
              ),
            ),
            
            Expanded(
              child: RadioListTile<UserRole>(
                title: Text('Gérant'),
                subtitle: Text('Gérer des terrains'),
                value: UserRole.gerant,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                activeColor: AppConstants.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      children: [
        // Nom complet
        TextFormField(
          controller: _nomController,
          decoration: InputDecoration(
            labelText: 'Nom complet',
            hintText: 'Entrez votre nom complet',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre nom';
            }
            if (value.trim().length < 2) {
              return 'Le nom doit contenir au moins 2 caractères';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Téléphone
        TextFormField(
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Téléphone',
            hintText: '77 123 45 67',
            prefixIcon: Icon(Icons.phone),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre numéro de téléphone';
            }
            if (!RegExp(AppConstants.phonePattern).hasMatch(value.trim())) {
              return 'Numéro de téléphone invalide';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'votre@email.com',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer votre email';
            }
            if (!RegExp(AppConstants.emailPattern).hasMatch(value.trim())) {
              return 'Adresse email invalide';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Ville
        DropdownButtonFormField<String>(
          value: _selectedVille,
          decoration: InputDecoration(
            labelText: 'Ville',
            prefixIcon: Icon(Icons.location_city),
          ),
          items: AppConstants.villes.map((String ville) {
            return DropdownMenuItem<String>(
              value: ville,
              child: Text(ville),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedVille = newValue!;
            });
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Mot de passe
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            hintText: 'Minimum 6 caractères',
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
              return 'Veuillez entrer un mot de passe';
            }
            if (value.length < AppConstants.minPasswordLength) {
              return 'Le mot de passe doit contenir au moins ${AppConstants.minPasswordLength} caractères';
            }
            return null;
          },
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        // Confirmation mot de passe
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            hintText: 'Retapez votre mot de passe',
            prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez confirmer votre mot de passe';
            }
            if (value != _passwordController.text) {
              return 'Les mots de passe ne correspondent pas';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTermsAcceptance() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value!;
            });
          },
          activeColor: AppConstants.primaryColor,
        ),
        
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _acceptTerms = !_acceptTerms;
              });
            },
            child: Text(
              'J\'accepte les conditions d\'utilisation et la politique de confidentialité',
              style: AppConstants.bodyStyle.copyWith(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(
                'S\'inscrire',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Déjà un compte ? ',
          style: AppConstants.bodyStyle,
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Se connecter',
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}