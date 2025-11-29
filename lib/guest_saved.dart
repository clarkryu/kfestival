import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart'; // 위치 계산용 (Geolocator 대신 사용하기도 함)
import 'package:geolocator/geolocator.dart';
import 'package:kfestival/ui/liquid_theme.dart'; // 🔥 새 테마 적용
import 'package:kfestival/festival_detail.dart';

class GuestSavedPage extends StatefulWidget {
  final Position? myPosition; // 내 위치 (거리 계산용)

  const GuestSavedPage({super.key, this.myPosition});

  @override
  State<GuestSavedPage> createState() => _GuestSavedPageState();
}

class _GuestSavedPageState extends State<GuestSavedPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _getDistance(Map<String, dynamic> data) {
    if (widget.myPosition == null || data['latitude'] == null || data['longitude'] == null) {
      return '';
    }

    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();

    if (lat == 0.0 && lng == 0.0) return '';

    double distanceInMeters = Geolocator.distanceBetween(
      widget.myPosition!.latitude,
      widget.myPosition!.longitude,
      lat,
      lng,
    );

    return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 배경이 앱바 뒤로 가게
      appBar: AppBar(
        title: const Text('My Favorite', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LiquidBackground( // 🔥 다크 코스믹 배경 적용
        child: SafeArea(
          child: _uid.isEmpty 
              ? _buildLoginRequired() 
              : _buildSavedList(),
        ),
      ),
    );
  }

  // 로그인 안 했을 때
  Widget _buildLoginRequired() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Colors.white54),
          SizedBox(height: 16),
          Text(
            "로그인이 필요한 기능입니다.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // 찜 목록 리스트
  Widget _buildSavedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('festivals')
          .where('likes', arrayContains: _uid) // 내 아이디가 likes에 포함된 것만
          // .orderBy('createdAt', descending: true) // 색인 없으면 에러나니 일단 주석 처리
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LiquidColors.cyanAccent));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  "아직 찜한 공연이 없어요.\n하트를 눌러보세요!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final String title = data['title'] ?? '제목 없음';
            final String location = data['location'] ?? '위치 미정';
            final String imageUrl = data['image'] ?? '';
            final bool isValidImage = imageUrl.startsWith('http');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LiquidGlassCard( // 🔥 리퀴드 카드 적용
                height: 120,
                glowColor: Colors.pinkAccent, // 찜 목록이니까 핑크빛 테두리
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FestivalDetailPage(data: data, festivalId: doc.id),
                    ),
                  );
                },
                child: Row(
                  children: [
                    // 이미지
                    Container(
                      width: 100,
                      height: 120,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.white12)),
                      ),
                      child: isValidImage
                          ? Image.network(
                              imageUrl, 
                              fit: BoxFit.cover,
                              errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white24),
                            )
                          : const Icon(Icons.image, color: Colors.white24),
                    ),
                    // 정보
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: LiquidColors.cyanAccent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 거리 표시
                            if (_getDistance(data).isNotEmpty)
                              Text(
                                _getDistance(data),
                                style: const TextStyle(color: LiquidColors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // 찜 취소 버튼 (쓰레기통)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white54),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('festivals').doc(doc.id).update({
                          'likes': FieldValue.arrayRemove([_uid])
                        });
                        if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("찜 목록에서 삭제되었습니다."))
                            );
                        }
                      },
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}