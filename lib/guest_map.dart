import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kfestival/festival_detail.dart'; // 상세 페이지 이동용

class GuestMapPage extends StatefulWidget {
  final Position? initialPosition; // 내 위치를 받아서 지도의 중심으로 삼음

  const GuestMapPage({super.key, this.initialPosition});

  @override
  State<GuestMapPage> createState() => _GuestMapPageState();
}

class _GuestMapPageState extends State<GuestMapPage> {
  late GoogleMapController mapController;
  
  // 초기 카메라 위치 (내 위치가 없으면 서울 시청 기준)
  late final CameraPosition _kGooglePlex;

  @override
  void initState() {
    super.initState();
    // 내 위치가 있으면 거기로, 없으면 서울 시청
    double lat = widget.initialPosition?.latitude ?? 37.5665;
    double lng = widget.initialPosition?.longitude ?? 126.9780;
    
    _kGooglePlex = CameraPosition(
      target: LatLng(lat, lng),
      zoom: 11.0, // 적당한 줌 레벨
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('축제 지도'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('festivals').snapshots(),
        builder: (context, snapshot) {
          // 데이터 로딩 중일 때
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // 마커(핀) 만들기
          Set<Marker> markers = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            double lat = (data['latitude'] ?? 0.0).toDouble();
            double lng = (data['longitude'] ?? 0.0).toDouble();
            String title = data['title'] ?? '제목 없음';
            String location = data['location'] ?? '';

            // 좌표가 있는 축제만 마커 생성
            if (lat != 0.0 && lng != 0.0) {
              markers.add(
                Marker(
                  markerId: MarkerId(doc.id),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(
                    title: title,
                    snippet: location, // 주소 표시
                    onTap: () {
                      // 핀의 말풍선을 누르면 상세 페이지로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FestivalDetailPage(data: data),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          }

          return GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
            },
            markers: markers, // 만든 마커들 지도에 뿌리기
            myLocationEnabled: true, // 내 위치 파란 점 표시
            myLocationButtonEnabled: true, // 내 위치로 가는 버튼 표시
          );
        },
      ),
    );
  }
}