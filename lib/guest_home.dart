import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:translator/translator.dart'; // 🔥 번역 패키지 추가
import 'package:kfestival/login.dart';
import 'package:kfestival/festival_detail.dart';
import 'package:kfestival/guest_saved.dart';
import 'package:kfestival/ui/liquid_theme.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  final translator = GoogleTranslator(); // 🔥 번역기 인스턴스

  // 상태 변수들
  String _selectedLanguage = 'ko'; // 현재 언어
  Position? _myPosition;
  String _selectedGenre = '전체';
  
  // 데이터 리스트 & 페이징 관련
  List<Map<String, dynamic>> _displayList = []; // 화면에 보여줄 축제 리스트
  DocumentSnapshot? _lastDocument; // 다음 페이지를 위한 커서
  bool _isLoading = false; // 로딩 중인지 여부
  bool _hasMore = true; // 더 불러올 데이터가 있는지
  final int _limit = 10; // ⚡ 한 번에 불러올 개수 (10개)

  // 🔥 장르 목록 (번역을 위해 단순 문자열 리스트 대신 매핑 사용 권장하지만, 여기선 로직 내에서 처리)
  final List<String> _genres = ['전체', '락/밴드', '재즈/클래식', '힙합/EDM', '발라드/R&B', '기타'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadFestivals(isRefresh: true); // 앱 켜지면 첫 데이터 로드
  }

  // 🌍 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
        if (mounted) setState(() => _myPosition = position);
      }
    } catch (e) { print(e); }
  }

  // 📏 거리 계산
  String _getDistance(Map<String, dynamic> data) {
    if (_myPosition == null || data['latitude'] == null || data['longitude'] == null) return '- km';
    double lat = (data['latitude'] as num).toDouble();
    double lng = (data['longitude'] as num).toDouble();
    if (lat == 0.0 && lng == 0.0) return '';
    double dist = Geolocator.distanceBetween(_myPosition!.latitude, _myPosition!.longitude, lat, lng);
    return '${(dist / 1000).toStringAsFixed(1)}km';
  }

  // 🔥 [핵심] 데이터 로드 및 번역 함수
  Future<void> _loadFestivals({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (isRefresh) {
      _displayList.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    Query query = FirebaseFirestore.instance.collection('festivals').orderBy('createdAt', descending: true);
    if (_selectedGenre != '전체') {
      query = query.where('genre', isEqualTo: _selectedGenre);
    }

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    query = query.limit(_limit); // 10개만 가져오기

    try {
      QuerySnapshot snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        // 가져온 데이터 처리 (번역 포함)
        List<Map<String, dynamic>> newItems = [];
        
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String docId = doc.id;
          
          // 🔥 [번역 로직] 한국어가 아니면 번역 실행
          if (_selectedLanguage != 'ko') {
            String title = data['title'] ?? '';
            String location = data['location'] ?? '';
            String genre = data['genre'] ?? '';

            // 병렬 번역 실행 (속도 향상)
            var translations = await Future.wait([
               translator.translate(title, to: _selectedLanguage),
               translator.translate(location, to: _selectedLanguage),
               // 장르는 간단하므로 매핑 함수를 쓸 수도 있지만, 여기선 구글 번역기 돌림
               translator.translate(genre, to: _selectedLanguage),
            ]);

            data['displayTitle'] = translations[0].text;
            data['displayLocation'] = translations[1].text;
            data['displayGenre'] = translations[2].text;
          } else {
            // 한국어면 그대로 사용
            data['displayTitle'] = data['title'];
            data['displayLocation'] = data['location'];
            data['displayGenre'] = data['genre'];
          }
          
          data['docId'] = docId; // ID 저장
          newItems.add(data);
        }

        if (mounted) {
          setState(() {
            _displayList.addAll(newItems);
          });
        }
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      print("데이터 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗣️ UI 텍스트 번역 사전
  String get _txtPartner => _selectedLanguage == 'ko' ? 'Partner' : 'Partner'; // 파트너는 영어 그대로가 나을듯
  String get _txtSearch => _selectedLanguage == 'ko' ? '축제 검색' : 'Search';
  String get _txtEmpty => _selectedLanguage == 'ko' ? '등록된 축제가 없습니다.' : 'No festivals found.';
  String get _txtLoadMore => _selectedLanguage == 'ko' ? '더 보기' : 'Load More';
  String get _txtNoMore => _selectedLanguage == 'ko' ? '마지막 축제입니다.' : 'No more festivals.';

  // 장르 탭 번역 처리
  String _translateGenreLabel(String genre) {
    if (_selectedLanguage == 'ko') return genre;
    // 간단 매핑
    switch (genre) {
      case '전체': return 'All';
      case '락/밴드': return 'Rock/Band';
      case '재즈/클래식': return 'Jazz/Classic';
      case '힙합/EDM': return 'Hip-hop/EDM';
      case '발라드/R&B': return 'Ballad/R&B';
      case '기타': return 'Others';
      default: return genre;
    }
  }

  // 🌐 언어 변경 팝업
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_selectedLanguage == 'ko' ? '언어 선택' : 'Select Language'),
        children: [
          _buildLangOption('한국어', 'ko'),
          _buildLangOption('English', 'en'),
          // 필요하면 일본어 등 추가
        ],
      ),
    );
  }

  Widget _buildLangOption(String label, String code) {
    return SimpleDialogOption(
      onPressed: () {
        if (_selectedLanguage != code) {
          setState(() => _selectedLanguage = code);
          _loadFestivals(isRefresh: true); // 🔥 언어 바뀌면 새로고침!
        }
        Navigator.pop(context);
      },
      child: Row(
        children: [
          Icon(_selectedLanguage == code ? Icons.radio_button_checked : Icons.radio_button_off, 
               color: _selectedLanguage == code ? Colors.blue : Colors.grey),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('K-Festival', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 1. 지구본 (언어 변경)
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: _showLanguageDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white), 
            onPressed: () => showSearch(context: context, delegate: FestivalSearchDelegate(myPosition: _myPosition)),
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GuestSavedPage(myPosition: _myPosition))),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage())),
            child: Text(
              _txtPartner, 
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.w600, 
                decoration: TextDecoration.underline, 
                decorationColor: Colors.white70,
              )
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 🎵 장르 선택 탭
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Row(
                  children: _genres.map((genre) {
                    final isSelected = _selectedGenre == genre;
                    // 화면에 보여줄 장르 이름 (번역 적용)
                    final displayGenreLabel = _translateGenreLabel(genre);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedGenre = genre);
                        _loadFestivals(isRefresh: true); // 🔥 장르 바뀌면 새로고침
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: isSelected 
                            ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]
                            : [],
                        ),
                        child: Text(
                          displayGenreLabel,
                          style: TextStyle(
                            color: isSelected ? LiquidColors.darkCosmicBottom : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 📜 축제 리스트 (StreamBuilder 대신 ListView 사용)
              Expanded(
                child: _displayList.isEmpty && !_isLoading
                    ? Center(child: Text(_txtEmpty, style: const TextStyle(color: Colors.white)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        // 아이템 개수 + 1 (마지막에 로딩 표시 또는 더보기 버튼)
                        itemCount: _displayList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _displayList.length) {
                            // 👇 마지막 아이템: 더 보기 버튼 or 로딩 중
                            return _buildLoadMoreButton();
                          }

                          final data = _displayList[index];
                          return _buildGlassCard(context, data);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ➕ 더 보기 버튼 위젯
  Widget _buildLoadMoreButton() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(child: Text(_txtNoMore, style: const TextStyle(color: Colors.white70))),
      );
    }
    return TextButton(
      onPressed: () => _loadFestivals(),
      child: Text(_txtLoadMore, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGlassCard(BuildContext context, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        onTap: () {
          // 상세 페이지로 이동
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => FestivalDetailPage(
                data: data, 
                festivalId: data['docId'],
                // 🔥 [추가] 현재 선택된 언어(_selectedLanguage)를 같이 보냅니다!
                initialLang: _selectedLanguage, 
              )
            )
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              data['image'] ?? '',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(height: 180, color: Colors.white24, child: const Icon(Icons.broken_image, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        // 🔥 번역된 장르 표시
                        child: Text(data['displayGenre'] ?? 'Etc', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                      Text(_getDistance(data), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 🔥 번역된 제목 표시
                  Text(data['displayTitle'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  // 🔥 번역된 장소 표시
                  Text(data['displayLocation'] ?? '', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 검색 기능 (참고: 검색 결과는 여기서 따로 처리 안 했으므로 한국어로 나올 수 있음)
class FestivalSearchDelegate extends SearchDelegate {
  final Position? myPosition;
  FestivalSearchDelegate({this.myPosition});
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text("축제 이름을 입력하세요."));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('festivals').orderBy('title').startAt([query]).endAt(['$query\uf8ff']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['title'] ?? ''),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FestivalDetailPage(data: data, festivalId: docs[index].id))),
            );
          },
        );
      },
    );
  }
}