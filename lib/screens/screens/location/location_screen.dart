import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:timex/index.dart';

class LocationScreen extends StatefulWidget {
  final String? employeeId;
  final String? organizationId;
  final Map<String, dynamic>? employeeData;

  const LocationScreen({
    Key? key,
    this.employeeId,
    this.organizationId,
    this.employeeData,
  }) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  final TextEditingController _reasonController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _assignedWorkLocations = [];
  bool _isLoadingLocations = true;
  bool _hasAssignedLocations = false;
  Map<String, dynamic>? _currentWorkLocation;
  bool _inWorkArea = false;
  bool _isTiming = false;

  Timer? _timer;
  int _seconds = 0;

  // Employee data (we'll get this from navigation arguments)
  String? _employeeId;
  String? _organizationId;

  @override
  void initState() {
    super.initState();

    // Get employee data from widget parameters or navigation arguments
    _employeeId = widget.employeeId;
    _organizationId = widget.organizationId;

    if (_employeeId != null && _organizationId != null) {
      _fetchAssignedWorkLocations();
    } else {
      _getEmployeeDataAndCheckLocations();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get employee data from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _employeeId = args['employeeId'] as String?;
      _organizationId = args['organizationId'] as String?;

      if (_employeeId != null && _organizationId != null) {
        _fetchAssignedWorkLocations();
      }
    }
  }

  void _getEmployeeDataAndCheckLocations() {
    // This will be called from didChangeDependencies once we have the data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _employeeId = args['employeeId'] as String?; // Fixed: was 'employeeIds'
        _organizationId = args['organizationId'] as String?;

        if (_employeeId != null && _organizationId != null) {
          _fetchAssignedWorkLocations();
        } else {
          setState(() {
            _isLoadingLocations = false;
            _hasAssignedLocations = false;
          });
        }
      }
    });
  }

  Future<void> _fetchAssignedWorkLocations() async {
    if (_employeeId == null || _organizationId == null) {
      debugPrint('Employee ID or Organization ID is null');
      setState(() {
        _isLoadingLocations = false;
        _hasAssignedLocations = false;
      });
      return;
    }

    try {
      debugPrint('Fetching work locations for employee: $_employeeId in organization: $_organizationId');

      // Remove the Firebase Auth check and proceed directly to Firestore query
      final workLocationsSnapshot = await _firestore
          .collection('organizations')
          .doc(_organizationId)
          .collection('workLocations')
          .where('employeeIds', arrayContains: _employeeId)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Query timeout');
        },
      );

      // Rest of your code remains the same...
      final assignedLocations = <Map<String, dynamic>>[];

      for (final doc in workLocationsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        assignedLocations.add(data);
        debugPrint('Found work location: ${data['name']} with ID: ${doc.id}');
      }

      setState(() {
        _assignedWorkLocations = assignedLocations;
        _hasAssignedLocations = assignedLocations.isNotEmpty;
        _isLoadingLocations = false;
      });

      debugPrint('Found ${assignedLocations.length} assigned work locations');

      if (_hasAssignedLocations) {
        _requestLocationPermission();
      }

    } catch (e) {
      debugPrint('Error fetching work locations: $e');

      // Handle specific error types
      String errorMessage = 'Ажлын байршил ачаалахад алдаа гарлаа';

      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Хандах эрх хүрэлцээгүй байна.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Сүлжээний алдаа. Интернет холболтоо шалгана уу.';
      } else if (e is TimeoutException) {
        errorMessage = 'Хугацаа хэтэрсэн. Дахин оролдоно уу.';
      }

      setState(() {
        _isLoadingLocations = false;
        _hasAssignedLocations = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Дахин оролдох',
              textColor: Colors.white,
              onPressed: _fetchAssignedWorkLocations,
            ),
          ),
        );
      }
    }
  }
  // Add a method to check authentication status
  Future<bool> _checkAuthenticationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No authenticated user found');
      return false;
    }

    try {
      // Try to get the ID token to verify the user is still authenticated
      final idToken = await user.getIdToken(true);
      debugPrint('User is authenticated with token: ${idToken?.substring(0, 20)}...');
      return true;
    } catch (e) {
      debugPrint('Authentication token error: $e');
      return false;
    }
  }

  // Rest of your existing methods remain the same...
  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Байршлын зөвшөөрөл шаардлагатай.')),
      );
      await openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(position.latitude, position.longitude);

      // Check if employee is in any assigned work location
      _checkWorkLocationProximity(current);

      setState(() {
        _currentLocation = current;
      });

      // Animate camera to current location or first work location
      if (_mapController != null) {
        if (_assignedWorkLocations.isNotEmpty) {
          final firstLocation = _assignedWorkLocations.first;
          final workLatLng = LatLng(
            firstLocation['latitude']?.toDouble() ?? 0.0,
            firstLocation['longitude']?.toDouble() ?? 0.0,
          );
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(workLatLng, 16));
        } else {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(current, 16));
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Байршил авахад алдаа гарлаа: $e')),
      );
    }
  }

  void _checkWorkLocationProximity(LatLng currentLocation) {
    bool inAnyWorkArea = false;
    Map<String, dynamic>? nearestWorkLocation;

    for (final workLocation in _assignedWorkLocations) {
      final workLat = workLocation['latitude']?.toDouble() ?? 0.0;
      final workLng = workLocation['longitude']?.toDouble() ?? 0.0;
      final radius = workLocation['radius']?.toDouble() ?? 50.0;

      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        workLat,
        workLng,
      );

      if (distance <= radius) {
        inAnyWorkArea = true;
        nearestWorkLocation = workLocation;
        break;
      }
    }

    setState(() {
      _inWorkArea = inAnyWorkArea;
      _currentWorkLocation = nearestWorkLocation;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      if (_assignedWorkLocations.isNotEmpty) {
        final firstLocation = _assignedWorkLocations.first;
        final workLatLng = LatLng(
          firstLocation['latitude']?.toDouble() ?? 0.0,
          firstLocation['longitude']?.toDouble() ?? 0.0,
        );
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(workLatLng, 16));
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
      }
    }
  }

  Set<Circle> _buildWorkLocationCircles() {
    final circles = <Circle>{};

    for (int i = 0; i < _assignedWorkLocations.length; i++) {
      final location = _assignedWorkLocations[i];
      final lat = location['latitude']?.toDouble() ?? 0.0;
      final lng = location['longitude']?.toDouble() ?? 0.0;
      final radius = location['radius']?.toDouble() ?? 50.0;

      circles.add(
        Circle(
          circleId: CircleId('work_area_$i'),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blueAccent,
          strokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  Set<Marker> _buildWorkLocationMarkers() {
    final markers = <Marker>{};

    for (int i = 0; i < _assignedWorkLocations.length; i++) {
      final location = _assignedWorkLocations[i];
      final lat = location['latitude']?.toDouble() ?? 0.0;
      final lng = location['longitude']?.toDouble() ?? 0.0;
      final name = location['name'] as String? ?? 'Ажлын байршил ${i + 1}';

      markers.add(
        Marker(
          markerId: MarkerId('work_location_$i'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: 'Радиус: ${location['radius']?.toInt() ?? 50}м',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  void _toggleTimer() async {
    if (!_isTiming) {
      if (!_inWorkArea) {
        // If NOT in work area, ask reason
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Байршил зөрүүтэй байна'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Та ажлын байранд байхгүй байна.'),
                  const SizedBox(height: 8),
                  const Text('Шалтгаанаа бичнэ үү:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Жишээ нь: Гадаад уулзалт, гадаа ажил гэх мэт',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Болих'),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Save request with reason to Firestore here
                    Navigator.pop(context, true);
                  },
                  child: const Text('Илгээж эхлүүлэх'),
                ),
              ],
            );
          },
        );

        if (shouldProceed != true) return;
      } else {
        // If in work area, confirm start
        final confirmStart = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Баталгаажуулах'),
            content: Text(
                'Цагийн бичлэгийг эхлүүлэх үү?\n\nАжлын байршил: ${_currentWorkLocation?['name'] ?? 'Танилцуулаагүй'}'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Үгүй'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Тийм'),
              ),
            ],
          ),
        );

        if (confirmStart != true) return;
      }
    } else {
      // Confirm end time
      final confirmEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Баталгаажуулах'),
          content: const Text('Цагийн бичлэгийг зогсоох уу?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Үгүй'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Тийм'),
            ),
          ],
        ),
      );

      if (confirmEnd != true) return;
    }

    // Toggle timer
    if (_isTiming) {
      _timer?.cancel();
    } else {
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _seconds++;
        });
      });
    }

    setState(() {
      _isTiming = !_isTiming;
    });
  }

  String _formatTime(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/loader.json', width: 80, height: 80),
              const SizedBox(height: 16),
              const Text(
                'Ажлын байршил шалгаж байна...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasAssignedLocations) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ажлын байршил тохируулаагүй',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Таны байгууллага танд ажлын байршил оноогоогүй байна. Удирдлагатайгаа холбогдоно уу.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _fetchAssignedWorkLocations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Дахин шалгах'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hours = _formatTime(_seconds ~/ 3600);
    final minutes = _formatTime((_seconds % 3600) ~/ 60);
    final seconds = _formatTime(_seconds % 60);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _currentLocation == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/loader.json', width: 80, height: 80),
            const SizedBox(height: 16),
            const Text(
              'Байршил авч байна...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 16,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              circles: _buildWorkLocationCircles(),
              markers: _buildWorkLocationMarkers(),
            ),
          ),

          // Time tracker header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _timeBox(hours, 'Цаг'),
                  _timeBox(minutes, 'Минут'),
                  _timeBox(seconds, 'Секунд'),
                ],
              ),
            ),
          ),

          // Location status
          Positioned(
            top: 150,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _inWorkArea ? Colors.green.shade100 : Colors.red.shade100,
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
                children: [
                  Icon(
                    _inWorkArea ? Icons.check_circle : Icons.error,
                    color: _inWorkArea ? Colors.green.shade700 : Colors.red.shade700,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  txt(
                    _inWorkArea
                        ? 'Та ажлын байранд байна'
                        : 'Та ажлын байранд байхгүй байна',
                    style: TxtStl.bodyText1(
                      color: _inWorkArea ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_inWorkArea && _currentWorkLocation != null) ...[
                    const SizedBox(height: 4),
                    txt(
                      'Байршил: ${_currentWorkLocation!['name']}',
                      style: TxtStl.bodyText1(
                        color: Colors.green.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Work locations info
          if (_assignedWorkLocations.length > 1)
            Positioned(
              top: 240,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: txt(
                        'Танд ${_assignedWorkLocations.length} ажлын байршил хуваарилагдсан байна',
                        style: TxtStl.bodyText1(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Start/End button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _toggleTimer,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isTiming ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: txt(
                _isTiming ? 'Зогсоох' : 'Эхлүүлэх',
                style: TxtStl.bodyText1(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: txt(
            value,
            style: TxtStl.bodyText1(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        txt(label, style: TxtStl.bodyText1(color: Colors.black54)),
      ],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _timer?.cancel();
    super.dispose();
  }
}