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
import 'package:kfestival/utils/k_localization.dart'; 

class HostHomePage extends StatefulWidget {
  const HostHomePage({super.key});

  @override
  State<HostHomePage> createState() => _HostHomePageState();
}

class _HostHomePageState extends State<HostHomePage> {
  final Map<String, List<String>> _categoryMap = {
    'kpop': ['idol', 'hiphop'],
    'musical': ['theater', 'big_musical'],
    'exhibition': ['gallery', 'museum'],
    'performance': ['nanta', 'magic'],
  };

  final Map<String, String> _langOptions = {
    'eng_sub': '🇺🇸 Eng Sub',
    'jp_sub': '🇯🇵 JP Sub',
    'cn_sub': '🇨🇳 CN Sub',
    'non_verbal': '🤐 Non-verbal',
  };

  // 🔥 [NEW] 호스트 상태 확인 변수
  String _hostStatus = 'pending'; 

  @override
  void initState() {
    super.initState();
    _checkHostStatus(); // 들어오자마자 내 상태(active/pending) 확인
  }

  // 🔥 [NEW] 내 상태 DB에서 가져오기
  Future<void> _checkHostStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _hostStatus = doc.data()?['status'] ?? 'pending';
        });
      }
    }
  }

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

  // 🔥 [NEW] 글쓰기 버튼 클릭 시 검문소 역할
  void _handleWriteButton() {
    if (_hostStatus == 'pending') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: LiquidColors.darkCosmicMid,
          title: const Row(children: [Icon(Icons.lock_clock, color: Colors.orangeAccent), SizedBox(width: 10), Text("승인 대기 중", style: TextStyle(color: Colors.white))]),
          content: const Text(
            "제출하신 서류를 관리자가 검토 중입니다.\n승인이 완료되면 공연을 등록하실 수 있습니다.\n(영업일 기준 1~2일 소요)",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("확인", style: TextStyle(color: LiquidColors.cyanAccent)),
            ),
          ],
        ),
      );
    } else {
      // 승인된(active) 유저만 에디터 열기
      _showEditor(context);
    }
  }

  Future<void> _deleteFestival(String docId) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidColors.darkCosmicMid,
        title: const Text("공연 삭제", style: TextStyle(color: Colors.white)),
        content: const Text("정말로 이 공연 정보를 삭제하시겠습니까?\n복구할 수 없습니다.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('festivals').doc(docId).delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제되었습니다.")));
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('festivals').doc(docId).update({
      'isActive': !currentStatus,
    });
    String msg = !currentStatus ? "공연이 공개되었습니다. (Active)" : "공연이 비공개 처리되었습니다. (Inactive)";
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 축제 등록/수정 에디터
  Future<void> _showEditor(BuildContext context, {DocumentSnapshot? doc}) async {
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : null;

    final titleController = TextEditingController(text: data?['title'] ?? '');
    final locationController = TextEditingController(text: data?['location'] ?? '');
    final descriptionController = TextEditingController(text: data?['description'] ?? '');

    double selectedLat = (data?['latitude'] ?? 0.0).toDouble();
    double selectedLng = (data?['longitude'] ?? 0.0).toDouble();
    
    List<dynamic> currentImageUrls = [];
    if (data != null) {
      if (data['images'] != null) {
        currentImageUrls = List.from(data['images']);
      } else if (data['image'] != null && data['image'].toString().isNotEmpty) {
        currentImageUrls.add(data['image']);
      }
    }

    List<XFile> newImages = [];
    
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
    
    bool isActive = data?['isActive'] ?? true;

    // 언어 지원 옵션 초기화
    List<String> selectedLanguages = [];
    if (data != null && data['languageSupport'] != null) {
      selectedLanguages = List<String>.from(data['languageSupport']);
    }

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

          Future<void> pickImages() async {
            try {
              final List<XFile> pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 70);
              if (pickedFiles.isNotEmpty) {
                int totalCount = currentImageUrls.length + newImages.length + pickedFiles.length;
                if (totalCount > 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("사진은 최대 10장까지 등록 가능합니다.")));
                  return;
                }
                List<XFile> validFiles = [];
                for (var file in pickedFiles) {
                  int sizeInBytes = await file.length();
                  double sizeInMB = sizeInBytes / (1024 * 1024);
                  if (sizeInMB > 5.0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${file.name}은 5MB를 초과하여 제외되었습니다.")));
                  } else {
                    validFiles.add(file);
                  }
                }
                setState(() {
                  newImages.addAll(validFiles);
                });
              }
            } catch (e) {
              print("이미지 선택 오류: $e");
            }
          }

          Widget buildImageGallery() {
            int totalCount = currentImageUrls.length + newImages.length;
            return Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                children: [
                  if (totalCount < 10)
                    GestureDetector(
                      onTap: pickImages,
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LiquidColors.cyanAccent.withOpacity(0.5)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, color: LiquidColors.cyanAccent),
                            const SizedBox(height: 4),
                            Text("${totalCount}/10", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ...currentImageUrls.asMap().entries.map((entry) {
                    int idx = entry.key;
                    String url = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover)),
                        ),
                        Positioned(top: 2, right: 12, child: GestureDetector(onTap: () => setState(() => currentImageUrls.removeAt(idx)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                      ],
                    );
                  }).toList(),
                  ...newImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    XFile file = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover)),
                        ),
                        Positioned(top: 2, right: 12, child: GestureDetector(onTap: () => setState(() => newImages.removeAt(idx)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)))),
                      ],
                    );
                  }).toList(),
                ],
              ),
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
                                if (currentImageUrls.isEmpty && newImages.isEmpty) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최소 1장의 사진을 등록해주세요.')));
                                   return;
                                }
                                setState(() => isProcessing = true);
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    List<String> finalImageUrls = [...List<String>.from(currentImageUrls)];
                                    for (var imageFile in newImages) {
                                      try {
                                        final ref = FirebaseStorage.instance.ref().child('festivals/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}');
                                        if (kIsWeb) {
                                          final bytes = await imageFile.readAsBytes();
                                          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
                                        } else {
                                          await ref.putFile(File(imageFile.path));
                                        }
                                        String url = await ref.getDownloadURL();
                                        finalImageUrls.add(url);
                                      } catch (e) { print("이미지 업로드 실패: $e"); }
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
                                      'images': finalImageUrls, 
                                      'image': finalImageUrls.isNotEmpty ? finalImageUrls[0] : '', 
                                      'latitude': selectedLat,
                                      'longitude': selectedLng,
                                      'isActive': isActive,
                                      'languageSupport': selectedLanguages, 
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
                            buildImageGallery(),
                            const SizedBox(height: 16),
                            LiquidGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("공연 공개 설정", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    Row(
                                      children: [
                                        Text(isActive ? "공개 (Active)" : "비공개 (Hidden)", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.white54, fontSize: 12)),
                                        Switch(
                                          value: isActive,
                                          activeColor: Colors.greenAccent,
                                          onChanged: (val) => setState(() => isActive = val),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 카테고리
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
                                        return DropdownMenuItem(value: sub, child: Text(KLocalization.get('ko', 'sub_$sub')));
                                      }).toList(),
                                      onChanged: (val) => setState(() => selectedSubCategory = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // 외국인 관람 옵션
                            LiquidGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.language, color: Colors.orangeAccent, size: 20),
                                        const SizedBox(width: 8),
                                        const Text("외국인 관람 옵션 (다중 선택)", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: _langOptions.entries.map((entry) {
                                        final isSelected = selectedLanguages.contains(entry.key);
                                        return FilterChip(
                                          label: Text(entry.value),
                                          selected: isSelected,
                                          onSelected: (bool selected) {
                                            setState(() {
                                              if (selected) {
                                                selectedLanguages.add(entry.key);
                                              } else {
                                                selectedLanguages.remove(entry.key);
                                              }
                                            });
                                          },
                                          selectedColor: Colors.orangeAccent.withOpacity(0.3),
                                          checkmarkColor: Colors.orangeAccent,
                                          labelStyle: TextStyle(
                                            color: isSelected ? Colors.orangeAccent : Colors.white70,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          backgroundColor: Colors.black26,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(color: isSelected ? Colors.orangeAccent : Colors.white24),
                                          ),
                                        );
                                      }).toList(),
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
                                    _buildTextField(titleController, "공연 제목"),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: searchAddress,
                                      child: AbsorbPointer(
                                        absorbing: !kIsWeb, 
                                        child: _buildTextField(locationController, kIsWeb ? "장소 (직접 입력)" : "장소 (터치하여 검색)", icon: Icons.map),
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
                                child: _buildTextField(descriptionController, "공연 상세 소개 (500자 이내)", maxLines: 5, maxLength: 500),
                              ),
                            ),
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

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, IconData? icon, int? maxLength}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
        counterStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: LiquidBackground(child: Center(child: CircularProgressIndicator(color: Colors.white))),
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
                  // 🔥 [핵심] 기존: 바로 _showEditor 호출 / 변경: _handleWriteButton 호출 (권한 체크)
                  onTap: _handleWriteButton, 
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
                    stream: FirebaseFirestore.instance
                        .collection('festivals')
                        .where('hostId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("오류 발생: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return const Center(child: Text("등록된 공연이 없습니다.", style: TextStyle(color: Colors.white70)));
                      
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final String title = data['title']?.toString() ?? '제목 없음';
                          final String displayCategory = data['category']?.toString().toUpperCase() ?? 'KPOP';
                          final String subCategory = data['subCategory']?.toString() ?? 'IDOL';
                          final String imageUrl = data['image']?.toString() ?? '';
                          final bool isActive = data['isActive'] ?? true;
                          final bool isValidImage = imageUrl.startsWith('http');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Opacity(
                              opacity: isActive ? 1.0 : 0.5,
                              child: LiquidGlassCard(
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8), 
                                    child: isValidImage
                                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.white))
                                      : const SizedBox(width: 50, height: 50, child: Icon(Icons.image, color: Colors.white54)),
                                  ),
                                  title: Text(
                                    title, 
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.bold,
                                      decoration: isActive ? null : TextDecoration.lineThrough, 
                                    )
                                  ),
                                  subtitle: Text(
                                    "$displayCategory / $subCategory \n${isActive ? '🟢 공개중' : '🔴 비공개'}", 
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    color: LiquidColors.darkCosmicMid,
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditor(context, doc: docs[index]);
                                      } else if (value == 'toggle') {
                                        _toggleActive(docs[index].id, isActive);
                                      } else if (value == 'delete') {
                                        _deleteFestival(docs[index].id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(children: [Icon(Icons.edit, color: Colors.white, size: 20), SizedBox(width: 8), Text('수정', style: TextStyle(color: Colors.white))]),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(children: [
                                          Icon(isActive ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 20), 
                                          const SizedBox(width: 8), 
                                          Text(isActive ? '비공개로 전환' : '공개로 전환', style: const TextStyle(color: Colors.white))
                                        ]),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 8), Text('삭제', style: TextStyle(color: Colors.redAccent))]),
                                      ),
                                    ],
                                  ),
                                ),
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