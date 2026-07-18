import 'package:flutter/material.dart';
import 'screens/payment_success_screen.dart';
import 'models/game_object.dart';
 
/// Entry point for the JAP Xperience stacking mini-game.
void main() {
  runApp(const JapXperienceApp());
}
 
class JapXperienceApp extends StatelessWidget {
  const JapXperienceApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JAP Xperience',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryTeal,
          primary: AppColors.primaryTeal,
        ),
      ),
 home: const PaymentSuccessScreen(),
    );
  }
}