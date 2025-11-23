import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kfestival/guest_home.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/artist_home.dart';
import 'package:kfestival/ui/liquid_theme.dart'; // 🔥 테마 임포트

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _handleLogin(String role) async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userType': role,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        Widget nextParams;
        if (role == 'host') nextParams = const HostHomePage();
        else if (role == 'artist') nextParams = const ArtistHomePage();
        else nextParams = const GuestHomePage();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextParams),
        );
      }
    } catch (e) {
      print("로그인 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 [적용 1] 배경에 파란색 그라데이션 깔기
    return Scaffold(
      body: LiquidBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 및 타이틀 (흰색 글씨로 변경)
                const Icon(Icons.water_drop, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'K-Festival',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Global Festival Platform',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 60),

                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  _buildRoleButton('관객 (Guest)', '축제를 즐기고 싶어요', Icons.sentiment_satisfied_alt, 'guest'),
                  const SizedBox(height: 20),
                  _buildRoleButton('주최자 (Host)', '축제를 등록하고 싶어요', Icons.campaign, 'host'),
                  const SizedBox(height: 20),
                  _buildRoleButton('공연자 (Artist)', '무대에 서고 싶어요', Icons.mic_external_on, 'artist'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 [적용 2] 버튼을 유리 카드로 변경
  Widget _buildRoleButton(String title, String subtitle, IconData icon, String role) {
    return LiquidGlassCard(
      onTap: () => _handleLogin(role),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}