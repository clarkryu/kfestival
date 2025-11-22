import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

class FestivalDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArtistMode; // 🔥 [추가] 아티스트 모드인지 확인하는 스위치 (기본값 false)

  const FestivalDetailPage({
    super.key, 
    required this.data,
    this.isArtistMode = false, // 기본적으로는 안 보여줌 (게스트용)
  });

  @override
  State<FestivalDetailPage> createState() => _FestivalDetailPageState();
}

class _FestivalDetailPageState extends State<FestivalDetailPage> {
  final translator = GoogleTranslator();
  
  String _currentLang = 'ko';
  String? _translatedTitle;
  String? _translatedDescription;
  String? _translatedRecruitDetail;
  bool _isTranslating = false;

  final Map<String, String> _languages = {
    '원본 (Original)': 'ko',
    'English': 'en',
    '日本語 (Japanese)': 'ja',
    '中文 (Chinese)': 'zh-cn',
    'Español (Spanish)': 'es',
  };

  Future<void> _changeLanguage(String langCode) async {
    if (_currentLang == langCode) return;

    if (langCode == 'ko') {
      setState(() {
        _currentLang = 'ko';
        _translatedTitle = null;
        _translatedDescription = null;
        _translatedRecruitDetail = null;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final String title = widget.data['title'] ?? '';
      final String desc = widget.data['description'] != null && widget.data['description'].toString().isNotEmpty
          ? widget.data['description']
          : "이 축제는 ${widget.data['location']}에서 열리는 ${widget.data['genre']} 장르의 멋진 축제입니다. 상세 내용이 곧 업데이트 될 예정입니다.";
      final String recruit = widget.data['recruitDetail'] != null && widget.data['recruitDetail'].toString().isNotEmpty
          ? widget.data['recruitDetail']
          : "별도의 모집 상세 내용이 없습니다.";

      var results = await Future.wait([
        translator.translate(title, to: langCode),
        translator.translate(desc, to: langCode),
        translator.translate(recruit, to: langCode),
      ]);

      if (mounted) {
        setState(() {
          _currentLang = langCode;
          _translatedTitle = results[0].text;
          _translatedDescription = results[1].text;
          _translatedRecruitDetail = results[2].text;
          _isTranslating = false;
        });
      }
    } catch (e) {
      print("번역 실패: $e");
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("번역 서비스를 사용할 수 없습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayTitle = _translatedTitle ?? widget.data['title'] ?? '제목 없음';
    final String originalDesc = widget.data['description'] != null && widget.data['description'].toString().isNotEmpty
          ? widget.data['description']
          : "이 축제는 ${widget.data['location']}에서 열리는 ${widget.data['genre']} 장르의 멋진 축제입니다. 상세 내용이 곧 업데이트 될 예정입니다.";
    final String displayDesc = _translatedDescription ?? originalDesc;

    // 모집 요강 데이터
    final bool isRecruiting = widget.data['isRecruiting'] ?? false;
    final String originalRecruit = widget.data['recruitDetail'] ?? "상세 내용 없음";
    final String displayRecruit = _translatedRecruitDetail ?? originalRecruit;
    final List<dynamic> targetGenres = widget.data['targetGenres'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: _isTranslating 
                  ? const SizedBox()
                  : Text(
                      displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.data['image'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.language, color: Colors.white),
                onSelected: _changeLanguage,
                itemBuilder: (BuildContext context) {
                  return _languages.entries.map((entry) {
                    return PopupMenuItem<String>(
                      value: entry.value,
                      child: Row(
                        children: [
                          if (_currentLang == entry.value)
                            const Icon(Icons.check, size: 16, color: Colors.deepPurple)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
              const SizedBox(width: 10),
            ],
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isTranslating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.data['genre'] ?? '기타',
                          style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(widget.data['date'] ?? '날짜 미정'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(child: Text(widget.data['location'] ?? '위치 정보 없음')),
                        ],
                      ),
                      
                      const Divider(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("축제 소개", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            _currentLang == 'ko' ? "한국어" : _currentLang.toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(displayDesc, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),

                      // 🔥 [핵심 수정] 모집 중이고 + 아티스트 모드일 때만 보임!
                      if (isRecruiting && widget.isArtistMode) ...[
                        const Divider(height: 40),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.campaign, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    "아티스트 모집 요강",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (targetGenres.isNotEmpty) ...[
                                const Text("모집 장르:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  children: targetGenres.map((g) => Chip(
                                    label: Text(g.toString(), style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  )).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const Text("세부 내용:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(displayRecruit, style: const TextStyle(fontSize: 15, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ],
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}