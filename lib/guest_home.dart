import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kfestival/login.dart';
import 'package:kfestival/festival_detail.dart';
import 'package:kfestival/guest_map.dart';
import 'package:kfestival/guest_saved.dart';
import 'package:kfestival/ui/liquid_theme.dart'; // 🔥 테마 임포트

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  Position? _myPosition;
  String _selectedGenre = '전체';
  final List<String> _genres = ['전체', '락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
        if (mounted) setState(() => _myPosition = position);
      }
    } catch (e) { print(e); }
  }

  String _getDistance(Map<String, dynamic> data) {
    if (_myPosition == null || data['latitude'] == null || data['longitude'] == null) return '- km';
    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();
    if (lat == 0.0 && lng == 0.0) return '';
    double dist = Geolocator.distanceBetween(_myPosition!.latitude, _myPosition!.longitude, lat, lng);
    return '${(dist / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('festivals').orderBy('createdAt', descending: true);
    if (_selectedGenre != '전체') query = query.where('genre', isEqualTo: _selectedGenre);

    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 앱바 뒤까지 배경 확장
      appBar: AppBar(
        title: const Text('K-Festival', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => showSearch(context: context, delegate: FestivalSearchDelegate(myPosition: _myPosition))),
          IconButton(icon: const Icon(Icons.favorite, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GuestSavedPage(myPosition: _myPosition)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: LiquidBackground( // 🔥 전체 파란 배경
        child: SafeArea(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: _genres.map((genre) {
                    final isSelected = _selectedGenre == genre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: isSelected,
                        selectedColor: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? LiquidColors.deepBlue : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) => setState(() => _selectedGenre = genre),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('축제가 없습니다.', style: TextStyle(color: Colors.white)));

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        // 🔥 [수정] Card 대신 LiquidGlassCard 사용
                        return _buildGlassCard(context, data, docs[index].id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GuestMapPage(initialPosition: _myPosition))),
        label: const Text("지도 보기", style: TextStyle(color: LiquidColors.deepBlue, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.map, color: LiquidColors.deepBlue),
        backgroundColor: Colors.white,
      ),
    );
  }

  // 🔥 [새로 만든 위젯] 유리 카드 디자인
  Widget _buildGlassCard(BuildContext context, Map<String, dynamic> data, String docId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard( // Card 대신 커스텀 유리 카드 사용
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FestivalDetailPage(data: data, festivalId: docId)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              data['image'] ?? '',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(height: 180, color: Colors.white24, child: const Icon(Icons.broken_image, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        child: Text(data['genre'] ?? '기타', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                      Text(_getDistance(data), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(data['title'] ?? '제목 없음', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(data['location'] ?? '', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 검색 델리게이트 (기존 유지하되 배경색 등을 맞추고 싶다면 수정 가능, 일단 기능 유지)
class FestivalSearchDelegate extends SearchDelegate {
  final Position? myPosition;
  FestivalSearchDelegate({this.myPosition});
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text("축제 이름을 입력하세요."));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('festivals').orderBy('title').startAt([query]).endAt(['$query\uf8ff']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['title'] ?? ''),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FestivalDetailPage(data: data, festivalId: docs[index].id))),
            );
          },
        );
      },
    );
  }
}