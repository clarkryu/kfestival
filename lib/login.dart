import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kfestival/guest_main.dart'; 
import 'package:kfestival/host_home.dart';
// import 'package:kfestival/artist_home.dart'; // 🗑️ 아티스트 화면 필요 없음
import 'package:kfestival/ui/liquid_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _isLoginMode = true; // true: 로그인, false: 회원가입
  
  // 🔥 역할 선택 변수 삭제 (_selectedRole 필요 없음)

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _pwController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      
      if (_isLoginMode) {
        // [로그인]
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _pwController.text.trim(),
        );
      } else {
        // [회원가입]
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _pwController.text.trim(),
        );
        
        // 🔥 [수정] 가입 시 무조건 'host'로 저장 (선택 로직 삭제)
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'userType': 'host', // 고정값
          'status': 'pending', // 추후 승인 대기용
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("환영합니다! 파트너 가입이 완료되었습니다.")));
        }
      }

      // 로그인 성공 후 이동 (무조건 HostHomePage)
      User? user = userCredential.user;
      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HostHomePage()));
      }
    } on FirebaseAuthException catch (e) {
      String message = "오류가 발생했습니다.";
      if (e.code == 'user-not-found') message = "등록되지 않은 계정입니다.";
      else if (e.code == 'wrong-password') message = "비밀번호가 일치하지 않습니다.";
      else if (e.code == 'email-already-in-use') message = "이미 사용 중인 이메일입니다.";
      else if (e.code == 'weak-password') message = "비밀번호는 6자리 이상이어야 합니다.";
      else if (e.code == 'invalid-email') message = "이메일 형식이 잘못되었습니다.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // 우측 상단 닫기 버튼
              Positioned(
                top: 10,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_person_rounded, size: 60, color: LiquidColors.cyanAccent),
                      const SizedBox(height: 20),
                      Text(
                        _isLoginMode ? 'Partner Login' : 'Partner Sign Up',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '공연/전시 주최자를 위한 파트너 공간입니다.',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),

                      // 입력창
                      _buildTextField(_emailController, "이메일", Icons.email, false),
                      const SizedBox(height: 16),
                      _buildTextField(_pwController, "비밀번호", Icons.lock, true),
                      
                      // 🔥 [삭제됨] 역할 선택 라디오 버튼 영역 삭제!

                      const SizedBox(height: 40),

                      // 로그인/가입 버튼
                      if (_isLoading)
                        const CircularProgressIndicator(color: LiquidColors.cyanAccent)
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LiquidColors.cyanAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                              shadowColor: LiquidColors.cyanAccent.withOpacity(0.5),
                            ),
                            child: Text(
                              _isLoginMode ? "로그인" : "파트너 가입 완료",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 모드 전환 텍스트
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoginMode ? "계정이 없으신가요?" : "이미 계정이 있으신가요?",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                            child: Text(
                              _isLoginMode ? "회원가입" : "로그인",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isObscure) {
    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          obscureText: isObscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            icon: Icon(icon, color: Colors.white70),
            border: InputBorder.none,
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }
}