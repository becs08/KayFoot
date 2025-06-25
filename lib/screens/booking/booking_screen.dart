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
  // 🆕 VARIABLES POUR MULTI-SÉLECTION
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  List<String> _selectedCreneaux = []; // 🆕 Liste des créneaux sélectionnés
  ModePaiement _selectedPaymentMethod = ModePaiement.orange;

  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingAvailability = false;
  Set<String> _occupiedSlots = {};

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    if (user != null) {
      _phoneController.text = user.telephone;
    }
    _loadOccupiedSlots();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// 🆕 CHARGE LES CRÉNEAUX DÉJÀ RÉSERVÉS
  Future<void> _loadOccupiedSlots() async {
    setState(() {
      _isLoadingAvailability = true;
    });

    try {
      final occupiedSlots = await ReservationService().getOccupiedSlots(
        terrainId: widget.terrain.id,
        date: _selectedDate,
      );

      setState(() {
        _occupiedSlots = occupiedSlots;
        _isLoadingAvailability = false;

        // 🚨 Vérifier si les créneaux sélectionnés sont toujours disponibles
        _selectedCreneaux.removeWhere((creneau) => _occupiedSlots.contains(creneau));
      });

      print('📅 Créneaux occupés pour ${_formatDate(_selectedDate)}: $_occupiedSlots');
    } catch (e) {
      print('❌ Erreur chargement disponibilités: $e');
      setState(() {
        _isLoadingAvailability = false;
      });
    }
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

  /// 🆕 SÉLECTION DE DATE AVEC RESET DES CRÉNEAUX
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final minDate = now.add(Duration(days: 1));
    final maxDate = now.add(Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Réservation minimum 24h à l\'avance',
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
        _selectedCreneaux.clear(); // 🆕 Reset de la sélection
      });

      await _loadOccupiedSlots();
    }
  }

  /// 🆕 GESTION DE LA SÉLECTION MULTI-CRÉNEAUX
  void _handleSlotSelection(String creneau) {
    if (!_isSlotAvailable(creneau)) {
      _showError('Ce créneau n\'est pas disponible');
      return;
    }

    setState(() {
      if (_selectedCreneaux.contains(creneau)) {
        // Désélectionner le créneau
        _selectedCreneaux.remove(creneau);
      } else {
        // Vérifier la limite de 3 créneaux
        if (_selectedCreneaux.length >= 3) {
          _showError('Maximum 3 créneaux consécutifs autorisés');
          return;
        }

        // Ajouter le créneau et trier
        _selectedCreneaux.add(creneau);
        _selectedCreneaux.sort((a, b) => _parseTimeSlot(a).compareTo(_parseTimeSlot(b)));

        // Vérifier la consécutivité
        if (!_areConsecutive(_selectedCreneaux)) {
          _selectedCreneaux.remove(creneau);
          _showError('Les créneaux doivent être consécutifs');
          return;
        }
      }
    });

    print('📅 Créneaux sélectionnés: $_selectedCreneaux');
  }

  /// 🆕 VÉRIFIER SI LES CRÉNEAUX SONT CONSÉCUTIFS
  bool _areConsecutive(List<String> creneaux) {
    if (creneaux.length <= 1) return true;

    // Trier les créneaux par heure de début
    final sortedSlots = List<String>.from(creneaux)
      ..sort((a, b) => _parseTimeSlot(a).compareTo(_parseTimeSlot(b)));

    for (int i = 0; i < sortedSlots.length - 1; i++) {
      final currentEnd = _getSlotEndTime(sortedSlots[i]);
      final nextStart = _getSlotStartTime(sortedSlots[i + 1]);

      if (currentEnd != nextStart) {
        return false;
      }
    }

    return true;
  }

  /// 🆕 PARSER L'HEURE DE DÉBUT D'UN CRÉNEAU
  int _parseTimeSlot(String slot) {
    final startTime = slot.split('-')[0];
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 🆕 OBTENIR L'HEURE DE DÉBUT D'UN CRÉNEAU
  String _getSlotStartTime(String slot) {
    return slot.split('-')[0];
  }

  /// 🆕 OBTENIR L'HEURE DE FIN D'UN CRÉNEAU
  String _getSlotEndTime(String slot) {
    return slot.split('-')[1];
  }

  bool _isSlotAvailable(String creneau) {
    return !_occupiedSlots.contains(creneau);
  }

  /// 🆕 CALCUL DU TOTAL POUR PLUSIEURS CRÉNEAUX
  double _calculateTotal() {
    return _selectedCreneaux.length * widget.terrain.prixHeure;
  }

  /// 🆕 OBTENIR LA DURÉE TOTALE
  String _getTotalDuration() {
    if (_selectedCreneaux.isEmpty) return '0h';
    return '${_selectedCreneaux.length}h';
  }

  /// 🆕 OBTENIR LA PLAGE HORAIRE COMPLÈTE
  String _getTimeRange() {
    if (_selectedCreneaux.isEmpty) return '';

    final sortedSlots = List<String>.from(_selectedCreneaux)
      ..sort((a, b) => _parseTimeSlot(a).compareTo(_parseTimeSlot(b)));

    final startTime = _getSlotStartTime(sortedSlots.first);
    final endTime = _getSlotEndTime(sortedSlots.last);

    return '$startTime - $endTime';
  }

  /// 🆕 CRÉER RÉSERVATIONS MULTIPLES
  Future<void> _proceedToPayment() async {
    if (_selectedCreneaux.isEmpty) {
      _showError('Veuillez sélectionner au moins un créneau');
      return;
    }

    // Vérifier que tous les créneaux sont toujours disponibles
    for (final creneau in _selectedCreneaux) {
      if (!_isSlotAvailable(creneau)) {
        _showError('Le créneau $creneau n\'est plus disponible');
        return;
      }
    }

    if (_phoneController.text.trim().isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Créer une réservation pour toute la plage horaire
      final sortedSlots = List<String>.from(_selectedCreneaux)
        ..sort((a, b) => _parseTimeSlot(a).compareTo(_parseTimeSlot(b)));

      final heureDebut = _getSlotStartTime(sortedSlots.first);
      final heureFin = _getSlotEndTime(sortedSlots.last);

      print('🎫 Création réservation multi-créneaux:');
      print('   📅 Créneaux: $_selectedCreneaux');
      print('   ⏰ Plage: $heureDebut - $heureFin');
      print('   💰 Total: ${_calculateTotal().toInt()} FCFA');

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

            // Avertissement 24H + sélection multiple
            _buildAdvanceBookingWarning(),

            SizedBox(height: AppConstants.mediumPadding),

            // Sélection de la date
            _buildDateSelection(),

            SizedBox(height: AppConstants.largePadding),

            // 🆕 SÉLECTION MULTI-CRÉNEAUX
            _buildMultiSlotSelection(),

            SizedBox(height: AppConstants.largePadding),

            // Mode de paiement
            _buildPaymentMethodSelection(),

            SizedBox(height: AppConstants.largePadding),

            // Numéro de téléphone
            _buildPhoneInput(),

            SizedBox(height: AppConstants.largePadding),

            // Récapitulatif amélioré
            _buildSummary(),

            SizedBox(height: AppConstants.largePadding),

            // Bouton de confirmation
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  /// 🆕 AVERTISSEMENT AVEC INFO MULTI-SÉLECTION
  Widget _buildAdvanceBookingWarning() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          decoration: BoxDecoration(
            color: AppConstants.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            border: Border.all(
              color: AppConstants.accentColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppConstants.accentColor,
                size: 20,
              ),
              SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text(
                  'Réservation minimum 24h à l\'avance. Date la plus tôt : ${_formatDate(DateTime.now().add(Duration(days: 1)))}',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 12,
                    color: AppConstants.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: AppConstants.smallPadding),

        // 🆕 INFO MULTI-SÉLECTION
        Container(
          padding: EdgeInsets.all(AppConstants.mediumPadding),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                color: AppConstants.primaryColor,
                size: 20,
              ),
              SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text(
                  'Sélectionnez jusqu\'à 3 créneaux consécutifs pour jouer plus longtemps',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 12,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  /// 🆕 SÉLECTION MULTI-CRÉNEAUX AVEC INTERFACE AMÉLIORÉE
  Widget _buildMultiSlotSelection() {
    final creneaux = _getAvailableCreneaux();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créneaux disponibles',
                  style: AppConstants.subHeadingStyle.copyWith(fontSize: 16),
                ),
                if (_selectedCreneaux.isNotEmpty)
                  Text(
                    'Sélectionnés: ${_selectedCreneaux.length}/3 • ${_getTotalDuration()}',
                    style: AppConstants.bodyStyle.copyWith(
                      fontSize: 12,
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            if (_isLoadingAvailability)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),

        SizedBox(height: AppConstants.smallPadding),

        // 🆕 LÉGENDE AMÉLIORÉE
        _buildEnhancedLegend(),

        SizedBox(height: AppConstants.mediumPadding),

        // 🆕 PLAGE HORAIRE SÉLECTIONNÉE
        if (_selectedCreneaux.isNotEmpty)
          _buildSelectedTimeRange(),

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
            spacing: 8,
            runSpacing: 8,
            children: creneaux.map((creneau) {
              final isAvailable = _isSlotAvailable(creneau);
              final isSelected = _selectedCreneaux.contains(creneau);

              return GestureDetector(
                onTap: isAvailable ? () => _handleSlotSelection(creneau) : null,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.mediumPadding,
                    vertical: AppConstants.smallPadding,
                  ),
                  decoration: BoxDecoration(
                    color: _getSlotColor(isAvailable, isSelected),
                    borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                    border: Border.all(
                      color: _getSlotBorderColor(isAvailable, isSelected),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppConstants.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable
                            ? (isSelected ? Icons.check_circle : Icons.schedule)
                            : Icons.block,
                        size: 16,
                        color: _getSlotIconColor(isAvailable, isSelected),
                      ),

                      SizedBox(width: AppConstants.smallPadding),

                      Text(
                        creneau,
                        style: AppConstants.bodyStyle.copyWith(
                          color: _getSlotTextColor(isAvailable, isSelected),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          decoration: isAvailable ? null : TextDecoration.lineThrough,
                        ),
                      ),

                      // 🆕 NUMÉRO DE SÉLECTION
                      if (isSelected) ...[
                        SizedBox(width: AppConstants.smallPadding),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_selectedCreneaux.indexOf(creneau) + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// 🆕 LÉGENDE AMÉLIORÉE AVEC MULTI-SÉLECTION
  Widget _buildEnhancedLegend() {
    return Row(
      children: [
        _buildLegendItem(
          color: AppConstants.successColor,
          icon: Icons.schedule,
          label: 'Disponible',
        ),

        SizedBox(width: AppConstants.mediumPadding),

        _buildLegendItem(
          color: AppConstants.primaryColor,
          icon: Icons.check_circle,
          label: 'Sélectionné',
        ),

        SizedBox(width: AppConstants.mediumPadding),

        _buildLegendItem(
          color: Colors.grey,
          icon: Icons.block,
          label: 'Occupé',
        ),
      ],
    );
  }

  /// 🆕 AFFICHAGE DE LA PLAGE HORAIRE SÉLECTIONNÉE
  Widget _buildSelectedTimeRange() {
    return Container(
      padding: EdgeInsets.all(AppConstants.mediumPadding),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: AppConstants.primaryColor,
            size: 20,
          ),
          SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plage horaire sélectionnée',
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 12,
                    color: AppConstants.primaryColor,
                  ),
                ),
                Text(
                  '${_getTimeRange()} (${_getTotalDuration()})',
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // 🆕 BOUTON CLEAR
          if (_selectedCreneaux.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedCreneaux.clear();
                });
              },
              icon: Icon(
                Icons.clear,
                color: AppConstants.primaryColor,
                size: 20,
              ),
              tooltip: 'Tout désélectionner',
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        SizedBox(width: 4),
        Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            fontSize: 10,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getSlotColor(bool isAvailable, bool isSelected) {
    if (!isAvailable) return Colors.grey.shade200;
    if (isSelected) return AppConstants.primaryColor;
    return Colors.white;
  }

  Color _getSlotBorderColor(bool isAvailable, bool isSelected) {
    if (!isAvailable) return Colors.grey.shade400;
    if (isSelected) return AppConstants.primaryColor;
    return AppConstants.successColor.withOpacity(0.5);
  }

  Color _getSlotTextColor(bool isAvailable, bool isSelected) {
    if (!isAvailable) return Colors.grey.shade500;
    if (isSelected) return Colors.white;
    return Colors.black87;
  }

  Color _getSlotIconColor(bool isAvailable, bool isSelected) {
    if (!isAvailable) return Colors.grey.shade500;
    if (isSelected) return Colors.white;
    return AppConstants.successColor;
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
        ),
      ],
    );
  }

  /// 🆕 RÉCAPITULATIF AMÉLIORÉ POUR MULTI-CRÉNEAUX
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

            // 🆕 AFFICHAGE MULTI-CRÉNEAUX
            if (_selectedCreneaux.isNotEmpty) ...[
              _buildSummaryRow('Créneaux', '${_selectedCreneaux.length} sélectionné(s)'),
              _buildSummaryRow('Plage horaire', _getTimeRange()),
              _buildSummaryRow('Durée totale', _getTotalDuration()),
            ],

            _buildSummaryRow('Mode de paiement', _getPaymentMethodName(_selectedPaymentMethod)),

            if (_selectedCreneaux.isNotEmpty) ...[
              SizedBox(height: AppConstants.smallPadding),

              // 🆕 DÉTAIL DES CRÉNEAUX
              Container(
                padding: EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détail des créneaux:',
                      style: AppConstants.bodyStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    ...List.generate(_selectedCreneaux.length, (index) {
                      final creneau = _selectedCreneaux[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('${index + 1}. '),
                            Text(creneau),
                            Spacer(),
                            Text('${widget.terrain.prixHeure.toInt()} FCFA'),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

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

  /// 🆕 BOUTON DE CONFIRMATION AMÉLIORÉ
  Widget _buildConfirmButton() {
    final canConfirm = _selectedCreneaux.isNotEmpty &&
        _selectedCreneaux.every((slot) => _isSlotAvailable(slot)) &&
        !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canConfirm ? _proceedToPayment : null,
        child: _isLoading
            ? CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : Text(
          canConfirm
              ? 'Confirmer la réservation (${_selectedCreneaux.length}h)'
              : _selectedCreneaux.isEmpty
              ? 'Sélectionnez au moins un créneau'
              : 'Créneaux indisponibles',
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
