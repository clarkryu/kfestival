import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kfestival/ui/liquid_theme.dart'; 

class FestivalDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String festivalId;
  final String initialLang; 

  const FestivalDetailPage({
    super.key, 
    required this.data,
    this.festivalId = '', 
    this.initialLang = 'ko', 
  });

  @override
  State<FestivalDetailPage> createState() => _FestivalDetailPageState();
}

class _FestivalDetailPageState extends State<FestivalDetailPage> {
  final translator = GoogleTranslator();
  String _currentLang = 'ko';
  
  String? _translatedTitle;
  String? _translatedDesc;
  String? _translatedLocation;
  
  bool _isTranslating = false;
  bool _isLiked = false;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  // 슬라이더용 컨트롤러
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
    if (widget.initialLang != 'ko') {
      _changeLanguage(widget.initialLang);
    }
  }

  void _checkLikeStatus() {
    List<dynamic> likes = widget.data['likes'] ?? [];
    setState(() {
      _isLiked = likes.contains(_uid);
    });
  }

  Future<void> _toggleLike() async {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인이 필요합니다.")));
      return;
    }
    setState(() => _isLiked = !_isLiked);
    
    final docRef = FirebaseFirestore.instance.collection('festivals').doc(widget.festivalId);
    if (_isLiked) {
      await docRef.update({'likes': FieldValue.arrayUnion([_uid])});
    } else {
      await docRef.update({'likes': FieldValue.arrayRemove([_uid])});
    }
  }

  Future<void> _changeLanguage(String langCode) async {
    if (_currentLang == langCode) return;

    if (langCode == 'ko') {
      setState(() {
        _currentLang = 'ko';
        _translatedTitle = null;
        _translatedDesc = null;
        _translatedLocation = null;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _currentLang = langCode;
    });

    try {
      var results = await Future.wait([
        translator.translate(widget.data['title'] ?? '', to: langCode),
        translator.translate(widget.data['description'] ?? '', to: langCode),
        translator.translate(widget.data['location'] ?? '', to: langCode),
      ]);

      if (mounted) {
        setState(() {
          _translatedTitle = results[0].text;
          _translatedDesc = results[1].text;
          _translatedLocation = results[2].text;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _launchMaps() async {
    final double lat = (widget.data['latitude'] ?? 0.0).toDouble();
    final double lng = (widget.data['longitude'] ?? 0.0).toDouble();
    final String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("지도를 열 수 없습니다.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayTitle = _translatedTitle ?? widget.data['title'] ?? 'No Title';
    final String displayDesc = _translatedDesc ?? widget.data['description'] ?? 'No Description';
    final String displayLocation = _translatedLocation ?? widget.data['location'] ?? 'Unknown';
    
    // 🔥 이미지 리스트 처리
    List<String> images = [];
    if (widget.data['images'] != null) {
      images = List<String>.from(widget.data['images']);
    } else if (widget.data['image'] != null && widget.data['image'].toString().isNotEmpty) {
      images.add(widget.data['image']);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.pinkAccent : Colors.white, shadows: const [Shadow(color: Colors.black, blurRadius: 10)]),
            onPressed: _toggleLike,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
            onSelected: _changeLanguage,
            itemBuilder: (context) => ['ko', 'en', 'ja', 'zh'].map((lang) => PopupMenuItem(value: lang, child: Text(lang.toUpperCase()))).toList(),
          ),
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 [수정] 이미지 슬라이더 (PageView)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: 400, // 높이를 조금 더 키움
                    width: double.infinity,
                    child: images.isNotEmpty
                      ? PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index], 
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54)),
                            );
                          },
                        )
                      : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54)),
                  ),
                  // 하단 그라데이션 (글씨 잘 보이게)
                  Container(
                    height: 100,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, LiquidColors.darkCosmicTop],
                      ),
                    ),
                  ),
                  // 인디케이터 (점)
                  if (images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: images.asMap().entries.map((entry) {
                          return Container(
                            width: 8.0,
                            height: 8.0,
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == entry.key
                                  ? LiquidColors.cyanAccent
                                  : Colors.white.withOpacity(0.4),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              
              // 상세 정보
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카테고리 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LiquidColors.cyanAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: LiquidColors.cyanAccent),
                      ),
                      child: Text(
                        widget.data['subCategory']?.toString().toUpperCase() ?? 'EVENT',
                        style: const TextStyle(color: LiquidColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _isTranslating 
                        ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(color: Colors.white))
                        : Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
                    
                    const SizedBox(height: 24),
                    
                    _buildInfoRow(Icons.calendar_today, widget.data['date'] ?? '날짜 미정'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on, displayLocation),
                    
                    const SizedBox(height: 30),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 20),
                    
                    const Text("About", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      displayDesc,
                      style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                    ),
                    
                    const SizedBox(height: 100), 
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      
      // 하단 버튼
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: LiquidColors.darkCosmicBottom,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _launchMaps,
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text("Map", style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("예매 기능 준비 중입니다! 🎟️")));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LiquidColors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 10,
                  shadowColor: LiquidColors.cyanAccent.withOpacity(0.5),
                ),
                child: const Text("Book Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}