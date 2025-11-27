class KLocalization {
  static const List<String> supportedLanguages = ['ko', 'en', 'zh', 'ja', 'es']; // 스페인어 추가됨

  static const Map<String, Map<String, String>> _localizedValues = {
    'ko': {
      'app_title': 'K-PODO',
      'welcome': '한국의 예술을 만나보세요!',
      
      // 🔥 [수정] 파트너 로그인 버튼
      'btn_partner_login': '파트너 로그인',

      // 🔥 [수정] 새로운 아트 카테고리 (Art Platform)
      'cat_kpop': 'K-Pop & 콘서트',
      'cat_musical': '연극 & 뮤지컬',
      'cat_exhibition': '전시 & 박물관',
      'cat_performance': '퍼포먼스 & 기타',
      
      // 서브 카테고리 (나중에 호스트 등록할 때 쓰임)
      'sub_all': '전체',
      'sub_idol': '아이돌/팬미팅',
      'sub_hiphop': '힙합/페스티벌',
      'sub_theater': '대학로 연극',
      'sub_big_musical': '대형 뮤지컬',
      'sub_gallery': '미술관/갤러리',
      'sub_museum': '박물관/역사',
      'sub_nanta': '난타/넌버벌',
      'sub_magic': '마술/국악',
      
      'btn_like_only': '❤️ 찜한 것만',
      'empty_list': '아직 등록된 공연이 없어요.',
    },
    'en': {
      'app_title': 'K-PODO',
      'welcome': 'Discover Korean Art & Vibe!',
      
      'btn_partner_login': 'Partner Login', // 🔥 영어 번역

      // Art Categories
      'cat_kpop': 'K-Pop & Concert',
      'cat_musical': 'Theater & Musical',
      'cat_exhibition': 'Exhibition & Museum',
      'cat_performance': 'Performance & Etc',

      'sub_all': 'All',
      'sub_idol': 'Idol/Fan Meet',
      'sub_hiphop': 'Hiphop/Festival',
      'sub_theater': 'Theater (Daehak-ro)',
      'sub_big_musical': 'Grand Musical',
      'sub_gallery': 'Gallery/Art',
      'sub_museum': 'Museum/History',
      'sub_nanta': 'Non-verbal',
      'sub_magic': 'Magic/Traditional',

      'btn_like_only': '❤️ Liked Only',
      'empty_list': 'No events found yet.',
    },
    // (중국어, 일본어, 스페인어는 영어로 대체되거나 추후 추가)
  };

  static String get(String lang, String key) {
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  static String getCategory(String lang, String code) {
    if (_localizedValues[lang]?.containsKey('cat_$code') ?? false) {
      return get(lang, 'cat_$code');
    }
    if (_localizedValues[lang]?.containsKey('sub_$code') ?? false) {
      return get(lang, 'sub_$code');
    }
    return code; 
  }
}