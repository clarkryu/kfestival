import 'dart:io'; // 파일 처리를 위해 필수
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart'; // 위치 변환
import 'package:image_picker/image_picker.dart'; // 갤러리 접근
import 'package:firebase_storage/firebase_storage.dart'; // 사진 저장소

class HostHomePage extends StatelessWidget {
  const HostHomePage({super.key});

  // DB에 축제 데이터 추가하는 함수
  Future<void> _addFestival(BuildContext context) async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    
    String selectedGenre = '락/밴드';
    final List<String> genres = ['락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];
    
    // 이미지 담을 변수
    File? selectedImage;
    final ImagePicker picker = ImagePicker();
    
    // 로딩 상태 관리
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          // 내부 함수: 이미지 선택하기
          Future<void> pickImage() async {
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setState(() {
                selectedImage = File(image.path);
              });
            }
          }

          return AlertDialog(
            title: const Text('새 축제 등록'),
            content: SingleChildScrollView( // 화면이 길어질 수 있어 스크롤 추가
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 이미지 선택 영역 (UI)
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                        image: selectedImage != null
                            ? DecorationImage(
                                image: FileImage(selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('포스터 사진 선택', style: TextStyle(color: Colors.grey)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '축제 이름'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: '주소 (예: 서울시 강남구)',
                      helperText: '실제 주소를 입력해야 지도에 표시됩니다.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('장르 선택', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<String>(
                    value: selectedGenre,
                    isExpanded: true,
                    items: genres.map((String genre) {
                      return DropdownMenuItem<String>(
                        value: genre,
                        child: Text(genre),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() => selectedGenre = newValue!);
                    },
                  ),
                  
                  // 로딩 중 표시
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("사진 업로드 중..."),
                        ],
                      )),
                    ),
                ],
              ),
            ),
            actions: [
              if (!isProcessing)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              if (!isProcessing)
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty || locationController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목과 주소를 입력해주세요.')));
                       return;
                    }
                    
                    // 로딩 시작
                    setState(() => isProcessing = true);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        
                        // A. 이미지 업로드 로직
                        String imageUrl = 'https://picsum.photos/400/200'; // 기본값 (랜덤)
                        
                        if (selectedImage != null) {
                          // 1. 파일 이름 만들기 (중복 방지용 시간값 포함)
                          final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                          // 2. 저장소 위치 지정 (festivals 폴더 안)
                          final Reference ref = FirebaseStorage.instance.ref().child('festivals/$fileName');
                          // 3. 파일 업로드
                          await ref.putFile(selectedImage!);
                          // 4. 다운로드 URL 받기
                          imageUrl = await ref.getDownloadURL();
                        }

                        // B. 위치 변환 로직 (Geocoding)
                        double lat = 0.0;
                        double lng = 0.0;
                        try {
                          List<Location> locations = await locationFromAddress(locationController.text);
                          if (locations.isNotEmpty) {
                            lat = locations.first.latitude;
                            lng = locations.first.longitude;
                          }
                        } catch (e) {
                          print("주소 변환 실패: $e");
                        }

                        // C. Firestore 저장 (이미지 URL 포함)
                        await FirebaseFirestore.instance.collection('festivals').add({
                          'hostId': user.uid,
                          'title': titleController.text,
                          'location': locationController.text,
                          'genre': selectedGenre,
                          'date': '2025.05.23 ~ 05.25',
                          'image': imageUrl, // 🔥 실제 업로드된 URL 저장
                          'createdAt': FieldValue.serverTimestamp(),
                          'isRecruiting': true,
                          'latitude': lat,
                          'longitude': lng,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('포스터와 함께 축제가 등록되었습니다! 📸')),
                          );
                        }
                      }
                    } catch (e) {
                      print("에러 발생: $e");
                      if(context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
                      }
                      setState(() => isProcessing = false);
                    }
                  },
                  child: const Text('등록'),
                ),
            ],
          );
        },
      ),
    );
  }

  // 메인 UI (변경 없음)
  @override
  Widget build(BuildContext context) {
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
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('festivals')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('등록된 축제가 없습니다.'));
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
                            // 이미지 URL 로딩
                            child: Image.network(
                              data['image'] ?? '', 
                              width: 50, 
                              height: 50, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(width:50, height:50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                              },
                            ),
                          ),
                          title: Text(data['title'] ?? '제목 없음'),
                          subtitle: Text("${data['genre'] ?? '장르 미정'} | ${data['location'] ?? ''}"),
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