import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/terrain.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../services/auth_service.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  final Terrain terrain;

  const BookingScreen({Key? key, required this.terrain}) : super(key: key);

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedCreneau;
  ModePaiement _selectedPaymentMethod = ModePaiement.orange;
  
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir le numéro de téléphone de l'utilisateur
    final user = AuthService().currentUser;
    if (user != null) {
      _phoneController.text = user.telephone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  List<String> _getAvailableCreneaux() {
    final dayOfWeek = _getDayOfWeek(_selectedDate);
    return widget.terrain.disponibilites[dayOfWeek] ?? [];
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'lundi', 'mardi', 'mercredi', 'jeudi', 
      'vendredi', 'samedi', 'dimanche'
    ];
    return days[date.weekday - 1];
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppConstants.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedCreneau = null; // Reset créneau selection
      });
    }
  }

  double _calculateTotal() {
    if (_selectedCreneau != null) {
      return widget.terrain.prixHeure;
    }
    return 0.0;
  }

  String _getCreneauEnd(String heureDebut) {
    final parts = heureDebut.split('-');
    return parts.length > 1 ? parts[1] : heureDebut;
  }

  Future<void> _proceedToPayment() async {
    if (_selectedCreneau == null) {
      _showError('Veuillez sélectionner un créneau');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final parts = _selectedCreneau!.split('-');
      final heureDebut = parts[0];
      final heureFin = parts.length > 1 ? parts[1] : parts[0];

      final result = await ReservationService().createReservation(
        terrainId: widget.terrain.id,
        date: _selectedDate,
        heureDebut: heureDebut,
        heureFin: heureFin,
        montant: _calculateTotal(),
        modePaiement: _selectedPaymentMethod,
      );

      if (result.success && result.reservation != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              reservation: result.reservation!,
              terrain: widget.terrain,
            ),
          ),
        );
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
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
        title: Text('Réserver'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations du terrain
            _buildTerrainInfo(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Sélection de la date
            _buildDateSelection(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Sélection du créneau
            _buildCreneauSelection(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Mode de paiement
            _buildPaymentMethodSelection(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Numéro de téléphone
            _buildPhoneInput(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Récapitulatif
            _buildSummary(),
            
            SizedBox(height: AppConstants.largePadding),
            
            // Bouton de confirmation
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTerrainInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
              ),
              child: Icon(
                Icons.sports_soccer,
                color: AppConstants.primaryColor,
                size: 30,
              ),
            ),
            
            SizedBox(width: AppConstants.mediumPadding),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.terrain.nom,
                    style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                  ),
                  
                  SizedBox(height: 4),
                  
                  Text(
                    widget.terrain.ville,
                    style: AppConstants.bodyStyle.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  
                  Text(
                    '${widget.terrain.prixHeure.toInt()} FCFA/heure',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date du match',
          style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppConstants.primaryColor,
                ),
                
                SizedBox(width: AppConstants.mediumPadding),
                
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: AppConstants.bodyStyle,
                  ),
                ),
                
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreneauSelection() {
    final creneaux = _getAvailableCreneaux();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créneaux disponibles',
          style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        if (creneaux.isEmpty)
          Container(
            padding: EdgeInsets.all(AppConstants.mediumPadding),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Aucun créneau disponible pour cette date',
                  style: AppConstants.bodyStyle.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: creneaux.map((creneau) {
              final isSelected = _selectedCreneau == creneau;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCreneau = creneau;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.mediumPadding,
                    vertical: AppConstants.smallPadding,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppConstants.primaryColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                    border: Border.all(
                      color: isSelected
                          ? AppConstants.primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    creneau,
                    style: AppConstants.bodyStyle.copyWith(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode de paiement',
          style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
        ),
        
        SizedBox(height: AppConstants.mediumPadding),
        
        Column(
          children: ModePaiement.values.map((method) {
            return RadioListTile<ModePaiement>(
              title: Text(_getPaymentMethodName(method)),
              subtitle: Text(_getPaymentMethodDescription(method)),
              value: method,
              groupValue: _selectedPaymentMethod,
              activeColor: AppConstants.primaryColor,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numéro de téléphone (Mobile Money)',
          style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
        ),
        
        SizedBox(height: AppConstants.smallPadding),
        
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '77 123 45 67',
            prefixIcon: Icon(Icons.phone),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Numéro de téléphone requis';
            }
            if (!RegExp(AppConstants.phonePattern).hasMatch(value.trim())) {
              return 'Numéro de téléphone invalide';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final total = _calculateTotal();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppConstants.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Récapitulatif',
              style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
            ),
            
            SizedBox(height: AppConstants.mediumPadding),
            
            _buildSummaryRow('Terrain', widget.terrain.nom),
            _buildSummaryRow('Date', _formatDate(_selectedDate)),
            if (_selectedCreneau != null)
              _buildSummaryRow('Créneau', _selectedCreneau!),
            _buildSummaryRow('Mode de paiement', _getPaymentMethodName(_selectedPaymentMethod)),
            
            Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total à payer',
                  style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                ),
                Text(
                  '${total.toInt()} FCFA',
                  style: AppConstants.subHeadingStyle.copyWith(
                    fontSize: 18,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: AppConstants.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading || _selectedCreneau == null
            ? null
            : _proceedToPayment,
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(
                'Confirmer la réservation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    const days = [
      'lundi', 'mardi', 'mercredi', 'jeudi', 
      'vendredi', 'samedi', 'dimanche'
    ];
    
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    
    return '${dayName.substring(0, 1).toUpperCase()}${dayName.substring(1)} ${date.day} $monthName ${date.year}';
  }

  String _getPaymentMethodName(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Orange Money';
      case ModePaiement.wave:
        return 'Wave';
      case ModePaiement.free:
        return 'Free Money';
      case ModePaiement.especes:
        return 'Espèces';
    }
  }

  String _getPaymentMethodDescription(ModePaiement method) {
    switch (method) {
      case ModePaiement.orange:
        return 'Paiement via Orange Money';
      case ModePaiement.wave:
        return 'Paiement via Wave';
      case ModePaiement.free:
        return 'Paiement via Free Money';
      case ModePaiement.especes:
        return 'Paiement sur place';
    }
  }
}