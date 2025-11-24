import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kfestival/guest_home.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/artist_home.dart';
import 'package:kfestival/ui/liquid_theme.dart'; // 커스텀 테마

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  // 로그인 처리 함수
  Future<void> _handleLogin(String role) async {
    setState(() => _isLoading = true);

    try {
      // 1. 익명 로그인
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      User? user = userCredential.user;

      if (user != null) {
        // 2. 유저 역할(Role) DB에 저장
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userType': role,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. 화면 이동
        if (!mounted) return;
        Widget nextParams;
        if (role == 'host') {
          nextParams = const HostHomePage();
        } else if (role == 'artist') {
          nextParams = const ArtistHomePage();
        } else {
          nextParams = const GuestHomePage();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextParams),
        );
      }
    } catch (e) {
      print("로그인 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인에 실패했습니다. 다시 시도해주세요.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경: 리퀴드 그라데이션
      body: LiquidBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 및 타이틀
                const Icon(Icons.water_drop, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'Partner Login',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '호스트와 아티스트 전용 공간입니다.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 60),

                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  // 🔥 [수정] 게스트 버튼 삭제됨 -> 호스트/아티스트만 남김
                  
                  _buildRoleButton(
                    title: '주최자 (Host)',
                    subtitle: '축제를 등록하고 관리해요',
                    icon: Icons.campaign,
                    role: 'host',
                  ),
                  const SizedBox(height: 20),
                  
                  _buildRoleButton(
                    title: '공연자 (Artist)',
                    subtitle: '공연을 지원하고 매칭해요',
                    icon: Icons.mic_external_on,
                    role: 'artist',
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 뒤로가기 버튼
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                    label: const Text("관객 홈으로 돌아가기", style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 리퀴드 스타일 버튼 위젯
  Widget _buildRoleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required String role,
  }) {
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
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