import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

class SosPulseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isBroadcasting;

  const SosPulseButton({
    super.key,
    required this.onPressed,
    this.isBroadcasting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing halo using flutter_animate
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emergencyRedGlow,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.2, 1.2),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              )
              .fade(begin: 0.7, end: 0.1),

          // Core emergency circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF4D4D), AppColors.emergencyRed, Color(0xFF991B1B)],
                center: Alignment(-0.2, -0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emergencyRed.withOpacity(0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.crisis_alert_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 4),
                Text(
                  isBroadcasting ? 'TRANSMITTING' : 'BROADCAST SOS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          )
              .animate(target: isBroadcasting ? 1 : 0)
              .shake(duration: 400.ms, hz: 4),
        ],
      ),
    );
  }
}
