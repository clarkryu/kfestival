import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kfestival/main.dart'; // LoginPage로 이동하기 위해 필요

class HostHomePage extends StatelessWidget {
  const HostHomePage({super.key});

  // 🔥 [추가] 로그아웃 함수
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      // 로그인 페이지로 이동 (뒤로 가기 없애기)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showApplicants(BuildContext context, String festivalId, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "'$title' 지원 현황",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('applications')
                      .where('festivalId', isEqualTo: festivalId)
                      .orderBy('appliedAt', descending: true)
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
                            Icon(Icons.people_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("아직 지원자가 없습니다."),
                          ],
                        ),
                      );
                    }
                    final apps = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: Colors.grey[50],
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple[100],
                              child: const Icon(Icons.person, color: Colors.deepPurple),
                            ),
                            title: Text(
                              app['artistName'] ?? '이름 없음',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("장르: ${app['artistGenre']}"),
                                Text("이메일: ${app['artistEmail']}", style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: const Chip(
                              label: Text('대기중', style: TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditor(BuildContext context, {DocumentSnapshot? doc}) async {
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : null;

    final titleController = TextEditingController(text: isEditing ? (data?['title'] ?? '') : '');
    final locationController = TextEditingController(text: isEditing ? (data?['location'] ?? '') : '');
    String selectedGenre = isEditing ? (data?['genre'] ?? '락/밴드') : '락/밴드';
    String? currentImageUrl = data?['image'] as String?;
    bool isRecruiting = isEditing ? (data?['isRecruiting'] ?? true) : true;

    File? newImageFile;
    final ImagePicker picker = ImagePicker();
    final List<String> genres = ['락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickImage() async {
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setState(() {
                newImageFile = File(image.path);
              });
            }
          }

          return AlertDialog(
            title: Text(isEditing ? '축제 정보 수정' : '새 축제 등록'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _buildImagePreview(newImageFile, currentImageUrl),
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
                      helperText: '주소를 수정하면 좌표도 다시 계산됩니다.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('장르 선택', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  DropdownButton<String>(
                    value: genres.contains(selectedGenre) ? selectedGenre : '락/밴드',
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
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isRecruiting ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isRecruiting ? Colors.green : Colors.grey),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        isRecruiting ? "아티스트 모집 중" : "모집 마감",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isRecruiting ? Colors.green[700] : Colors.grey,
                        ),
                      ),
                      subtitle: const Text("Artist 앱에 노출하려면 켜주세요"),
                      value: isRecruiting,
                      activeColor: Colors.green,
                      onChanged: (bool value) {
                        setState(() => isRecruiting = value);
                      },
                    ),
                  ),
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularProgressIndicator()),
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
                    if (titleController.text.isEmpty || locationController.text.isEmpty) return;
                    setState(() => isProcessing = true);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        String finalImageUrl = currentImageUrl ?? 'https://picsum.photos/400/200';
                        if (newImageFile != null) {
                          final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final Reference ref = FirebaseStorage.instance.ref().child('festivals/$fileName');
                          await ref.putFile(newImageFile!);
                          finalImageUrl = await ref.getDownloadURL();
                        }

                        double lat = 0.0;
                        double lng = 0.0;
                        if (isEditing) {
                          lat = (data?['latitude'] ?? 0.0).toDouble();
                          lng = (data?['longitude'] ?? 0.0).toDouble();
                        }
                        try {
                          List<Location> locations = await locationFromAddress(locationController.text);
                          if (locations.isNotEmpty) {
                            lat = locations.first.latitude;
                            lng = locations.first.longitude;
                          }
                        } catch (e) { print(e); }

                        final Map<String, dynamic> festivalData = {
                          'hostId': user.uid,
                          'title': titleController.text,
                          'location': locationController.text,
                          'genre': selectedGenre,
                          'date': '2025.05.23 ~ 05.25',
                          'image': finalImageUrl,
                          'latitude': lat,
                          'longitude': lng,
                          'isRecruiting': isRecruiting,
                        };

                        if (isEditing) {
                          await FirebaseFirestore.instance.collection('festivals').doc(doc.id).update(festivalData);
                        } else {
                          festivalData['createdAt'] = FieldValue.serverTimestamp();
                          await FirebaseFirestore.instance.collection('festivals').add(festivalData);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEditing ? '수정되었습니다! ✨' : '등록되었습니다! 🎉')),
                          );
                        }
                      }
                    } catch (e) { setState(() => isProcessing = false); }
                  },
                  child: Text(isEditing ? '수정 완료' : '등록'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(File? newFile, String? currentUrl) {
    if (newFile != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(newFile, fit: BoxFit.cover));
    } else if (currentUrl != null && currentUrl.isNotEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(currentUrl, fit: BoxFit.cover));
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text('포스터 사진 선택', style: TextStyle(color: Colors.grey))],
      );
    }
  }

  Future<void> _deleteFestival(BuildContext context, String docId) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('축제 삭제'),
        content: const Text('정말로 이 축제를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('festivals').doc(docId).delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다. 🗑️')));
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 축제 관리'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 🔥 [추가] 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('festivals').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          int totalCount = docs.length;
          int rockCount = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['genre'] ?? '') == '락/밴드';
          }).length;
          int otherCount = totalCount - rockCount;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(totalCount, rockCount, otherCount),
                const SizedBox(height: 24),
                const Text('등록된 축제 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text('등록된 축제가 없습니다.'))
                      : ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    data['image'] ?? '',
                                    width: 50, height: 50, fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
                                  ),
                                ),
                                title: Text(data['title'] ?? '제목 없음'),
                                subtitle: Text("${data['genre'] ?? '미정'} | ${data['location'] ?? '미정'}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.people, color: Colors.deepPurple),
                                      tooltip: "지원자 확인",
                                      onPressed: () => _showApplicants(context, doc.id, data['title'] ?? '축제'),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') _showEditor(context, doc: doc);
                                        else if (value == 'delete') _deleteFestival(context, doc.id);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                                        const PopupMenuItem(value: 'delete', child: Text('삭제하기', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('축제 등록'),
      ),
    );
  }

  Widget _buildSummaryCard(int total, int rock, int others) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(count: '$total', label: '전체 축제'),
          _SummaryItem(count: '$rock', label: '락/밴드'),
          _SummaryItem(count: '$others', label: '그 외'),
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
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }
}