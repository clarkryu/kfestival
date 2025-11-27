import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔥 [중요] 새로 바뀐 테마 파일 임포트 확인
import 'package:kfestival/ui/liquid_theme.dart';
import 'package:kfestival/host_home.dart';
import 'package:kfestival/guest_main.dart'; 

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
      title: 'K-PODO',
      debugShowCheckedModeBanner: false,
      // 🔥 다크 테마 적용
theme: ThemeData.dark().copyWith(
          useMaterial3: true,
          scaffoldBackgroundColor: LiquidColors.darkCosmicTop, // 🔥 배경색 변경
          colorScheme: ColorScheme.fromSeed(
            seedColor: LiquidColors.darkCosmicBottom, // 🔥 deepBlue -> darkCosmicBottom
            brightness: Brightness.dark,
            primary: LiquidColors.cyanAccent, // 🔥 포인트 색상 변경
          ),
        // 앱바 테마 설정
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
        // 기본 텍스트 테마를 흰색으로 설정
        textTheme: Typography.whiteMountainView,
      ),
      home: const AuthCheck(),
    );
  }
}

// ... (AuthCheck 클래스 이하는 기존과 동일합니다. 변경 필요 없음)
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  
  @override
  void initState() {
    super.initState();
    _signInAnonymouslyIfLoggedOut();
  }

  // 로그인이 안 되어 있으면 자동으로 익명 로그인 시도
  Future<void> _signInAnonymouslyIfLoggedOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        print("👻 게스트를 위한 투명 로그인(익명) 완료!");
      } catch (e) {
        print("익명 로그인 실패: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LiquidBackground(
              child: Center(child: CircularProgressIndicator(color: LiquidColors.cyanAccent)),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.isAnonymous) {
            return const GuestMainPage();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: LiquidBackground(
                    child: Center(child: CircularProgressIndicator(color: LiquidColors.cyanAccent)),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                String userType = userSnapshot.data!.get('userType');
                if (userType == 'host') return const HostHomePage();
               
              }
              
              return const GuestMainPage(); 
            },
          );
        }

        return const Scaffold(
          body: LiquidBackground(
            child: Center(child: CircularProgressIndicator(color: LiquidColors.cyanAccent)),
          ),
        );
      },
    );
  }
}