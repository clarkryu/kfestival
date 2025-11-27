import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:kpostal/kpostal.dart'; 
import 'package:kfestival/login.dart';
import 'package:kfestival/guest_main.dart'; 
import 'package:kfestival/ui/liquid_theme.dart'; 
import 'package:kfestival/utils/k_localization.dart'; // 카테고리 이름 가져오기용

class HostHomePage extends StatefulWidget {
  const HostHomePage({super.key});

  @override
  State<HostHomePage> createState() => _HostHomePageState();
}

class _HostHomePageState extends State<HostHomePage> {
  // 🔥 [수정] 게스트 화면과 100% 일치하는 카테고리 정의 (키값 기준)
  final Map<String, List<String>> _categoryMap = {
    'kpop': ['idol', 'hiphop'],
    'musical': ['theater', 'big_musical'],
    'exhibition': ['gallery', 'museum'],
    'performance': ['nanta', 'magic'],
  };

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const GuestMainPage()),
        (route) => false,
      );
    }
  }

  void _goToGuestMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GuestMainPage()),
    );
  }

  // 🔥 [삭제됨] 지원자 관리 함수 (_showApplicants) -> 아티스트 모집 기능 삭제로 불필요

  // 축제 등록/수정 에디터
  Future<void> _showEditor(BuildContext context, {DocumentSnapshot? doc}) async {
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : null;

    final titleController = TextEditingController(text: data?['title'] ?? '');
    final locationController = TextEditingController(text: data?['location'] ?? '');
    final descriptionController = TextEditingController(text: data?['description'] ?? '');
    
    // 🔥 [삭제됨] recruitDetailController (모집 요강 입력창 삭제)

    double selectedLat = (data?['latitude'] ?? 0.0).toDouble();
    double selectedLng = (data?['longitude'] ?? 0.0).toDouble();
    String? currentImageUrl = data?['image'];
    
    File? newImageFile;
    Uint8List? newImageBytes;
    
    DateTimeRange? selectedDateRange;
    if (isEditing && data?['startDate'] != null && data?['endDate'] != null) {
      selectedDateRange = DateTimeRange(
        start: (data!['startDate'] as Timestamp).toDate(),
        end: (data['endDate'] as Timestamp).toDate(),
      );
    }

    String selectedCategory = 'kpop';
    String selectedSubCategory = 'idol';

    if (data != null) {
      if (data['category'] != null && _categoryMap.containsKey(data['category'])) {
        selectedCategory = data['category'];
      }
      if (data['subCategory'] != null && 
          _categoryMap[selectedCategory]!.contains(data['subCategory'])) {
        selectedSubCategory = data['subCategory'];
      } else {
        selectedSubCategory = _categoryMap[selectedCategory]!.first;
      }
    }

    // 🔥 [삭제됨] isRecruiting 변수 삭제

    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          Future<void> searchAddress() async {
             if (kIsWeb) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("웹에서는 주소를 직접 입력해주세요.")));
               return;
             }

             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KpostalView(
                  callback: (Kpostal result) async {
                    locationController.text = result.address;
                    try {
                      List<Location> locations = await locationFromAddress(result.address);
                      if (locations.isNotEmpty) {
                        setState(() {
                          selectedLat = locations.first.latitude;
                          selectedLng = locations.first.longitude;
                        });
                      }
                    } catch (e) {
                      if (result.latitude != null) {
                        setState(() {
                          selectedLat = result.latitude!;
                          selectedLng = result.longitude!;
                        });
                      }
                    }
                  },
                ),
              ),
            );
          }

          Future<void> pickDateRange() async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
              initialDateRange: selectedDateRange,
            );
            if (picked != null) setState(() => selectedDateRange = picked);
          }

          Future<void> pickImage() async {
            final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (pickedFile != null) {
              if (kIsWeb) {
                final bytes = await pickedFile.readAsBytes();
                setState(() => newImageBytes = bytes);
              } else {
                setState(() => newImageFile = File(pickedFile.path));
              }
            }
          }

          Widget buildImageWidget() {
            if (kIsWeb && newImageBytes != null) {
              return Image.memory(newImageBytes!, fit: BoxFit.cover);
            } else if (!kIsWeb && newImageFile != null) {
              return Image.file(newImageFile!, fit: BoxFit.cover);
            } else if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
              return Image.network(currentImageUrl, fit: BoxFit.cover);
            }
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [Icon(Icons.add_a_photo, color: Colors.white, size: 40), Text("포스터 등록", style: TextStyle(color: Colors.white))]
              )
            );
          }

          return Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [LiquidColors.darkCosmicTop, LiquidColors.darkCosmicBottom],
                  ),
                  border: Border.all(color: LiquidColors.cyanAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                          Text(isEditing ? "공연 수정" : "새 공연 등록", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () async {
                               if (titleController.text.isEmpty || locationController.text.isEmpty || selectedDateRange == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목, 장소, 날짜는 필수입니다.')));
                                  return;
                                }
                                setState(() => isProcessing = true);
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    String finalImageUrl = currentImageUrl ?? '';
                                    
                                    try {
                                      if (kIsWeb && newImageBytes != null) {
                                        final ref = FirebaseStorage.instance.ref().child('festivals/${DateTime.now().millisecondsSinceEpoch}.jpg');
                                        await ref.putData(newImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
                                        finalImageUrl = await ref.getDownloadURL();
                                      } else if (!kIsWeb && newImageFile != null) {
                                        final ref = FirebaseStorage.instance.ref().child('festivals/${DateTime.now().millisecondsSinceEpoch}.jpg');
                                        await ref.putFile(newImageFile!);
                                        finalImageUrl = await ref.getDownloadURL();
                                      }
                                    } catch (imgError) {
                                      print("이미지 업로드 실패: $imgError");
                                    }

                                    final festivalData = {
                                      'hostId': user.uid,
                                      'title': titleController.text,
                                      'location': locationController.text,
                                      'description': descriptionController.text,
                                      'category': selectedCategory,
                                      'subCategory': selectedSubCategory,
                                      'date': "${DateFormat('yyyy.MM.dd').format(selectedDateRange!.start)} ~ ${DateFormat('MM.dd').format(selectedDateRange!.end)}",
                                      'startDate': Timestamp.fromDate(selectedDateRange!.start),
                                      'endDate': Timestamp.fromDate(selectedDateRange!.end),
                                      'image': finalImageUrl,
                                      'latitude': selectedLat,
                                      'longitude': selectedLng,
                                      // 🔥 [삭제됨] isRecruiting, recruitDetail 필드 삭제
                                      'createdAt': isEditing ? data!['createdAt'] : FieldValue.serverTimestamp(),
                                    };

                                    if (isEditing) {
                                      await FirebaseFirestore.instance.collection('festivals').doc(doc!.id).update(festivalData);
                                    } else {
                                      await FirebaseFirestore.instance.collection('festivals').add(festivalData);
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다! ✨')));
                                    }
                                  }
                                } catch (e) { 
                                  setState(() => isProcessing = false);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
                                }
                            },
                            child: const Text("저장", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: pickImage,
                              child: LiquidGlassCard(
                                height: 200,
                                width: double.infinity,
                                child: buildImageWidget(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LiquidGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildTextField(titleController, "공연 제목"),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: searchAddress,
                                      child: AbsorbPointer(
                                        absorbing: !kIsWeb, 
                                        child: _buildTextField(
                                          locationController, 
                                          kIsWeb ? "장소 (직접 입력)" : "장소 (터치하여 검색)", 
                                          icon: Icons.map
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: pickDateRange,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.white30), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, color: Colors.white70),
                                            const SizedBox(width: 10),
                                            Text(selectedDateRange == null ? "날짜 선택" : "${DateFormat('yyyy.MM.dd').format(selectedDateRange!.start)} ~ ${DateFormat('MM.dd').format(selectedDateRange!.end)}", style: const TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LiquidGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("카테고리 설정", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: selectedCategory,
                                      dropdownColor: LiquidColors.darkCosmicMid,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _inputDeco("대분류"),
                                      items: _categoryMap.keys.map((cat) {
                                        // 🔥 [수정] 단어장에서 번역된 이름 가져오기 (KLocalization 사용)
                                        // 여기서는 일단 키값(cat) 앞에 'cat_'을 붙여서 찾음 (예: cat_kpop)
                                        return DropdownMenuItem(value: cat, child: Text(KLocalization.get('ko', 'cat_$cat')));
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          selectedCategory = val!;
                                          selectedSubCategory = _categoryMap[val]!.first;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: selectedSubCategory,
                                      dropdownColor: LiquidColors.darkCosmicMid,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _inputDeco("소분류"),
                                      items: _categoryMap[selectedCategory]!.map((sub) {
                                        // 🔥 [수정] 소분류도 단어장에서 가져오기 (예: sub_idol)
                                        return DropdownMenuItem(value: sub, child: Text(KLocalization.get('ko', 'sub_$sub')));
                                      }).toList(),
                                      onChanged: (val) => setState(() => selectedSubCategory = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LiquidGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildTextField(descriptionController, "공연 상세 소개 (500자 이내)", maxLines: 5),
                                    // 🔥 [삭제됨] 공연팀 모집하기 스위치 삭제됨
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (isProcessing) const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white30), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, IconData? icon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
      ),
    );
  }

  Future<void> _deleteFestival(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('festivals').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: LiquidBackground(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('내 공연 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.admin_panel_settings), 
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _goToGuestMode,
              icon: const Icon(Icons.home_filled, size: 18),
              label: const Text("Main 화면", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent, 
                foregroundColor: Colors.black, 
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(),
            tooltip: "로그아웃",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LiquidGlassCard(
                  onTap: () => _showEditor(context),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.add_circle, color: Colors.cyanAccent, size: 30), SizedBox(width: 10), Text("새 공연 등록하기", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('festivals').where('hostId', isEqualTo: user.uid).orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return const Center(child: Text("등록된 공연이 없습니다.", style: TextStyle(color: Colors.white70)));
                      
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          
                          // 🔥 [안전장치]
                          final String title = data['title']?.toString() ?? '제목 없음';
                          final String displayCategory = data['category']?.toString().toUpperCase() ?? 'KPOP';
                          final String subCategory = data['subCategory']?.toString() ?? 'IDOL';
                          final String imageUrl = data['image']?.toString() ?? '';

                          final bool isValidImage = imageUrl.startsWith('http');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LiquidGlassCard(
                              onTap: () => _showEditor(context, doc: docs[index]),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8), 
                                  child: isValidImage
                                    ? Image.network(
                                        imageUrl, 
                                        width: 50, height: 50, fit: BoxFit.cover, 
                                        errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.white)
                                      )
                                    : const SizedBox(width: 50, height: 50, child: Icon(Icons.image, color: Colors.white54)),
                                ),
                                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text("$displayCategory / $subCategory", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                // 🔥 [수정] 지원자 보기 버튼 삭제됨 (대신 수정/삭제 팝업 메뉴 등 추가 가능)
                                trailing: const Icon(Icons.edit, color: Colors.white54, size: 20),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}