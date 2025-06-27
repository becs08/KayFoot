import 'dart:convert';

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Widget pour afficher l'avatar de profil avec gestion robuste des erreurs
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final String? fallbackText;
  final VoidCallback? onTap;
  final bool showCameraIcon;
  final bool isLoading;

  const ProfileAvatar({
    Key? key,
    this.photoUrl,
    this.radius = 40,
    this.fallbackText,
    this.onTap,
    this.showCameraIcon = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Photo de profil avec gestion des erreurs
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.primaryColor.withOpacity(0.1),
            ),
            child: ClipOval(
              child: _buildImageWidget(),
            ),
          ),

          // Overlay de chargement
          if (isLoading)
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: Center(
                child: SizedBox(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),

          // Icône appareil photo
          if (showCameraIcon && !isLoading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(radius * 0.15),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: radius * 0.25,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    // Pas de photo
    if (photoUrl == null || photoUrl!.isEmpty) {
      return _buildFallbackWidget();
    }

    // Photo Base64
    if (photoUrl!.startsWith('data:image/')) {
      try {
        final base64String = photoUrl!.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Erreur chargement image Base64: $error');
            return _buildFallbackWidget();
          },
        );
      } catch (e) {
        print('❌ Erreur décodage Base64: $e');
        return _buildFallbackWidget();
      }
    }

    // Photo URL (Firebase Storage ou autre)
    return Image.network(
      photoUrl!,
      fit: BoxFit.cover,
      width: radius * 2,
      height: radius * 2,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: radius * 0.6,
            height: radius * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppConstants.primaryColor,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Erreur chargement image réseau: $error');
        print('📸 URL problématique: $photoUrl');
        return _buildFallbackWidget();
      },
    );
  }

  Widget _buildFallbackWidget() {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      // Afficher les initiales
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppConstants.primaryColor.withOpacity(0.1),
        ),
        child: Center(
          child: Text(
            fallbackText![0].toUpperCase(),
            style: TextStyle(
              fontSize: radius * 0.6,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryColor,
            ),
          ),
        ),
      );
    }

    // Icône par défaut
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppConstants.primaryColor.withOpacity(0.1),
      ),
      child: Icon(
        Icons.person,
        size: radius * 1.2,
        color: AppConstants.primaryColor,
      ),
    );
  }
}

