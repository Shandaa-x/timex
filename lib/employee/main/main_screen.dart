import 'package:flutter/material.dart';
import 'package:timex/index.dart';

class MainScreen extends StatefulWidget {
  final String loginMethod;
  final String userName;
  final String? userImage;

  const MainScreen({
    super.key,
    required this.loginMethod,
    required this.userName,
    this.userImage,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _screens = [
      HomeScreen(userName: widget.userName, userImage: widget.userImage),
      const LocationScreen(),
      HomeScreen(userName: 'Guest'), // or pass any fallback name/image here
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
            onPressed: () => Navigator.of(context).pop(false), // Do not logout
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm logout
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Navigate to login screen by popping all and pushing login
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.loginScreen, // Adjust to your login route name
            (route) => false,
      );
      return false; // Do not pop automatically, we handled navigation
    } else {
      return false; // Prevent popping if user cancels
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
          itemBuilder: (context, index) {
            return _screens[index];
          },
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
      {'icon': Icons.home, 'label': 'Нүүр'},
      {'icon': Icons.location_on_rounded, 'label': 'Цаг'},
      {'icon': Icons.search, 'label': 'Search'},
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
                    color: isSelected ? const Color(0xFFC7BBE1) : Colors.transparent, // Pink container
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(tabs[index]['icon'] as IconData, color: isSelected ? Colors.black : Colors.white.withOpacity(0.6), size: 24),
                      const SizedBox(width: 6),
                      txt(tabs[index]['label'] as String, style: TxtStl.bodyText1(color: isSelected ? Colors.black : Colors.white.withOpacity(0.6), fontSize: 11)),
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
