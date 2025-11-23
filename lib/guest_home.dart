import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kfestival/main.dart';
import 'package:kfestival/festival_detail.dart';
import 'package:kfestival/guest_map.dart';
import 'package:kfestival/guest_saved.dart'; // 🔥 [추가] 찜 목록 페이지 연결

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
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        
        if (mounted) {
          setState(() {
            _myPosition = position;
          });
        }
      }
    } catch (e) {
      print("위치 확인 실패: $e");
    }
  }

  String _getDistance(Map<String, dynamic> data) {
    if (_myPosition == null || data['latitude'] == null || data['longitude'] == null) {
      return '- km';
    }

    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();

    if (lat == 0.0 && lng == 0.0) return '위치 미상';

    double distanceInMeters = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      lat,
      lng,
    );

    return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('festivals').orderBy('createdAt', descending: true);
    if (_selectedGenre != '전체') {
      query = query.where('genre', isEqualTo: _selectedGenre);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('축제 둘러보기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 검색 버튼
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "축제 검색",
            onPressed: () {
              showSearch(
                context: context,
                delegate: FestivalSearchDelegate(myPosition: _myPosition),
              );
            },
          ),
          // 🔥 [추가] 찜 목록(하트) 버튼
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            tooltip: "찜한 축제",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GuestSavedPage(myPosition: _myPosition),
                ),
              );
            },
          ),
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "로그아웃",
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
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
                    selectedColor: Colors.deepPurple.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.deepPurple : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedGenre = genre);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('현재 진행 중인 축제가 없습니다.'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildFestivalCard(context, data, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GuestMapPage(initialPosition: _myPosition),
            ),
          );
        },
        label: const Text('지도 보기'),
        icon: const Icon(Icons.map),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFestivalCard(BuildContext context, Map<String, dynamic> data, String docId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FestivalDetailPage(data: data, festivalId: docId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                data['image'] ?? '',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 180, color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
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
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['genre'] ?? '기타',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Text(
                            _getDistance(data),
                            style: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.deepPurple
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['title'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['location'] ?? '',
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 검색 기능 (기존 유지)
class FestivalSearchDelegate extends SearchDelegate {
  final Position? myPosition;

  FestivalSearchDelegate({this.myPosition});

  @override
  String get searchFieldLabel => '축제 이름 검색';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text("찾고 싶은 축제 이름을 입력하세요."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('festivals')
          .orderBy('title')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("검색 결과가 없습니다."));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    data['image'] ?? '',
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
                  ),
                ),
                title: Text(data['title'] ?? '제목 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['location'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FestivalDetailPage(data: data, festivalId: doc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}