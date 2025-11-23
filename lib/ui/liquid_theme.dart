import 'package:flutter/material.dart';
import 'dart:ui';

class LiquidColors {
  // 🔥 찐한 파란색 그라데이션 색상
  static const Color deepBlue = Color(0xFF005BEA);
  static const Color skyBlue = Color(0xFF00C6FB);
  static const Color textWhite = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
}

// 1. 배경용 위젯 (모든 화면의 뒤에 깔아줄 것)
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LiquidColors.skyBlue, // 하늘색
            LiquidColors.deepBlue, // 찐파랑
          ],
        ),
      ),
      child: child, // 이 위에 내용물이 올라감
    );
  }
}

// 2. 유리 카드 위젯 (Glassmorphism 핵심)
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        // 🔥 뒤쪽 배경을 흐리게 만듦 (Blur)
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              // 🔥 반투명한 흰색 + 그라데이션
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.4), // 왼쪽 위는 좀 더 하얗게 (빛 반사)
                  Colors.white.withOpacity(0.1), // 오른쪽 아래는 투명하게
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              // 🔥 얇은 흰색 테두리 (유리 모서리 느낌)
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}