import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatelessWidget {
  final Position? currentLocation;
  final List<Map<String, dynamic>> todayEntries;
  final Function(Map<String, dynamic>) onLocationTap;

  const MapWidget({
    super.key,
    this.currentLocation,
    required this.todayEntries,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null && todayEntries.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Ажлын цаг, байршил бүртгэгдээгүй байна!',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Build markers from all today's entries
    Set<Marker> markers = {};
    LatLng? centerPosition;

    // Add markers for each time entry with location
    for (int i = 0; i < todayEntries.length; i++) {
      final entry = todayEntries[i];
      final location = entry['location'];
      if (location != null && location['latitude'] != null && location['longitude'] != null) {
        final lat = location['latitude'] as double;
        final lng = location['longitude'] as double;
        final timestamp = (entry['timestamp'] as Timestamp).toDate();
        final type = entry['type'] as String;
        
        markers.add(
          Marker(
            markerId: MarkerId('entry_$i'),
            position: LatLng(lat, lng),
            icon: type == 'check_in' 
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: type == 'check_in' ? 'ИРЛЭЭ' : 'ЯВЛАА',
              snippet: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
            ),
          ),
        );
        
        // Use the latest location as center
        centerPosition = LatLng(lat, lng);
      }
    }

    // If no entries have location, use current location
    if (centerPosition == null && currentLocation != null) {
      centerPosition = LatLng(currentLocation!.latitude, currentLocation!.longitude);
    }

    // Default to Ulaanbaatar if no location data
    centerPosition ??= const LatLng(47.9184, 106.9177);

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (controller) {
            // Map controller assignment removed as it's not used
          },
          initialCameraPosition: CameraPosition(
            target: centerPosition,
            zoom: 16,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }
}
