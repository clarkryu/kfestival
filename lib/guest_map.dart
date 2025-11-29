import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kfestival/festival_detail.dart';
import 'package:kfestival/ui/liquid_theme.dart';

class GuestMapPage extends StatefulWidget {
  const GuestMapPage({super.key});

  @override
  State<GuestMapPage> createState() => _GuestMapPageState();
}

class _GuestMapPageState extends State<GuestMapPage> {
  GoogleMapController? mapController;
  
  // 대학로(혜화) 좌표를 기본값으로 설정 (문화 예술 중심지)
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(37.5806, 127.0033), 
    zoom: 14.0,
  );
  
  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _showSearchButton = false; // "이 지역 검색" 버튼 표시 여부

  @override
  void initState() {
    super.initState();
    // 앱 켜면 내 위치로 이동 시도
    _goToMyLocation();
  }

  // 🔥 [핵심] 현재 보고 있는 지도 화면 안의 데이터만 가져오기
  Future<void> _loadMarkersInViewport() async {
    if (mapController == null) return;
    
    setState(() {
      _isLoading = true;
      _showSearchButton = false; // 검색 시작하면 버튼 숨김
    });

    try {
      // 현재 화면의 동서남북 좌표 범위 가져오기
      final LatLngBounds bounds = await mapController!.getVisibleRegion();
      final double minLat = bounds.southwest.latitude;
      final double maxLat = bounds.northeast.latitude;
      final double minLng = bounds.southwest.longitude;
      final double maxLng = bounds.northeast.longitude;

      // 1. 위도(Lat) 기준으로 DB에서 1차 필터링
      final snapshot = await FirebaseFirestore.instance
          .collection('festivals')
          .where('isActive', isEqualTo: true)
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat)
          .get();
      
      Set<Marker> newMarkers = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double lat = (data['latitude'] ?? 0.0).toDouble();
        final double lng = (data['longitude'] ?? 0.0).toDouble();
        
        // 2. 경도(Lng) 기준으로 앱 내에서 2차 필터링 (Firestore 제약 때문)
        if (lng >= minLng && lng <= maxLng) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: data['title'] ?? '공연 정보',
                snippet: data['location'] ?? '',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FestivalDetailPage(data: data, festivalId: doc.id),
                    ),
                  );
                },
              ),
              // 보라색 마커 사용 (K-Art 테마)
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet), 
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          if (newMarkers.isEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text("이 화면 범위에는 공연 정보가 없습니다."),
                 duration: Duration(seconds: 1),
               )
             );
          }
        });
      }
    } catch (e) {
      print("마커 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 내 위치로 이동
  Future<void> _goToMyLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14),
      );
      
      // 이동 후 자동으로 데이터 로드
      await Future.delayed(const Duration(milliseconds: 500)); 
      if (mounted) _loadMarkersInViewport();

    } catch (e) {
      print("위치 찾기 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Art Map', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kDefaultLocation,
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            // 🔥 지도를 움직이면 "이 지역 검색" 버튼이 나타나게 함
            onCameraMove: (position) {
              if (!_showSearchButton) {
                setState(() => _showSearchButton = true);
              }
            },
          ),

          // 🔥 [NEW] "이 지역 검색" 버튼 (Floating Style)
          if (_showSearchButton)
            Positioned(
              top: 100,
              left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _loadMarkersInViewport,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: LiquidColors.darkCosmicBottom,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))],
                      border: Border.all(color: LiquidColors.cyanAccent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) 
                          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          const Icon(Icons.refresh, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text("이 지역 검색", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 내 위치 버튼
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _goToMyLocation,
              backgroundColor: LiquidColors.darkCosmicBottom,
              child: const Icon(Icons.my_location, color: LiquidColors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }
}