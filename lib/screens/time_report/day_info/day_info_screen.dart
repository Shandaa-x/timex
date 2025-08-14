import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

class DayInfoScreen extends StatefulWidget {
  final String dateString;
  final Map<String, dynamic> dayData;
  final bool? hasFoodEaten;

  const DayInfoScreen({
    super.key,
    required this.dateString,
    required this.dayData,
    this.hasFoodEaten,
  });

  @override
  State<DayInfoScreen> createState() => _DayInfoScreenState();
}

class _DayInfoScreenState extends State<DayInfoScreen> {
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _timeEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeEntries();
  }

  String formatMongolianHours(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) return '$h цаг, $m минут';
    if (h > 0) return '$h цаг';
    return '$h цаг, $m минут';
  }

  Future<void> _loadTimeEntries() async {
    try {
      final entriesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('calendarDays')
          .doc(widget.dateString)
          .collection('timeEntries')
          .get();

      _timeEntries = entriesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by timestamp on client side to avoid index requirement
      _timeEntries.sort((a, b) {
        final timestampA = (a['timestamp'] as Timestamp).toDate();
        final timestampB = (b['timestamp'] as Timestamp).toDate();
        return timestampA.compareTo(timestampB);
      });
    } catch (e) {
      debugPrint('Error loading time entries: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
      debugPrint('Error formatting date: $e');
    }
    return dateString;
  }

  int _getCheckInCount() {
    return _timeEntries.where((entry) => entry['type'] == 'check_in').length;
  }

  int _getCheckOutCount() {
    return _timeEntries.where((entry) => entry['type'] == 'check_out').length;
  }

  double _getTotalWorkedHours() {
    double totalHours = 0.0;
    DateTime? sessionStart;

    for (final entry in _timeEntries) {
      final timestamp = (entry['timestamp'] as Timestamp).toDate();

      if (entry['type'] == 'check_in') {
        sessionStart = timestamp;
      } else if (entry['type'] == 'check_out' && sessionStart != null) {
        totalHours += timestamp.difference(sessionStart).inMinutes / 60.0;
        sessionStart = null;
      }
    }

    return totalHours;
  }

  List<String> _getAttachmentImages() {
    try {
      final attachmentImagesData = widget.dayData['attachmentImages'];
      if (attachmentImagesData is List) {
        return attachmentImagesData.cast<String>();
      }
    } catch (e) {
      debugPrint('Error getting attachment images: $e');
    }
    return [];
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeEntriesList() {
    if (_timeEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.access_time, size: 48, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text(
                'Энэ өдөр ямар ч орсон гарсан байхгүй',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                const Text(
                  'Орсон гарсан бүртгэл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timeEntries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = _timeEntries[index];
              final timestamp = (entry['timestamp'] as Timestamp).toDate();
              final isCheckIn = entry['type'] == 'check_in';
              final location = entry['location'] as Map<String, dynamic>?;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCheckIn
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isCheckIn ? Icons.login : Icons.logout,
                        color: isCheckIn
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCheckIn ? 'Ирлээ' : 'Явлаа',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            _formatTime(timestamp),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (location != null)
                            Text(
                              'GPS: ${location['latitude'].toStringAsFixed(4)}, ${location['longitude'].toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    final attachmentImages = _getAttachmentImages();

    if (attachmentImages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 12),
              Text(
                'Зураг байхгүй',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                Text(
                  'Зургууд (${attachmentImages.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: attachmentImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () =>
                      _showFullScreenImage(attachmentImages[index], index),
                  child: Hero(
                    tag: 'image_$index',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(attachmentImages[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.error, size: 40),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageData, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Зураг ${index + 1}'),
          ),
          body: Center(
            child: Hero(
              tag: 'image_$index',
              child: InteractiveViewer(
                child: Image.memory(
                  base64Decode(imageData),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 100,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    // Filter entries that have location data
    final entriesWithLocation = _timeEntries.where((entry) {
      final location = entry['location'] as Map<String, dynamic>?;
      return location != null &&
          location['latitude'] != null &&
          location['longitude'] != null;
    }).toList();

    if (entriesWithLocation.isEmpty) {
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
                'Энэ өдөр GPS байршил олдсонгүй',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Build markers from all entries with location
    Set<Marker> markers = {};
    LatLng? centerPosition;

    for (int i = 0; i < entriesWithLocation.length; i++) {
      final entry = entriesWithLocation[i];
      final location = entry['location'] as Map<String, dynamic>;
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
            snippet:
                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
          ),
        ),
      );

      // Use the first location as center
      centerPosition ??= LatLng(lat, lng);
    }

    // Default to Ulaanbaatar if no location data
    centerPosition ??= const LatLng(47.9184, 106.9177);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                Text(
                  'Байршил (${entriesWithLocation.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: (controller) {
                  // Map controller setup if needed
                },
                initialCameraPosition: CameraPosition(
                  target: centerPosition,
                  zoom: 16,
                ),
                markers: markers,
                myLocationEnabled: false,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = widget.dayData['confirmed'] ?? false;
    final hasFoodEaten = widget.hasFoodEaten ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_formatDate(widget.dateString)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Food eaten badge - only show if confirmed and food was eaten
          if (isConfirmed && hasFoodEaten)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Хоол идсэн',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Confirmation status badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isConfirmed ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isConfirmed ? 'Батлагдсан' : 'Хүлээгдэж буй',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Ирсэн',
                          '${_getCheckInCount()}',
                          Icons.login,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Явсан',
                          '${_getCheckOutCount()}',
                          Icons.logout,
                          const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildStatCard(
                    'Ажилласан цаг',
                    '${formatMongolianHours(_getTotalWorkedHours())}',
                    Icons.access_time,
                    const Color(0xFF3B82F6),
                  ),

                  const SizedBox(height: 24),

                  // Map Widget showing all check-in/out locations
                  _buildMapWidget(),

                  const SizedBox(height: 24),

                  // Time Entries List
                  _buildTimeEntriesList(),

                  const SizedBox(height: 24),

                  // Images Section
                  _buildImagesSection(),
                ],
              ),
            ),
    );
  }
}
