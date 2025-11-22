import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kfestival/main.dart';
import 'package:kfestival/festival_detail.dart';

class ArtistHomePage extends StatefulWidget {
  const ArtistHomePage({super.key});

  @override
  State<ArtistHomePage> createState() => _ArtistHomePageState();
}

class _ArtistHomePageState extends State<ArtistHomePage> {
  String _teamName = "팀명 설정 필요";
  String _myGenre = "장르 미정";
  Set<String> _appliedFestivalIds = {};

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email != null) {
        _teamName = user.email!.split('@')[0];
      }
      _listenToMyApplications(user.uid);
    }
  }

  void _listenToMyApplications(String userId) {
    FirebaseFirestore.instance
        .collection('applications')
        .where('artistId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _appliedFestivalIds = snapshot.docs
                .map((doc) => doc['festivalId'] as String)
                .toSet();
          });
        });
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

  Future<void> _showProfileEditor() async {
    final nameController = TextEditingController(text: _teamName);
    String tempGenre = (_myGenre == "장르 미정") ? '락/밴드' : _myGenre;
    final List<String> genres = ['락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('프로필 설정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '팀/아티스트 이름'),
                ),
                const SizedBox(height: 16),
                const Text('주력 장르', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButton<String>(
                  value: genres.contains(tempGenre) ? tempGenre : '락/밴드',
                  isExpanded: true,
                  items: genres.map((String genre) {
                    return DropdownMenuItem<String>(
                      value: genre,
                      child: Text(genre),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      tempGenre = newValue!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _teamName = nameController.text;
                    _myGenre = tempGenre;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('프로필이 업데이트되었습니다! ✨')),
                  );
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleApplication(BuildContext context, String festivalId, String festivalTitle, String hostId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAlreadyApplied = _appliedFestivalIds.contains(festivalId);

    if (isAlreadyApplied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('지원 취소'),
            content: Text("'$festivalTitle' 지원을 취소하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('아니요'),
              ),
              TextButton(
                onPressed: () async {
                  final query = await FirebaseFirestore.instance
                      .collection('applications')
                      .where('festivalId', isEqualTo: festivalId)
                      .where('artistId', isEqualTo: user.uid)
                      .get();
                  
                  if (query.docs.isNotEmpty) {
                    await query.docs.first.reference.delete();
                  }

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("지원이 취소되었습니다.")),
                    );
                  }
                },
                child: const Text('네, 취소합니다', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }
    } else {
      await FirebaseFirestore.instance.collection('applications').add({
        'festivalId': festivalId,
        'festivalTitle': festivalTitle,
        'hostId': hostId,
        'artistId': user.uid,
        'artistName': _teamName,
        'artistGenre': _myGenre,
        'artistEmail': user.email,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$festivalTitle'에 지원 완료! 📨")),
        );
      }
    }
  }

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
            icon: const Icon(Icons.edit),
            tooltip: "프로필 수정",
            onPressed: _showProfileEditor,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "로그아웃",
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 30),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔥 공연팀 모집 중인 축제',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '실시간 업데이트',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('festivals')
                  .where('isRecruiting', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        "현재 모집 중인 축제가 없습니다.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildRecruitItem(
                      context,
                      doc.id,
                      data['title'] ?? '제목 없음',
                      data['date'] ?? '날짜 미정',
                      data['genre'] ?? '장르 미정',
                      data['location'] ?? '장소 미정',
                      data['hostId'] ?? '',
                      data, // 🔥 전체 데이터를 넘김 (상세페이지 이동용)
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _showProfileEditor,
      child: Container(
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
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '장르: $_myGenre',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, color: Colors.white70, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitItem(
    BuildContext context, 
    String festivalId,
    String title, 
    String date, 
    String genre, 
    String location,
    String hostId,
    Map<String, dynamic> data, // 🔥 상세 페이지로 넘길 전체 데이터
  ) {
    bool isApplied = _appliedFestivalIds.contains(festivalId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // 🔥 클릭하면 상세 페이지로 이동
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FestivalDetailPage(
                data: data,
                isArtistMode: true, // 🔥 [핵심] "나 아티스트야!" 라고 알려줌
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.campaign, color: Colors.orange),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('$date  |  $genre'),
              Text(location, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () => _handleApplication(context, festivalId, title, hostId),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApplied ? Colors.green : Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: isApplied 
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.check, size: 16), SizedBox(width: 4), Text('완료')],
                )
              : const Text('지원'),
          ),
        ),
      ),
    );
  }
}