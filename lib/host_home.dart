import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kfestival/main.dart';
import 'package:intl/intl.dart'; // 🔥 날짜 포맷용 패키지

class HostHomePage extends StatelessWidget {
  const HostHomePage({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _updateAppStatus(String appId, String newStatus) async {
    await FirebaseFirestore.instance.collection('applications').doc(appId).update({
      'status': newStatus,
    });
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
                      return const Center(child: Text("아직 지원자가 없습니다."));
                    }
                    final apps = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index].data() as Map<String, dynamic>;
                        final String status = app['status'] ?? 'pending';

                        return Card(
                          color: Colors.grey[50],
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple[100],
                              child: const Icon(Icons.person, color: Colors.deepPurple),
                            ),
                            title: Text(app['artistName'] ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("장르: ${app['artistGenre']}"),
                                Text("이메일: ${app['artistEmail']}", style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: status == 'pending'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        onPressed: () => _updateAppStatus(apps[index].id, 'accepted'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel, color: Colors.red),
                                        onPressed: () => _updateAppStatus(apps[index].id, 'rejected'),
                                      ),
                                    ],
                                  )
                                : Text(status == 'accepted' ? "수락됨" : "거절됨",
                                    style: TextStyle(color: status == 'accepted' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
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
    final descriptionController = TextEditingController(text: isEditing ? (data?['description'] ?? '') : '');
    
    String selectedMainGenre = isEditing ? (data?['genre'] ?? '락/밴드') : '락/밴드';
    String? currentImageUrl = data?['image'] as String?;
    
    // 🔥 [수정] 날짜 처리 로직 (Timestamp -> DateTime)
    DateTimeRange? selectedDateRange;
    if (isEditing && data?['startDate'] != null && data?['endDate'] != null) {
      selectedDateRange = DateTimeRange(
        start: (data!['startDate'] as Timestamp).toDate(),
        end: (data['endDate'] as Timestamp).toDate(),
      );
    }

    bool isRecruiting = isEditing ? (data?['isRecruiting'] ?? true) : true;
    final recruitDetailController = TextEditingController(text: isEditing ? (data?['recruitDetail'] ?? '') : '');
    
    List<dynamic> loadedTargets = isEditing ? (data?['targetGenres'] ?? []) : [];
    List<String> targetGenres = loadedTargets.map((e) => e.toString()).toList();

    File? newImageFile;
    final ImagePicker picker = ImagePicker();
    final List<String> allGenres = ['락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          Future<void> pickImage() async {
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setState(() => newImageFile = File(image.path));
            }
          }

          // 🔥 [추가] 날짜 선택 함수 (DateRangePicker)
          Future<void> pickDateRange() async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(), // 오늘 이전은 선택 불가
              lastDate: DateTime(2030),
              initialDateRange: selectedDateRange,
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
                  ),
                  child: child!,
                );
              }
            );
            if (picked != null) {
              setState(() => selectedDateRange = picked);
            }
          }

          // 날짜 텍스트 포맷팅 (예: 2025.05.23 ~ 05.25)
          String dateText = "날짜를 선택해주세요";
          if (selectedDateRange != null) {
            String start = DateFormat('yyyy.MM.dd').format(selectedDateRange!.start);
            String end = DateFormat('MM.dd').format(selectedDateRange!.end);
            dateText = "$start ~ $end";
          }

          return AlertDialog(
            title: Text(isEditing ? '축제 수정' : '새 축제 등록'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🎪 축제 기본 정보 (관객용)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _buildImagePreview(newImageFile, currentImageUrl),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '축제 제목', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: '장소 (주소)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    
                    // 🔥 [변경] 날짜 선택 UI
                    GestureDetector(
                      onTap: pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(
                              dateText,
                              style: TextStyle(
                                color: selectedDateRange == null ? Colors.grey[600] : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '축제 상세 소개',
                        hintText: '관객들에게 축제를 자세히 소개해 주세요.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('대표 장르 (카테고리)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButton<String>(
                      value: allGenres.contains(selectedMainGenre) ? selectedMainGenre : '락/밴드',
                      isExpanded: true,
                      items: allGenres.map((String genre) {
                        return DropdownMenuItem<String>(value: genre, child: Text(genre));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedMainGenre = val!),
                    ),

                    const Divider(height: 40, thickness: 2),

                    const Text("🎸 아티스트 모집 설정", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    SwitchListTile(
                      title: const Text("공연팀 모집하기"),
                      value: isRecruiting,
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => isRecruiting = val),
                    ),

                    if (isRecruiting) ...[
                      const Text('모집 장르 (다중 선택 가능)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 8.0,
                        children: allGenres.map((genre) {
                          final isSelected = targetGenres.contains(genre);
                          return FilterChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  targetGenres.add(genre);
                                } else {
                                  targetGenres.remove(genre);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: recruitDetailController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '모집 요강 / 우대 사항',
                          hintText: '예: 30분 공연 가능 팀, 자작곡 보유 우대 등',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],

                    if (isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: () async {
                  // 🔥 유효성 검사 (제목, 장소, 날짜 필수)
                  if (titleController.text.isEmpty || locationController.text.isEmpty || selectedDateRange == null) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목, 장소, 날짜는 필수입니다.')));
                     return;
                  }
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

                      // 🔥 날짜 문자열 생성 (표시용)
                      String dateString = "${DateFormat('yyyy.MM.dd').format(selectedDateRange!.start)} ~ ${DateFormat('MM.dd').format(selectedDateRange!.end)}";

                      final Map<String, dynamic> festivalData = {
                        'hostId': user.uid,
                        'title': titleController.text,
                        'location': locationController.text,
                        'description': descriptionController.text,
                        'genre': selectedMainGenre,
                        'date': dateString, // 표시용 문자열
                        'startDate': Timestamp.fromDate(selectedDateRange!.start), // 🔥 정렬/필터용 진짜 날짜
                        'endDate': Timestamp.fromDate(selectedDateRange!.end),     // 🔥 정렬/필터용 진짜 날짜
                        'image': finalImageUrl,
                        'latitude': lat,
                        'longitude': lng,
                        'isRecruiting': isRecruiting,
                        'recruitDetail': recruitDetailController.text,
                        'targetGenres': targetGenres,
                      };

                      if (isEditing) {
                        await FirebaseFirestore.instance.collection('festivals').doc(doc.id).update(festivalData);
                      } else {
                        festivalData['createdAt'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('festivals').add(festivalData);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다! ✨')));
                      }
                    }
                  } catch (e) { setState(() => isProcessing = false); }
                },
                child: const Text('저장'),
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
          IconButton(
            icon: const Icon(Icons.logout),
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