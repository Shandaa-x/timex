import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> timeEntries;
  final String date;

  const LocationMapScreen({
    super.key,
    required this.timeEntries,
    required this.date,
  });

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _showPolylines = true;

  @override
  void initState() {
    super.initState();
    _createMarkersAndPolylines();
  }

  void _createMarkersAndPolylines() {
    final markers = <Marker>{};
    final List<LatLng> polylineCoordinates = [];

    for (int i = 0; i < widget.timeEntries.length; i++) {
      final entry = widget.timeEntries[i];
      final location = entry['location'] as Map<String, dynamic>?;
      
      if (location != null) {
        final timestamp = (entry['timestamp'] as Timestamp).toDate();
        final isCheckIn = entry['type'] == 'check_in';
        final latLng = LatLng(location['latitude'], location['longitude']);
        
        polylineCoordinates.add(latLng);
        
        markers.add(
          Marker(
            markerId: MarkerId('entry_$i'),
            position: latLng,
            infoWindow: InfoWindow(
              title: '${i + 1}. ${isCheckIn ? 'Ирсэн' : 'Явсан'}',
              snippet: '${_formatTime(timestamp)} - Нарийвчлал: ${location['accuracy'].toStringAsFixed(1)}м',
            ),
            icon: isCheckIn 
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }
    }

    // Create polyline connecting all points
    if (polylineCoordinates.length > 1) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('movement_path'),
          points: polylineCoordinates,
          color: Colors.blue,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    }

    setState(() {
      _markers = markers;
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        return '$year/$month/$day';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
  }

  void _zoomToFitMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateBounds() {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng _getCenterPoint() {
    if (_markers.isEmpty) return const LatLng(47.9184, 106.9177); // Default to Ulaanbaatar

    double totalLat = 0;
    double totalLng = 0;
    
    for (final marker in _markers) {
      totalLat += marker.position.latitude;
      totalLng += marker.position.longitude;
    }
    
    return LatLng(totalLat / _markers.length, totalLng / _markers.length);
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тэмдэглэгээ:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Ирсэн', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Явсан', style: TextStyle(fontSize: 12)),
            ],
          ),
          if (_polylines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 2,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text('Хөдөлгөөний зам', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_formatDate(widget.date)} - Байршлын зураг'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _zoomToFitMarkers,
              tooltip: 'Бүх цэгийг харуулах',
            ),
          if (_polylines.isNotEmpty)
            IconButton(
              icon: Icon(_showPolylines ? Icons.timeline : Icons.timeline_outlined),
              onPressed: () {
                setState(() {
                  _showPolylines = !_showPolylines;
                });
              },
              tooltip: _showPolylines ? 'Замыг нуух' : 'Замыг харуулах',
            ),
        ],
      ),
      body: _markers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'GPS байршил олдсонгүй',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Энэ өдөр байршлын мэдээлэл\nбүртгэгдээгүй байна',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Auto-fit to markers after map is created
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _zoomToFitMarkers();
                    });
                  },
                  initialCameraPosition: CameraPosition(
                    target: _getCenterPoint(),
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _showPolylines ? _polylines : {},
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildLegend(),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            Text(
                              'Нийт ${widget.timeEntries.length} удаа орсон гарсан',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (widget.timeEntries.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Эхний орсон: ${_formatTime((widget.timeEntries.first['timestamp'] as Timestamp).toDate())}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                          Text(
                            'Сүүлд гарсан: ${_formatTime((widget.timeEntries.last['timestamp'] as Timestamp).toDate())}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
