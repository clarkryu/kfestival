import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:kfestival/login.dart';
import 'package:kfestival/guest_home.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/artist_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kfestival/ui/liquid_theme.dart'; // 커스텀 테마 임포트

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Festival',
      debugShowCheckedModeBanner: false,
      // 🔥 [수정] 테마 색상을 새로운 팔레트에 맞게 변경
      theme: ThemeData(
        useMaterial3: true,
        // 배경은 LiquidBackground 위젯이 덮을 거라 기본 흰색으로 둠
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: LiquidColors.deepBlue, // 찐파랑
          primary: LiquidColors.deepBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white, // 앱바 글씨 흰색
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 텍스트 기본 색상
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: LiquidColors.textDark),
        ),
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 중일 때도 예쁜 배경 보여주기
          return const Scaffold(
            body: LiquidBackground(
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: LiquidBackground(
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                // 데이터가 있으면 userType 확인
                if (userSnapshot.data!.exists) {
                  String userType = userSnapshot.data!.get('userType');
                  if (userType == 'host') return const HostHomePage();
                  if (userType == 'artist') return const ArtistHomePage();
                  return const GuestHomePage();
                }
              }
              // 데이터 없으면 로그인 화면
              return const LoginPage();
            },
          );
        }
        // 로그인 안 되어 있으면 로그인 화면
        return const LoginPage();
      },
    );
  }
}