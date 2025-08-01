import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/index.dart';
import '../home/location/organization_location_screen.dart';

class OrganizationMainScreen extends StatefulWidget {
  final String loginMethod;
  final String userName;
  final String? userImage;
  final Map<String, dynamic> organizationData;
  final User user;  // Add this

  const OrganizationMainScreen({
    super.key,
    required this.loginMethod,
    required this.userName,
    required this.organizationData,
    required this.user,    // Add this
    this.userImage,
  });

  @override
  State<OrganizationMainScreen> createState() => _OrganizationMainScreenState();
}

class _OrganizationMainScreenState extends State<OrganizationMainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _screens = [
      OrganizationHomeScreen(
        organizationData: widget.organizationData,
        user: widget.user,  // Pass user here
      ),
      LocationScreen(),
      LocationScreen(),
      // const OrganizationLocationScreen(),
      // const OrganizationLocationScreen(),
    ];
  }

  void _onTabTapped(int index) {
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.loginScreen,
            (route) => false,
      );
      return false;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: PageView.builder(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          itemCount: _screens.length,
          itemBuilder: (context, index) => _screens[index],
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        bottomNavigationBar: _buildSegmentedTabBar(),
      ),
    );
  }

  Widget _buildSegmentedTabBar() {
    final tabs = [
      {'icon': Icons.home, 'label': 'Цэс'},
      {'icon': Icons.account_balance_sharp, 'label': 'Orga'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      color: const Color(0xFF3f3f3f),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(tabs.length, (index) {
              final isSelected = _currentIndex == index;
              return GestureDetector(
                onTap: () => _onTabTapped(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 21),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFC7BBE1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(tabs[index]['icon'] as IconData,
                          color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
                          size: 24),
                      const SizedBox(width: 6),
                      txt(
                        tabs[index]['label'] as String,
                        style: TxtStl.bodyText1(
                          color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
