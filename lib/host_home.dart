import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // DB 패키지
import 'package:firebase_auth/firebase_auth.dart'; // 내 UID 가져오기용

class HostHomePage extends StatelessWidget {
  const HostHomePage({super.key});

  // 🔥 DB에 축제 데이터 추가하는 함수 (이게 있어야 팝업이 뜹니다!)
  Future<void> _addFestival(BuildContext context) async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();

    // 입력 다이얼로그 띄우기
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 축제 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '축제 이름'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: '장소 (예: 서울 올림픽공원)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                
                if (user != null) {
                  // Firestore에 데이터 저장 (Create)
                  await FirebaseFirestore.instance.collection('festivals').add({
                    'hostId': user.uid,
                    'title': titleController.text,
                    'location': locationController.text,
                    'date': '2025.05.23 ~ 05.25',
                    'distance': '계산중...',
                    'image': 'https://picsum.photos/400/200',
                    'createdAt': FieldValue.serverTimestamp(),
                    'isRecruiting': true,
                  });
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('축제가 등록되었습니다! 🎉')),
                    );
                  }
                }
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 축제 관리'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            const Text(
              '등록된 축제 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 🔥 실시간 데이터 보여주기 (StreamBuilder)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('festivals')
                    .where('hostId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            '아직 등록된 축제가 없습니다.\n새로운 축제를 만들어보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              data['image'] ?? '', 
                              width: 50, 
                              height: 50, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.image_not_supported),
                            ),
                          ),
                          title: Text(data['title'] ?? '제목 없음'),
                          subtitle: Text(data['location'] ?? '장소 미정'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // 🔥 버튼 클릭 시 _addFestival 함수 실행
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFestival(context), 
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('축제 등록'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(count: '0', label: '진행중'),
          _SummaryItem(count: '0', label: '예정됨'),
          _SummaryItem(count: '0', label: '종료됨'),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String count;
  final String label;

  const _SummaryItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}