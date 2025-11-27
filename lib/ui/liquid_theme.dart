import 'dart:ui';
import 'package:flutter/material.dart';

// 🔥 새로운 다크 코스믹 색상 팔레트 정의
class LiquidColors {
  // 배경색: 깊은 우주 느낌의 어두운 그라데이션
  static const Color darkCosmicTop = Color(0xFF0F172A); // 아주 어두운 네이비
  static const Color darkCosmicMid = Color(0xFF1E293B); // 중간 톤의 다크 슬레이트
  static const Color darkCosmicBottom = Color(0xFF312E81); // 깊은 인디고 보라색

  // 포인트 색상 (발광 효과용)
  static const Color cyanAccent = Colors.cyanAccent;
  static const Color purpleAccent = Colors.purpleAccent;
  static const Color orangeAccent = Colors.orangeAccent;
  
  // 텍스트 색상
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
}

// 🔥 배경 위젯 (더 깊이감 있는 다크 그라데이션)
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // 3단계 그라데이션으로 깊이감 표현
          colors: [
            LiquidColors.darkCosmicTop,
            LiquidColors.darkCosmicMid,
            LiquidColors.darkCosmicBottom,
          ],
          stops: [0.0, 0.5, 1.0], // 색상이 변하는 지점
        ),
      ),
      child: child,
    );
  }
}

// 🔥 핵심: 더 투명하고 빛나는 리퀴드 글래스 카드
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color glowColor; // 테두리 발광 색상 선택 가능

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.onTap,
    this.glowColor = LiquidColors.cyanAccent, // 기본 발광색
  });

  @override
  Widget build(BuildContext context) {
    // 1. 탭 기능을 위한 InkWell 감싸기
    Widget cardContent = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: glowColor.withOpacity(0.2), // 클릭 시 물결 효과 색상
      highlightColor: glowColor.withOpacity(0.1),
      child: Container(
        width: width,
        height: height,
        // 2. 유리 질감 및 테두리 꾸미기
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // 2-1. 테두리: 얇고 빛나는 느낌
          border: Border.all(
            color: glowColor.withOpacity(0.3), // 발광색을 반투명하게
            width: 0.8, // 아주 얇은 테두리
          ),
          // 2-2. 유리 내부 색상: 아주 미세한 그라데이션으로 입체감 부여
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08), // 상단은 약간 밝게
              Colors.white.withOpacity(0.02), // 하단은 더 투명하게
            ],
          ),
          // 2-3. 은은한 그림자 (Glow 효과)
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: -5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // 3. 내용물 배치
        child: child,
      ),
    );

    // 4. 배경 블러 (유리 너머가 흐릿하게 보이는 효과)
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // 블러 강도 조절
        child: cardContent,
      ),
    );
  }
}

// 🔥 [추가] 발광 텍스트 스타일 (타이틀용)
TextStyle glowingTextStyle({double fontSize = 24, Color color = Colors.white}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: color,
    shadows: [
      Shadow(
        blurRadius: 12.0,
        color: color.withOpacity(0.6), // 글자색과 같은 빛 번짐
        offset: const Offset(0, 0),
      ),
      const Shadow(
        blurRadius: 20.0,
        color: Colors.black45, // 약간의 어두운 그림자로 입체감
        offset: Offset(0, 2),
      ),
    ],
  );
}