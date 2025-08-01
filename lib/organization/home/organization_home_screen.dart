// lib/screens/organization/home_tabs_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/index.dart';

import '../../routes/routes.dart';
import 'dashboard/dashboard_screen.dart';

class OrganizationHomeScreen extends StatefulWidget {
  final Map<String, dynamic> organizationData;
  final User user;

  const OrganizationHomeScreen({
    super.key,
    required this.organizationData,
    required this.user,
  });

  @override
  State<OrganizationHomeScreen> createState() => _OrganizationHomeScreenState();
}

class _OrganizationHomeScreenState extends State<OrganizationHomeScreen> {
  final List<Map<String, dynamic>> _tabs = const [
    {'icon': Icons.dashboard, 'title': 'Цагийн тайлан'},
    {'icon': Icons.work, 'title': 'Цалин'},
    {'icon': Icons.location_on_rounded, 'title': 'Байршил'},
    {'icon': Icons.group, 'title': 'Ажилтан'},
    {'icon': Icons.timelapse, 'title': 'Цагийн хүсэлт'},
    {'icon': Icons.location_on_outlined, 'title': 'Илгээсэн байршил'},
    {'icon': Icons.feedback, 'title': 'Санал хүсэлт'},
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(organizationData: widget.organizationData),
      const Center(child: Text("Projects Screen")),
      OrganizationLocationScreen(),
      const Center(child: Text("Clients Screen")),
      const Center(child: Text("Team Screen")),
      const Center(child: Text("Team Screen")),
      const Center(child: Text("Team Screen")),
    ];

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.organizationData['organizationName'] ?? 'Organization',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(Routes.loginScreen, (route) => false);
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 10), // Add a bit of height for padding
            child: Container(
              color: Colors.white,// Padding for the entire tab bar
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start, // Align tabs to the start
                labelColor: Colors.blue.shade800,
                unselectedLabelColor: Colors.black54,
                indicatorSize: TabBarIndicatorSize.tab, // Makes the indicator fill the entire tab
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 0.5,
                  ),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                tabs: _tabs.map((tab) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab['icon'] as IconData, size: 20),
                        const SizedBox(width: 8),
                        Text(tab['title'] as String),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: screens,
        ),
      ),
    );
  }
}