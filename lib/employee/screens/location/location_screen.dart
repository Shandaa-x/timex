import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timex/index.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  final TextEditingController _reasonController = TextEditingController();
  final LatLng _workLocation = LatLng(47.898392033701775, 106.91276818653961);
  final double _radiusInMeters = 20;

  bool _inWorkArea = false;
  bool _isTiming = false;

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Location permission is required.')));
      await openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(position.latitude, position.longitude);
      final distance = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        _workLocation.latitude,
        _workLocation.longitude,
      );

      setState(() {
        _currentLocation = current;
        _inWorkArea = distance <= _radiusInMeters;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_workLocation, 16));
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
                    // Optional: Save request with reason to Firestore here
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
            content: const Text('Цагийн бичлэгийг эхлүүлэх үү?'),
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
    final hours = _formatTime(_seconds ~/ 3600);
    final minutes = _formatTime((_seconds % 3600) ~/ 60);
    final seconds = _formatTime(_seconds % 60);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _currentLocation == null
          ? Center(child: Lottie.asset('assets/loader.json', width: 50, height: 50))
          : Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _currentLocation!, zoom: 16),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              circles: {
                Circle(
                  circleId: const CircleId('work_area'),
                  center: _workLocation,
                  radius: _radiusInMeters,
                  fillColor: Colors.blue.withOpacity(0.2),
                  strokeColor: Colors.blueAccent,
                  strokeWidth: 2,
                ),
              },
            ),
          ),

          // Time tracker header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
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
          Positioned(
            top: 150,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _inWorkArea ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: txt(
                _inWorkArea
                    ? 'Та ажлын байран дээр байна'
                    : 'Та ажлын байранд байхгүй байна',
                style: TxtStl.bodyText1(
                  color: _inWorkArea ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Start/End button
          Positioned(
            bottom: 10,
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
              ),
              child: txt(
                _isTiming ? 'End' : 'Start',
                style: TxtStl.bodyText1(fontSize: 18, color: Colors.white),
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
        SizedBox(height: 4),
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
