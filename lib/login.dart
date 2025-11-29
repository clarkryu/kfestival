import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 🔥 스토리지 추가
import 'package:image_picker/image_picker.dart'; // 🔥 이미지 피커 추가
import 'package:kfestival/guest_main.dart'; 
import 'package:kfestival/host_home.dart';
import 'package:kfestival/ui/liquid_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _isLoginMode = true; 
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // 🔥 사업자등록증 파일 변수
  XFile? _businessLicense; 
  final ImagePicker _picker = ImagePicker();

  // 이미지 선택 함수
  Future<void> _pickLicenseImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _businessLicense = image);
    }
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _pwController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")));
      return;
    }

    // 🔥 회원가입 시 서류 미첨부 차단
    if (!_isLoginMode && _businessLicense == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ 사업자등록증 또는 공연관계 확인서를 첨부해주세요.")));
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
        
        // 🔥 서류 업로드 로직
        String licenseUrl = '';
        if (_businessLicense != null) {
           final ref = FirebaseStorage.instance
               .ref()
               .child('host_documents/${userCredential.user!.uid}_license.jpg');
           
           if (kIsWeb) {
             // 웹 환경용
             await ref.putData(await _businessLicense!.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
           } else {
             // 모바일 환경용
             await ref.putFile(File(_businessLicense!.path));
           }
           
           licenseUrl = await ref.getDownloadURL();
        }

        // DB 저장 (pending 상태 + 서류 URL)
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'userType': 'host', 
          'status': 'pending', // 승인 대기
          'businessLicenseUrl': licenseUrl, // 서류 주소
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("가입 신청 완료! 관리자 승인 후 활동 가능합니다.")));
        }
      }

      // 로그인/가입 성공 후 이동
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
              Positioned(
                top: 10, right: 20,
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
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '공연/전시 주최자를 위한 파트너 공간입니다.',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),

                      _buildTextField(
                        controller: _emailController, 
                        label: "이메일", icon: Icons.email, isObscure: false, keyboardType: TextInputType.emailAddress
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _pwController, 
                        label: "비밀번호", icon: Icons.lock, isObscure: true, keyboardType: TextInputType.text
                      ),
                      
                      // 🔥 [추가] 회원가입 시에만 보이는 서류 업로드 버튼
                      if (!_isLoginMode) ...[
                         const SizedBox(height: 24),
                         const Divider(color: Colors.white24),
                         const SizedBox(height: 10),
                         const Text("⚠️ 신뢰 확인을 위해 증빙 서류가 필요합니다.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                         const SizedBox(height: 10),
                         InkWell(
                           onTap: _pickLicenseImage,
                           child: Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Colors.white10,
                               borderRadius: BorderRadius.circular(15),
                               border: Border.all(color: _businessLicense != null ? LiquidColors.cyanAccent : Colors.white24),
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Icon(_businessLicense != null ? Icons.check_circle : Icons.upload_file, color: _businessLicense != null ? LiquidColors.cyanAccent : Colors.white),
                                 const SizedBox(width: 10),
                                 Expanded(
                                   child: Text(
                                     _businessLicense != null ? "서류 첨부 완료 (${_businessLicense!.name})" : "사업자등록증/공연확인서 첨부",
                                     style: TextStyle(color: _businessLicense != null ? LiquidColors.cyanAccent : Colors.white, fontWeight: FontWeight.bold),
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                      ],

                      const SizedBox(height: 40),

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
                            ),
                            child: Text(
                              _isLoginMode ? "로그인" : "파트너 가입 완료",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isLoginMode ? "계정이 없으신가요?" : "이미 계정이 있으신가요?", style: const TextStyle(color: Colors.white70)),
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

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required bool isObscure, required TextInputType keyboardType}) {
    return LiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
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