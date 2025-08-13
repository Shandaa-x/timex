import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationMapDialog extends StatelessWidget {
  final Map<String, dynamic> location;

  const LocationMapDialog({
    super.key,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Байршил'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(location['latitude'], location['longitude']),
            zoom: 17,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('location'),
              position: LatLng(location['latitude'], location['longitude']),
              infoWindow: InfoWindow(
                title: 'Ажлын байршил',
                snippet: 'Нарийвчлал: ${location['accuracy'].toStringAsFixed(1)}м',
              ),
            ),
          },
          mapType: MapType.normal,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Хаах'),
        ),
      ],
    );
  }
}
