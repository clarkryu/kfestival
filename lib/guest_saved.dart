import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart'; // 거리 계산용 (선택)
import 'package:geolocator/geolocator.dart';
import 'package:kfestival/festival_detail.dart';

class GuestSavedPage extends StatefulWidget {
  final Position? myPosition; // 거리 계산을 위해 내 위치를 받아옴

  const GuestSavedPage({super.key, this.myPosition});

  @override
  State<GuestSavedPage> createState() => _GuestSavedPageState();
}

class _GuestSavedPageState extends State<GuestSavedPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _getDistance(Map<String, dynamic> data) {
    if (widget.myPosition == null || data['latitude'] == null || data['longitude'] == null) {
      return '- km';
    }

    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();

    if (lat == 0.0 && lng == 0.0) return '위치 미상';

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
      appBar: AppBar(
        title: const Text('찜한 축제 목록 ❤️'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _uid.isEmpty 
          ? const Center(child: Text("로그인이 필요합니다."))
          : StreamBuilder<QuerySnapshot>(
              // 🔥 [핵심 쿼리] 'likes' 배열 안에 내 ID(_uid)가 들어있는 것만 가져옴
              stream: FirebaseFirestore.instance
                  .collection('festivals')
                  .where('likes', arrayContains: _uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "아직 찜한 축제가 없어요.\n마음에 드는 축제에 하트를 눌러보세요!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
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

                    return _buildSavedCard(context, data, doc.id);
                  },
                );
              },
            ),
    );
  }

  Widget _buildSavedCard(BuildContext context, Map<String, dynamic> data, String docId) {
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
        child: Row(
          children: [
            // 왼쪽: 작은 썸네일 이미지
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image.network(
                data['image'] ?? '',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 100, height: 100, color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            // 오른쪽: 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '제목 없음',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${data['date'] ?? ''} | ${data['genre'] ?? ''}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.deepPurple),
                        const SizedBox(width: 4),
                        Text(
                          _getDistance(data),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 찜 삭제 버튼 (편의성)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () async {
                // 여기서 바로 찜 취소
                await FirebaseFirestore.instance
                    .collection('festivals')
                    .doc(docId)
                    .update({
                      'likes': FieldValue.arrayRemove([_uid])
                    });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("목록에서 삭제되었습니다.")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}