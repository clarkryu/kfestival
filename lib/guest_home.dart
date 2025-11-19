import 'package:flutter/material.dart';

class GuestHomePage extends StatelessWidget {
  const GuestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 가짜 축제 데이터 (나중엔 서버에서 가져올 겁니다)
    final List<Map<String, String>> festivals = [
      {
        'title': '서울 재즈 페스티벌 2025',
        'date': '2025.05.23 ~ 05.25',
        'location': '서울 올림픽공원',
        'distance': '2.5km',
        'image': 'https://picsum.photos/id/1015/400/200', // 랜덤 이미지
      },
      {
        'title': '워터밤 서울 2025',
        'date': '2025.06.20 ~ 06.22',
        'location': '잠실 종합운동장',
        'distance': '5.1km',
        'image': 'https://picsum.photos/id/1040/400/200',
      },
      {
        'title': '부산 락 페스티벌',
        'date': '2025.10.04 ~ 10.06',
        'location': '부산 삼락생태공원',
        'distance': '320km',
        'image': 'https://picsum.photos/id/1050/400/200',
      },
      {
        'title': '전주 비빔 축제',
        'date': '2025.09.10 ~ 09.15',
        'location': '전주 한옥마을',
        'distance': '180km',
        'image': 'https://picsum.photos/id/1060/400/200',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 주변 페스티벌'), // 상단 제목
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}, // 나중에 검색 기능 연결
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {}, // 알림 버튼
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: festivals.length,
        itemBuilder: (context, index) {
          final festival = festivals[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 포스터 이미지 영역
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    festival['image']!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.broken_image)),
                      );
                    },
                  ),
                ),
                // 2. 텍스트 정보 영역
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            festival['title']!,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // 거리 표시 뱃지
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              festival['distance']!,
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            festival['date']!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            festival['location']!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}