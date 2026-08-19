import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Istatistikler ve kart koruma hakki.
///
/// YAPIM ASAMASINDA: Bu ekranin icerigi ADIM 3 tamamlandiginda yazilacak.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 56, color: AppColors.warning),
              SizedBox(height: 16),
              Text(
                'ADIM 3 kapsaminda hazirlanacak.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
