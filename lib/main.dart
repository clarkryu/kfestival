import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 파이어베이스 코어
import 'package:firebase_auth/firebase_auth.dart'; // 인증 패키지
import 'package:kfestival/firebase_options.dart'; // [중요] 설정 파일 임포트

// 각 홈 화면 임포트
import 'package:kfestival/guest_home.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/artist_home.dart';

void main() async {
  // 1. 플러터 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 파이어베이스 초기화 (시동 걸기)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );

  runApp(const KFestivalApp());
}

class KFestivalApp extends StatelessWidget {
  const KFestivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Festival',
      debugShowCheckedModeBanner: false, // 오른쪽 위 빨간 띠 제거
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // 로그인 처리 및 페이지 이동 함수
  Future<void> _signInAndNavigate(BuildContext context, Widget page, String role) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // A. 익명 로그인 시도
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      print("로그인 성공! UID: ${userCredential.user?.uid}");

      // 로딩 닫기
      if (context.mounted) Navigator.pop(context);

      // B. 해당 페이지로 이동
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      }
    } catch (e) {
      print("로그인 실패: $e");
      if (context.mounted) Navigator.pop(context); // 로딩 닫기
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.festival, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text(
                'K-Festival',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              const Text(
                '어떤 분이신가요?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildUserTypeCard(
                context,
                title: '관객 (Guest)',
                subtitle: '축제를 즐기고 싶어요',
                icon: Icons.sentiment_satisfied_alt,
                color: Colors.blueAccent,
                onTap: () => _signInAndNavigate(context, const GuestHomePage(), 'guest'),
              ),
              const SizedBox(height: 16),
              _buildUserTypeCard(
                context,
                title: '주최자 (Host)',
                subtitle: '축제를 등록하고 싶어요',
                icon: Icons.campaign,
                color: Colors.orangeAccent,
                onTap: () => _signInAndNavigate(context, const HostHomePage(), 'host'),
              ),
              const SizedBox(height: 16),
              _buildUserTypeCard(
                context,
                title: '공연자 (Artist)',
                subtitle: '무대에 서고 싶어요',
                icon: Icons.mic_external_on,
                color: Colors.pinkAccent,
                onTap: () => _signInAndNavigate(context, const ArtistHomePage(), 'artist'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}