import 'package:flutter/material.dart';

class FestivalDetailPage extends StatelessWidget {
  final Map<String, dynamic> data; // 목록에서 넘겨받은 축제 데이터

  const FestivalDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 이미지 공간을 확보하기 위해 CustomScrollView 사용
      body: CustomScrollView(
        slivers: [
          // 1. 상단 대형 이미지 (SliverAppBar)
          SliverAppBar(
            expandedHeight: 300.0, // 이미지 높이
            pinned: true, // 스크롤 내려도 상단바 고정
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                data['title'] ?? '축제 상세',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    data['image'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey),
                  ),
                  // 이미지 위에 검은 그라데이션 (글씨 잘 보이게)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 상세 내용 (SliverList)
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 장르 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['genre'] ?? '기타',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    Text(
                      data['title'] ?? '제목 없음',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // 날짜 & 장소
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(data['date'] ?? '날짜 미정'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(data['location'] ?? '위치 정보 없음')),
                      ],
                    ),
                    
                    const Divider(height: 40),

                    // 설명 (아직 DB에 설명 필드는 없지만 공간 확보)
                    const Text(
                      "축제 소개",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "이 축제는 ${data['location']}에서 열리는 ${data['genre']} 장르의 멋진 축제입니다. 많은 관심 부탁드립니다!",
                      style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    ),
                    
                    const SizedBox(height: 100), // 하단 여백
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}