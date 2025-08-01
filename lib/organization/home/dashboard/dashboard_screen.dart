// lib/screens/organization/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:timex/index.dart'; // Often implicitly imported, but good to be explicit

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> organizationData;

  const DashboardScreen({super.key, required this.organizationData});

  @override
  Widget build(BuildContext context) {
    // These values are based on the data in your provided code
    final int totalEmployees = organizationData['totalEmployees'] ?? 0;
    final int arrivedOnTime = organizationData['arrivedOnTime'] ?? 0;
    final int lateEmployees = organizationData['lateEmployees'] ?? 0;
    final int notArrived = totalEmployees - arrivedOnTime - lateEmployees;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          color: Colors.grey[50], // Light background color
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildMobileLayout(totalEmployees, arrivedOnTime, lateEmployees, notArrived)
            ],
          ),
        ),
      ),
      floatingActionButton: ElevatedButton(
        child: Text('Ажилтан нэмэх', style: TextStyle(color: Colors.white)), // Assuming white text
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800, // Example color from your other buttons
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        onPressed: () {
          // Pass organizationData as arguments to the named route
          Navigator.pushNamed(
            context,
            Routes.addEmployee,
            arguments: organizationData, // <--- THIS IS THE CRUCIAL CHANGE
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.grey[700]),
            Text(
              'Цаг бүртгэл', // Time Registration
              style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200], // Light background for dropdown
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'Өнөөдөр',
                  // Today
                  onChanged: (String? newValue) {
                    // TODO: Handle dropdown change
                  },
                  dropdownColor: Colors.grey[200],
                  // Dropdown menu background
                  style: const TextStyle(color: Colors.black87),
                  // Text color for selected item
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  items:
                  <String>['Өнөөдөр', 'Энэ долоо хоног', 'Энэ сар'] // Today, This week, This month
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.black87), // Text color for dropdown items
                        ),
                      ),
                    );
                  })
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200], // Light background for fullscreen button
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fullscreen, color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout(int totalEmployees, int arrivedOnTime, int lateEmployees, int notArrived) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart placeholder
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, // Light background for chart container
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
          ),
          child: Center(
            child: Text('Chart Placeholder', style: TextStyle(color: Colors.grey[600])),
          ),
        ),
        const SizedBox(height: 24),
        // Attendance summary
        Text('Нийт $totalEmployees ажилтан', style: const TextStyle(color: Colors.black87, fontSize: 16)),
        const SizedBox(height: 16),
        _statCard(title: 'Цагтаа ирсэн', count: arrivedOnTime, color: Colors.green),
        _statCard(title: 'Эрт тарсан', count: 0, color: Colors.blueGrey),
        _statCard(title: 'Тасалсан', count: notArrived, color: Colors.red),
        _statCard(title: 'Хоцорсон', count: lateEmployees, color: Colors.orange),
      ],
    );
  }

  Widget _statCard({required String title, required int count, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // Light background for stat cards
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          // Optional: Add subtle shadow for depth
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87, // Dark text color
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.black, // Dark text for count
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}