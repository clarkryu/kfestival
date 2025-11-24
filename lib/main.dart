import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:kfestival/login.dart';
import 'package:kfestival/guest_home.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/artist_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kfestival/ui/liquid_theme.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: LiquidColors.deepBlue,
          primary: LiquidColors.deepBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
        // 1. 로딩 중일 때
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LiquidBackground(
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        // 2. 로그인이 되어 있는 경우 (Host, Artist, 또는 이미 익명 Guest)
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

              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                String userType = userSnapshot.data!.get('userType');
                if (userType == 'host') return const HostHomePage();
                if (userType == 'artist') return const ArtistHomePage();
              }
              
              // 유저 정보가 없거나 Guest라면 그냥 게스트 홈으로
              return const GuestHomePage();
            },
          );
        }

        // 3. 🔥 [핵심 변경] 로그인이 안 되어 있으면 -> 바로 GuestHomePage로 보냄 (로그인 화면 X)
        return const GuestHomePage();
      },
    );
  }
}