import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kfestival/festival_detail.dart';

class GuestMapPage extends StatefulWidget {
  final Position? initialPosition;

  const GuestMapPage({super.key, this.initialPosition});

  @override
  State<GuestMapPage> createState() => _GuestMapPageState();
}

class _GuestMapPageState extends State<GuestMapPage> {
  late GoogleMapController mapController;
  late final CameraPosition _kGooglePlex;

  @override
  void initState() {
    super.initState();
    double lat = widget.initialPosition?.latitude ?? 37.5665;
    double lng = widget.initialPosition?.longitude ?? 126.9780;
    
    _kGooglePlex = CameraPosition(
      target: LatLng(lat, lng),
      zoom: 11.0,
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          Set<Marker> markers = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            double lat = (data['latitude'] ?? 0.0).toDouble();
            double lng = (data['longitude'] ?? 0.0).toDouble();
            String title = data['title'] ?? '제목 없음';
            String location = data['location'] ?? '';

            if (lat != 0.0 && lng != 0.0) {
              markers.add(
                Marker(
                  markerId: MarkerId(doc.id),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(
                    title: title,
                    snippet: location,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // 🔥 [수정] festivalId 전달
                          builder: (context) => FestivalDetailPage(data: data, festivalId: doc.id),
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
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}