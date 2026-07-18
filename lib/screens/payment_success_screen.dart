import 'package:flutter/material.dart';
import '../models/game_object.dart';
import 'game_screen.dart';
 
/// The first screen shown after a successful payment.
/// Static (nothing animates here) — purely a confirmation + call-to-action
/// screen matching the JAP Xperience visual language.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool gameCompleted = false;
  bool gameWon = false;
String rewardName = "";
  
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFE),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- Top bar: close button ----------------
            Align(
              alignment: Alignment.topRight,
              child: Padding(
  padding: const EdgeInsets.all(12.0),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: IconButton(
      icon: const Icon(
        Icons.close_rounded,
        color: AppColors.textGrey,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  ),
),
            ),
 
            // ---------------- Main content ----------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
  const SizedBox(height: 40),
                  
                    // Large success icon inside a soft circular backdrop.
                    Container(
  width: 118,
  height: 118,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const LinearGradient(
      colors: [
        AppColors.primaryTeal,
        AppColors.primaryTealDark,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryTeal.withValues(alpha: 0.28),
        blurRadius: 28,
        spreadRadius: 2,
        offset: const Offset(0, 12),
      ),
    ],
  ),
  child: const Icon(
    Icons.check_rounded,
    color: Colors.white,
    size: 62,
  ),
),
 
                    const SizedBox(height: 36),
 
                    // Title.
                   const Text(
  'Payment Successful!',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textDark,
  ),
),
 
                    const SizedBox(height: 8),
 
 
                   const SizedBox(height: 40),

                 if (!gameCompleted) ...[
  const Text(
    "🎁 Surprise Reward",
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
    ),
  ),

  const SizedBox(height: 10),

  const Text(
    "Play the mini game to unlock an exclusive travel reward.",
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 15,
      height: 1.4,
      color: AppColors.textGrey,
    ),
  ),

  const SizedBox(height: 24),
],

if (!gameCompleted)
  _ClaimNowButton(
    onTap: () async {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GameScreen(),
        ),
      );

      if (result != null) {
        final reward = (result["reward"] ?? "") as String;
        setState(() {
          gameCompleted = true;
          rewardName = reward;
          // A non-empty reward name means the backend granted a reward.
          gameWon = reward.isNotEmpty;
        });
      }
    },
  )
else
  AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    transitionBuilder: (child, animation) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
    child: Container(
      key: ValueKey(gameWon),
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(28),
  border: Border.all(
    color: AppColors.primaryTeal.withValues(alpha: 0.15),
    width: 1.5,
  ),
  boxShadow: [
    BoxShadow(
      color: AppColors.primaryTeal.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ],
),
    child: Column(
  children: [
  Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [
          AppColors.primaryTeal,
          AppColors.primaryTealDark,
        ],
      ),
    ),
    child: Icon(
      gameWon
          ? Icons.workspace_premium_rounded
          : Icons.hourglass_bottom_rounded,
      color: Colors.white,
      size: 38,
    ),
  ),

  const SizedBox(height: 20),

  Text(
    gameWon ? "Reward Unlocked!" : "No Reward This Time",
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
    ),
  ),

  const SizedBox(height: 18),

 if (gameWon)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      vertical: 18,
      horizontal: 16,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFFE8FFFF),
          Colors.white,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.primaryTeal.withValues(alpha: 0.25),
        width: 1.5,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_offer_rounded,
          color: AppColors.primaryTeal,
          size: 26,
        ),
        const SizedBox(height: 8),
        Text(
          rewardName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTealDark,
          ),
        ),
      ],
    ),
  )
else
  const Text(
    "Better luck next time!\nComplete another journey to unlock a reward.",
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 16,
      height: 1.5,
      color: AppColors.textGrey,
    ),
  ),
],
    ),
  ),
  ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
/// Large rounded, teal-gradient call-to-action button matching the
/// JAP Xperience brand styling.
class _ClaimNowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClaimNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryTeal,
                AppColors.primaryTealDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.redeem_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),

              SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Play Mini Game",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Unlock an exclusive travel reward",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}