import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:translator/translator.dart';
import 'package:kfestival/ui/liquid_theme.dart';
import 'package:kfestival/utils/k_localization.dart';
import 'package:kfestival/festival_detail.dart';

class GuestListPage extends StatefulWidget {
  final String category; // 메인에서 선택한 카테고리 (kpop, musical...)
  final String lang;     // 선택된 언어 (en, ko...)

  const GuestListPage({super.key, required this.category, required this.lang});

  @override
  State<GuestListPage> createState() => _GuestListPageState();
}

class _GuestListPageState extends State<GuestListPage> {
  final translator = GoogleTranslator();
  
  // 상태 변수들
  String _selectedSub = 'all'; // 현재 선택된 서브 카테고리
  bool _showLikedOnly = false; // 좋아요 필터
  
  List<Map<String, dynamic>> _items = []; // 불러온 데이터 리스트
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc; // 페이징 커서
  final int _limit = 10;

  // 🔥 [수정] 아트 플랫폼에 맞는 서브 카테고리 매핑 (단어장 키값과 일치)
  Map<String, List<String>> get _subCategories => {
    'kpop': ['all', 'idol', 'hiphop'],
    'musical': ['all', 'theater', 'big_musical'],
    'exhibition': ['all', 'gallery', 'museum'],
    'performance': ['all', 'nanta', 'magic'],
  };

  @override
  void initState() {
    super.initState();
    _loadItems(isRefresh: true);
  }

  // 데이터 불러오기
  Future<void> _loadItems({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (isRefresh) {
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
    }

    if (!_hasMore) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Query query = FirebaseFirestore.instance.collection('festivals');

      // 1. 좋아요 필터
      if (_showLikedOnly) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          query = query.where('likes', arrayContains: uid);
        } else {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
          return;
        }
      } 
      // 2. 카테고리 필터
      else {
        query = query.where('category', isEqualTo: widget.category);
        if (_selectedSub != 'all') {
           query = query.where('subCategory', isEqualTo: _selectedSub);
        }
      }

      // 정렬 (색인 없으면 에러나므로 일단 제거, 색인 생성 후 추가 가능)
      // query = query.orderBy('createdAt', descending: true);
      
      query = query.limit(_limit);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        
        List<Map<String, dynamic>> newItems = [];
        
        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;

          // 번역 로직
          if (widget.lang != 'ko') {
            String title = data['title'] ?? '';
            String desc = data['description'] ?? '';
            if (desc.length > 100) desc = desc.substring(0, 100); 

            try {
              var trans = await Future.wait([
                translator.translate(title, to: widget.lang),
                translator.translate(desc, to: widget.lang),
              ]);
              
              data['displayTitle'] = trans[0].text;
              data['displayDesc'] = trans[1].text;
            } catch (e) {
              data['displayTitle'] = title;
              data['displayDesc'] = desc;
            }
          } else {
            data['displayTitle'] = data['title'];
            data['displayDesc'] = data['description'];
          }
          
          newItems.add(data);
        }

        if (mounted) {
          setState(() {
            _items.addAll(newItems);
          });
        }
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      print("Error loading items: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subCats = _subCategories[widget.category] ?? ['all'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          KLocalization.getCategory(widget.lang, widget.category),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. 상단 필터 영역
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: subCats.map((sub) {
                          final isSelected = _selectedSub == sub;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                KLocalization.getCategory(widget.lang, sub),
                                style: TextStyle(
                                  // 🔥 [수정] 선택되면 검은글씨, 아니면 흰글씨
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              showCheckmark: false,
                              // 🔥 [수정] 선택되면 형광색, 아니면 반투명
                              selectedColor: LiquidColors.cyanAccent,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? Colors.transparent : Colors.white24
                                )
                              ),
                              onSelected: (bool selected) {
                                if (selected) {
                                  setState(() => _selectedSub = sub);
                                  _loadItems(isRefresh: true);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 좋아요 필터
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            KLocalization.get(widget.lang, 'btn_like_only'), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _showLikedOnly,
                            activeColor: LiquidColors.cyanAccent, // 🔥 형광색 포인트
                            onChanged: (val) {
                              setState(() => _showLikedOnly = val);
                              _loadItems(isRefresh: true);
                            },
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              // 2. 리스트 영역
              Expanded(
                child: _items.isEmpty && !_isLoading
                    ? Center(child: Text(KLocalization.get(widget.lang, 'empty_list'), style: const TextStyle(color: Colors.white70)))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (!_isLoading && _hasMore && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                            _loadItems();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: LiquidColors.cyanAccent)));
                            }
                            
                            final data = _items[index];
                            return _buildItemCard(data);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 [수정] 다크 코스믹 스타일 카드
  Widget _buildItemCard(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        height: 140,
        glowColor: LiquidColors.purpleAccent, // 은은한 보라빛 테두리
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FestivalDetailPage(
                data: data,
                festivalId: data['docId'],
                initialLang: widget.lang,
              ),
            ),
          );
        },
        child: Row(
          children: [
            // 이미지 영역
            Container(
              width: 120,
              height: 140,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: Image.network(
                data['image'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Center(
                  child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 30)
                ),
              ),
            ),
            
            // 정보 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카테고리 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: LiquidColors.cyanAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        data['subCategory']?.toString().toUpperCase() ?? 'EVENT',
                        style: const TextStyle(color: LiquidColors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 제목
                    Text(
                      data['displayTitle'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    // 위치
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['location'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 설명 (짧게)
                    Text(
                      data['displayDesc'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}