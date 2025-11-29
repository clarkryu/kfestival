import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // 위치 계산 추가
import 'package:translator/translator.dart';
import 'package:kfestival/ui/liquid_theme.dart';
import 'package:kfestival/utils/k_localization.dart';
import 'package:kfestival/festival_detail.dart';

class GuestListPage extends StatefulWidget {
  final String category; // 'kpop', 'musical' ...
  final String lang;     // 'en', 'ko' ...

  const GuestListPage({super.key, required this.category, required this.lang});

  @override
  State<GuestListPage> createState() => _GuestListPageState();
}

class _GuestListPageState extends State<GuestListPage> {
  final translator = GoogleTranslator();
  
  // 상태 변수
  String _selectedSub = 'all';
  bool _showLikedOnly = false;
  
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final int _limit = 10;

  Position? _myPosition; // 내 위치 저장용

  // 카테고리 매핑 (단어장 키값과 일치)
  Map<String, List<String>> get _subCategories => {
    'kpop': ['all', 'idol', 'hiphop'],
    'musical': ['all', 'theater', 'big_musical'],
    'exhibition': ['all', 'gallery', 'museum'],
    'performance': ['all', 'nanta', 'magic'],
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // 위치 먼저 파악
    _loadItems(isRefresh: true);
  }

  // 🌍 내 위치 가져오기 (거리 계산용)
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _myPosition = position);
      }
    } catch (e) {
      print("위치 오류: $e");
    }
  }

  // 📏 거리 계산 함수
  String _getDistance(Map<String, dynamic> data) {
    if (_myPosition == null || data['latitude'] == null || data['longitude'] == null) return '';
    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();
    if (lat == 0.0 && lng == 0.0) return '';
    
    double dist = Geolocator.distanceBetween(_myPosition!.latitude, _myPosition!.longitude, lat, lng);
    return '${(dist / 1000).toStringAsFixed(1)}km';
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

      // 1. 활성화된 공연만 보기 (기본)
      query = query.where('isActive', isEqualTo: true);

      // 2. 좋아요 필터
      if (_showLikedOnly) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          query = query.where('likes', arrayContains: uid);
        } else {
          setState(() { _isLoading = false; _hasMore = false; });
          return;
        }
      } 
      // 3. 카테고리 필터 (좋아요 필터가 아닐 때만 적용)
      else {
        query = query.where('category', isEqualTo: widget.category);
        if (_selectedSub != 'all') {
           query = query.where('subCategory', isEqualTo: _selectedSub);
        }
      }

      // 정렬 (복합 색인이 필요할 수 있음. 에러 발생 시 콘솔 링크 클릭하여 색인 생성 필요)
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
            String location = data['location'] ?? '';
            
            try {
              var trans = await Future.wait([
                translator.translate(title, to: widget.lang),
                translator.translate(location, to: widget.lang),
              ]);
              data['displayTitle'] = trans[0].text;
              data['displayLocation'] = trans[1].text;
            } catch (e) {
              data['displayTitle'] = title;
              data['displayLocation'] = location;
            }
          } else {
            data['displayTitle'] = data['title'];
            data['displayLocation'] = data['location'];
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
        actions: [
          // 🔥 [추가] 통합 검색 버튼
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context, 
                delegate: FestivalSearchDelegate(lang: widget.lang, myPosition: _myPosition)
              );
            },
          )
        ],
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
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: LiquidColors.cyanAccent,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? Colors.transparent : Colors.white24)
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
                            activeThumbColor: LiquidColors.cyanAccent,
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
                          if (!_isLoading && _hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
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

  Widget _buildItemCard(Map<String, dynamic> data) {
    String distance = _getDistance(data);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        height: 140,
        glowColor: LiquidColors.purpleAccent,
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
                    // 카테고리 뱃지 & 거리
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LiquidColors.cyanAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4)
                          ),
                          child: Text(
                            KLocalization.getCategory(widget.lang, data['subCategory'] ?? 'event'),
                            style: const TextStyle(color: LiquidColors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (distance.isNotEmpty)
                          Text(distance, style: const TextStyle(color: LiquidColors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 제목
                    Text(
                      data['displayTitle'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // 위치
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['displayLocation'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
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

// 🔥 [통합] 검색 델리게이트 (기존 guest_home.dart 내용을 이식 및 개선)
class FestivalSearchDelegate extends SearchDelegate {
  final String lang;
  final Position? myPosition;

  FestivalSearchDelegate({required this.lang, this.myPosition});

  @override
  ThemeData appBarTheme(BuildContext context) {
    // 검색바 테마 커스텀 (다크 테마 적용)
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: LiquidColors.darkCosmicTop,
      appBarTheme: const AppBarTheme(backgroundColor: LiquidColors.darkCosmicTop),
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildSearchList();
  @override
  Widget buildSuggestions(BuildContext context) => Container(); // 추천검색어 생략

  Widget _buildSearchList() {
    if (query.isEmpty) return Center(child: Text(lang == 'ko' ? "검색어를 입력하세요" : "Please enter a keyword"));

    // 💡 참고: Firestore 무료 버전은 '문자열 포함 검색(Like)'이 안됨. 
    // 여기서는 '접두어 검색(startAt)'만 가능하므로 정확한 제목 앞글자를 입력해야 함.
    // 실제 서비스에선 Algolia 등을 쓰거나, 클라이언트에서 필터링해야 함.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('festivals')
          .orderBy('title')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: LiquidColors.cyanAccent));
        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) return Center(child: Text(lang == 'ko' ? "결과가 없습니다." : "No results found."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: data['image'] != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(data['image'], width: 40, height: 40, fit: BoxFit.cover)) 
                  : null,
              title: Text(data['title'] ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Text(data['location'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => FestivalDetailPage(
                  data: data, 
                  festivalId: docs[index].id,
                  initialLang: lang,
                )));
              },
            );
          },
        );
      },
    );
  }
}