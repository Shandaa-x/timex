import 'package:flutter/material.dart';
import 'package:timex/screens/time_report/monthly_statistic_screen.dart';
import 'package:timex/screens/time_track/time_tracking_screen.dart';
import 'calendar_uploader.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  bool _isUploading = false;
  String _status = '';

  Future<void> _uploadCalendar() async {
    setState(() {
      _isUploading = true;
      _status = 'Starting upload...';
    });

    try {
      await CalendarUploader.uploadCalendarDays();
      setState(() {
        _status = '✅ Successfully uploaded 365 days!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Upload'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Upload 365 Calendar Days',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'This will create 365 calendar days for 2025 with:\n'
              '• Working hours calculation\n'
              '• Holiday detection\n'
              '• Weekend handling\n'
              '• Week number calculation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            if (_isUploading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_status),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _uploadCalendar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upload Calendar Days', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],

            if (_status.isNotEmpty && !_isUploading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅') ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _status.startsWith('✅') ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: Text('Цаг бүртгэл'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TimeTrackScreen()),
                );
              },
            ),
            const SizedBox(height: 10), // spacing between buttons
            ElevatedButton(
              child: Text('Тайлан'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MonthlyStatisticsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
