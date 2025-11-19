import 'package:flutter/material.dart';

class ArtistHomePage extends StatelessWidget {
  const ArtistHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아티스트 홈'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {}, // 내 프로필 수정
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 내 프로필 카드 (가짜 데이터)
            _buildProfileCard(),
            const SizedBox(height: 30),

            // 2. 모집 공고 타이틀
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔥 공연팀 모집 중인 축제',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '더보기 >',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. 모집 리스트 (가짜 데이터)
            _buildRecruitItem(
              title: '2025 대학로 거리 축제',
              date: '2025.05.10',
              genre: '버스킹 / 어쿠스틱',
              pay: '30만원',
            ),
            _buildRecruitItem(
              title: '부산 해변 썸머 페스티벌',
              date: '2025.08.01',
              genre: '락 / 밴드',
              pay: '협의 가능',
            ),
            _buildRecruitItem(
              title: '홍대 인디 뮤직 위크',
              date: '2025.06.15',
              genre: '인디 / 힙합',
              pay: '50만원',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurple, Colors.purpleAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지 (동그라미)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          // 텍스트 정보
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '밴드 Q-Rad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '장르: 락 / 모던락',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecruitItem({
    required String title,
    required String date,
    required String genre,
    required String pay,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.campaign, color: Colors.orange),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$date  |  $genre'),
            Text(
              '출연료: $pay',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            // 지원하기 기능 연결 예정
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(60, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('지원'),
        ),
      ),
    );
  }
}