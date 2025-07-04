import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/social/username_service.dart';
import '../../services/Authentification/auth_service.dart';

class UsernameSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  
  const UsernameSetupScreen({Key? key, this.isFirstTime = false}) : super(key: key);

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final UsernameService _usernameService = UsernameService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isChecking = false;
  bool _isAvailable = false;
  String? _error;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      try {
        final suggestions = await _usernameService.getUsernameSuggestions(currentUser.nom);
        setState(() {
          _suggestions = suggestions;
        });
      } catch (e) {
        // Ignore errors for suggestions
      }
    }
  }

  Future<void> _checkUsername(String username) async {
    if (username.length < 3) {
      setState(() {
        _error = 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
        _isAvailable = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final available = await _usernameService.isUsernameAvailable(username);
      setState(() {
        _isAvailable = available;
        _error = available ? null : 'Ce nom d\'utilisateur est déjà pris';
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la vérification';
        _isAvailable = false;
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || !_isAvailable) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _usernameService.updateUsername(username);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nom d\'utilisateur configuré avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true);
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.isFirstTime ? null : AppBar(
        title: const Text('Choisir un nom d\'utilisateur'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFirstTime) ...[
                const SizedBox(height: 40),
                
                // Icône et titre
                Icon(
                  Icons.person_add,
                  size: 80,
                  color: AppConstants.primaryColor,
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Bienvenue dans KayFoot Social !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Choisissez un nom d\'utilisateur unique pour que vos amis puissent vous trouver facilement.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
              ],

              // Formulaire de saisie
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nom d\'utilisateur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Votre nom d\'utilisateur unique',
                        prefixIcon: const Icon(Icons.alternate_email),
                        suffixIcon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _usernameController.text.isNotEmpty
                                ? Icon(
                                    _isAvailable ? Icons.check_circle : Icons.error,
                                    color: _isAvailable ? Colors.green : Colors.red,
                                  )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _error != null 
                                ? Colors.red 
                                : _isAvailable && _usernameController.text.isNotEmpty
                                    ? Colors.green
                                    : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppConstants.primaryColor),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.length >= 3) {
                          _checkUsername(value);
                        } else {
                          setState(() {
                            _error = value.isNotEmpty ? 'Minimum 3 caractères' : null;
                            _isAvailable = false;
                          });
                        }
                      },
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    
                    if (_isAvailable && _usernameController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Disponible !',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Suggestions
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggestions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestions.map((suggestion) => InkWell(
                          onTap: () {
                            _usernameController.text = suggestion;
                            _checkUsername(suggestion);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppConstants.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '@$suggestion',
                              style: const TextStyle(
                                color: AppConstants.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Bouton de validation
              ElevatedButton(
                onPressed: _isLoading || !_isAvailable || _usernameController.text.isEmpty
                    ? null
                    : _saveUsername,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Configuration...'),
                        ],
                      )
                    : Text(
                        widget.isFirstTime ? 'Commencer !' : 'Sauvegarder',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              if (widget.isFirstTime) ...[
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () async {
                    // Générer automatiquement un username
                    try {
                      setState(() => _isLoading = true);
                      final autoUsername = await _usernameService.ensureUserHasUsername();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Username automatique: @$autoUsername'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.of(context).pop(true);
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
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  child: const Text('Générer automatiquement'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}