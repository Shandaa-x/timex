// lib/organization/home/location/organization_location_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrganizationLocationScreen extends StatefulWidget {
  const OrganizationLocationScreen({super.key});

  @override
  State<OrganizationLocationScreen> createState() => _OrganizationLocationScreenState();
}

class _OrganizationLocationScreenState extends State<OrganizationLocationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  // Form controllers
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  LatLng? _selectedLocation;
  double _currentRadius = 50.0;
  List<String> _selectedEmployeeIds = [];
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Main map markers and circles for displaying all locations
  Set<Marker> _mainMapMarkers = {};
  Set<Circle> _mainMapCircles = {};
  GoogleMapController? _mainMapController;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchLocations(), _fetchEmployees()]);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchLocations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('organizations')
          .doc(user.uid)
          .collection('workLocations')
          .get();

      _locations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _updateMainMapMarkers();
    } catch (e) {
      debugPrint("Error fetching locations: $e");
    }
  }

  Future<void> _fetchEmployees() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('organizations')
          .doc(user.uid)
          .collection('employees')
          .get();

      _employees = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching employees: $e");
    }
  }

  void _showAddLocationBottomSheet() {
    // Reset form
    _locationNameController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _radiusController.text = '50';
    _selectedLocation = null;
    _currentRadius = 50.0;
    _selectedEmployeeIds.clear();
    _markers.clear();
    _circles.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Байршил нэмэх',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Name
                      _buildInputField(
                        label: 'Байршлын нэр',
                        controller: _locationNameController,
                        hint: 'Байршлын дурын нэр өгнө үү.',
                      ),
                      const SizedBox(height: 16),

                      // Map
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AbsorbPointer(
                            absorbing: false,
                            child: GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(47.918, 106.917),
                                zoom: 12,
                              ),
                              onMapCreated: (controller) {},
                              onTap: (LatLng location) {
                                setModalState(() {
                                  _selectedLocation = location;
                                  _latitudeController.text = location.latitude.toStringAsFixed(6);
                                  _longitudeController.text = location.longitude.toStringAsFixed(6);
                                  _updateMapMarkers();
                                });
                              },
                              markers: _markers,
                              circles: _circles,
                              mapType: MapType.hybrid,
                              zoomGesturesEnabled: true,
                              scrollGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: true,
                              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Coordinates
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Өргөрөг',
                              controller: _latitudeController,
                              hint: '47.898268761584...',
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputField(
                              label: 'Уртраг',
                              controller: _longitudeController,
                              hint: '106.91284261636...',
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Radius Slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Радиус (м):',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  '${_currentRadius.toInt()}м',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blue.shade600,
                              inactiveTrackColor: Colors.grey.shade300,
                              thumbColor: Colors.blue.shade600,
                              overlayColor: Colors.blue.shade100,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _currentRadius,
                              min: 10,
                              max: 500,
                              divisions: 99,
                              // (1000-10)/10 = 99 steps of 10m each
                              onChanged: (value) {
                                setModalState(() {
                                  _currentRadius = value;
                                  _radiusController.text = value.toInt().toString();
                                  _updateMapMarkers();
                                });
                              },
                            ),
                          ),
                          // Helper text showing range
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '10м',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text(
                                  '500м',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Employee Selection
                      const Text(
                        'Байршилд ажиллах ажилтнууд',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _employees.map((employee) {
                            final isSelected = _selectedEmployeeIds.contains(employee['id']);
                            return CheckboxListTile(
                              title: Text(
                                employee['fullName'] ??
                                    '${employee['lastName'] ?? ''} ${employee['firstName'] ?? ''}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                              subtitle: Text(
                                employee['jobTitle'] ?? 'N/A',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    _selectedEmployeeIds.add(employee['id']);
                                  } else {
                                    _selectedEmployeeIds.remove(employee['id']);
                                  }
                                });
                              },
                              activeColor: Colors.blue.shade600,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _saveLocation(setModalState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'Нэмэх',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateMapMarkers() {
    if (_selectedLocation == null) return;

    _markers = {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    _circles = {
      Circle(
        circleId: const CircleId('radius'),
        center: _selectedLocation!,
        radius: _currentRadius,
        fillColor: Colors.red.withOpacity(0.2),
        strokeColor: Colors.red,
        strokeWidth: 2,
      ),
    };
  }

  Future<void> _saveLocation(StateSetter setModalState) async {
    if (_locationNameController.text.isEmpty ||
        _selectedLocation == null ||
        _selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүх талбарыг бөглөнө үү!'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final locationData = {
        'name': _locationNameController.text,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'radius': _currentRadius,
        'employeeIds': _selectedEmployeeIds,
        'createdAt': Timestamp.now(),
        'createdBy': user.uid,
      };
      print('rthrthrhrth');
      await _firestore
          .collection('organizations')
          .doc(user.uid)
          .collection('workLocations')
          .add(locationData);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Байршил амжилттай нэмэгдлээ!'),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchLocations();
      setState(() {}); // Refresh the UI
    } catch (e) {
      debugPrint("Error saving location: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Алдаа гарлаа: $e'), backgroundColor: Colors.red));
    }
  }

  void _updateMainMapMarkers() {
    _mainMapMarkers.clear();
    _mainMapCircles.clear();

    for (int i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      final lat = location['latitude']?.toDouble();
      final lng = location['longitude']?.toDouble();
      final radius = location['radius']?.toDouble() ?? 50.0;

      if (lat != null && lng != null) {
        final position = LatLng(lat, lng);

        // Add marker
        _mainMapMarkers.add(
          Marker(
            markerId: MarkerId(location['id']),
            position: position,
            infoWindow: InfoWindow(
              title: location['name'] ?? 'Unknown Location',
              snippet: 'Радиус: ${radius.toInt()}м',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            onTap: () => _showLocationDetails(location),
          ),
        );

        // Add circle
        _mainMapCircles.add(
          Circle(
            circleId: CircleId(location['id']),
            center: position,
            radius: radius,
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      }
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  location['name'] ?? 'Unknown Location',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${location['latitude']?.toStringAsFixed(6)}, ${location['longitude']?.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.radio_button_unchecked, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Радиус: ${location['radius']?.toStringAsFixed(0)}м',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ажилчид:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  (location['employeeIds'] as List<dynamic>?)?.map<Widget>((employeeId) {
                    final employee = _employees.firstWhere(
                      (emp) => emp['id'] == employeeId,
                      orElse: () => {'fullName': 'Unknown Employee'},
                    );
                    return Chip(
                      label: Text(
                        employee['fullName'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide(color: Colors.blue.shade200),
                    );
                  }).toList() ??
                  [],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editLocation(location);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text('Засах', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteLocation(location['id'], location['name']);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Устгах', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _locations.isNotEmpty
              ? CameraPosition(
                  target: LatLng(
                    _locations.first['latitude']?.toDouble() ?? 47.918,
                    _locations.first['longitude']?.toDouble() ?? 106.917,
                  ),
                  zoom: 16,
                )
              : const CameraPosition(target: LatLng(47.918, 106.917), zoom: 12),
          onMapCreated: (controller) {
            _mainMapController = controller;
          },
          markers: _mainMapMarkers,
          circles: _mainMapCircles,
          mapType: MapType.normal,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
        // Location count overlay
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_locations.length} байршил',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editLocation(Map<String, dynamic> location) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Засах функц удахгүй нэмэгдэнэ.'), backgroundColor: Colors.blue),
    );
  }

  void _confirmDeleteLocation(String locationId, String? locationName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Байршлыг устгах'),
          content: Text(
            'Та "${locationName ?? 'Unknown Location'}" байршлыг устгахдаа итгэлтэй байна уу?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Цуцлах')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteLocation(locationId);
              },
              child: const Text('Устгах', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade600),
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _locations.isEmpty
                  ? Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Байршил',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddLocationBottomSheet,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Байршил Нэмэх', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Байршил байхгүй байна.',
                                style: TextStyle(fontSize: 18, color: Colors.black54),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Байршил нэмэх товч дээр дарж байршил нэмнэ үү.',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                  : _buildMapView(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLocation(String locationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('organizations')
          .doc(user.uid)
          .collection('workLocations')
          .doc(locationId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Байршил амжилттай устгагдлаа!'),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchLocations();
      setState(() {}); // Refresh the UI
    } catch (e) {
      debugPrint("Error deleting location: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Алдаа гарлаа: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }
}
