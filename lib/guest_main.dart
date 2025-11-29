import 'package:flutter/material.dart';
import 'package:kfestival/ui/liquid_theme.dart';
import 'package:kfestival/guest_list.dart'; // 🔥 여기가 핵심! 리스트 및 검색 델리게이트 가져오기
import 'package:kfestival/login.dart';
import 'package:kfestival/utils/k_localization.dart';

class GuestMainPage extends StatefulWidget {
  const GuestMainPage({super.key});

  @override
  State<GuestMainPage> createState() => _GuestMainPageState();
}

class _GuestMainPageState extends State<GuestMainPage> {
  String _lang = 'en'; // 기본 언어

  // 아트 카테고리 정의 (4대장)
  final List<Map<String, dynamic>> _categories = [
    {'id': 'kpop', 'icon': Icons.music_note, 'color': Colors.pinkAccent},
    {'id': 'musical', 'icon': Icons.theater_comedy, 'color': Colors.orangeAccent},
    {'id': 'exhibition', 'icon': Icons.palette, 'color': Colors.cyanAccent},
    {'id': 'performance', 'icon': Icons.auto_awesome, 'color': Colors.purpleAccent},
  ];

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LiquidColors.darkCosmicMid.withOpacity(0.9),
        title: const Text("Choose Language", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['ko', 'en', 'ja', 'zh', 'es'].map((langCode) {
            return ListTile(
              title: Text(langCode.toUpperCase(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _lang = langCode);
                Navigator.pop(context);
              },
              trailing: _lang == langCode ? const Icon(Icons.check, color: LiquidColors.cyanAccent) : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 1. 언어 변경 버튼
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: _showLanguageDialog,
          ),
          // 2. 🔥 [연결] 통합 검색 버튼 -> guest_list.dart의 델리게이트 호출
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: FestivalSearchDelegate(lang: _lang), 
              );
            },
          ),
          // 3. 파트너 로그인 버튼
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: LiquidGlassCard(
              height: 36,
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(KLocalization.get(_lang, 'btn_partner_login'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // K-PODO 로고
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF7B2CBF), LiquidColors.darkCosmicBottom],
                      center: Alignment(-0.2, -0.2),
                      radius: 1.3,
                    ),
                    border: Border.all(color: LiquidColors.cyanAccent.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: LiquidColors.cyanAccent.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                      const BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 30, left: 30,
                        child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("K", style: TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w900, height: 1.0, shadows: [Shadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 5), Shadow(color: LiquidColors.cyanAccent, blurRadius: 15)])),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            width: 80, height: 2,
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, LiquidColors.cyanAccent.withOpacity(0.8), Colors.transparent])),
                          ),
                          const Text("PODO", style: TextStyle(color: LiquidColors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4.0)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text("Point of Do", style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2.0)),
                const SizedBox(height: 40),

                // 카테고리 그리드
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _buildMenuCard(cat['id'], cat['icon'], cat['color']);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(String category, IconData icon, Color accentColor) {
    return LiquidGlassCard(
      glowColor: accentColor, 
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GuestListPage(category: category, lang: _lang)),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.1),
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
            ),
            child: Icon(icon, size: 40, color: accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            KLocalization.getCategory(_lang, category),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}