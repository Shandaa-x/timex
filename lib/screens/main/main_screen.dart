import 'package:flutter/material.dart';
import 'package:timex/screens/meal_plan/meal_plan_calendar.dart';
import 'package:timex/screens/time_report/monthly_statistic_screen.dart';
import 'package:timex/screens/food_report/food_report_screen.dart';
import 'package:timex/screens/home/home_screen.dart';
import 'package:timex/index.dart';
import 'package:timex/screens/time_track/time_tracking_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

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
      HomeScreen(onNavigateToTab: _onTabTapped),
      TimeTrackScreen(onNavigateToTab: _onTabTapped),
      MonthlyStatisticsScreen(onNavigateToTab: _onTabTapped),
      MealPlanCalendar(onNavigateToTab: _onTabTapped),
      FoodReportScreen(onNavigateToTab: _onTabTapped),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for arguments from ModalRoute
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (routeArgs != null) {
      // Rebuild screens with updated employee data
      _updateScreensWithEmployeeData();
      setState(() {});
    }
  }

  void _updateScreensWithEmployeeData() {
    _screens[0] = HomeScreen(onNavigateToTab: _onTabTapped);
    _screens[1] = TimeTrackScreen(onNavigateToTab: _onTabTapped);
    _screens[2] = MonthlyStatisticsScreen(onNavigateToTab: _onTabTapped);
    _screens[3] = MealPlanCalendar(onNavigateToTab: _onTabTapped);
    _screens[4] = FoodReportScreen(onNavigateToTab: _onTabTapped);
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
        title: const Text('Гарах'),
        content: Text(
          'Та системээс гарахыг хүсч байна уу?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Navigate back to login selection
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return false;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        drawer: _buildDrawer(),
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

  // getSalary(x=2000, weekDays
  //   x*11.5*/100/weekDays) {
  //   // Example calculation, replace with actual logic
  //   return x
  // }

  Widget _buildSegmentedTabBar() {
    final tabs = [
      {'icon': Icons.home, 'label': 'Нүүр'},
      {'icon': Icons.access_time, 'label': 'Цаг'},
      {'icon': Icons.note, 'label': 'Тайлан'},
      {'icon': Icons.food_bank, 'label': 'Хоолны хуваарь'},
      {'icon': Icons.analytics, 'label': 'Хоолны тайлан'},
    ];

    return Container(
      color: const Color(0xFF2C3E50), // Darker, more professional gray-blue
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(tabs.length, (index) {
              final isSelected = _currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A8B3A) // Your app's forest green
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[index]['icon'] as IconData,
                          color: isSelected
                              ? Colors.white // White on green for better contrast
                              : Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        txt(
                          tabs[index]['label'] as String,
                          style: TxtStl.bodyText1(
                            color: isSelected
                                ? Colors.white // White text on green
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Drawer Header with gradient
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D5A27), // Forest green
                  Color(0xFF4A8B3A), // Lighter forest green
                ],
              ),
            ),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF2D5A27),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'TimeX App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Цаг хугацаа болон хоолны менежмент',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Drawer Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard,
                  title: 'Хяналтын самбар',
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(0); // Home screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.access_time,
                  title: 'Цагийн бүртгэл',
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(1); // Time tracking screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.analytics,
                  title: 'Тайлангууд',
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(2); // Statistics screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.restaurant_menu,
                  title: 'Хоолны хуваарь',
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(3); // Meal plan screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.receipt_long,
                  title: 'Хоолны тайлан',
                  onTap: () {
                    Navigator.pop(context);
                    _onTabTapped(4); // Food report screen
                  },
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Тохиргоо',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Тохиргоо цонх удахгүй нээгдэнэ')),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  title: 'Тусламж',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to help
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Тусламжийн цонх удахгүй нээгдэнэ')),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'Програмын тухай',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog();
                  },
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Гарах',
                  onTap: () {
                    Navigator.pop(context);
                    _onWillPop();
                  },
                  textColor: const Color(0xFFE74C3C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? const Color(0xFF2D5A27),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? const Color(0xFF2C3E50),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hoverColor: const Color(0xFF4A8B3A).withOpacity(0.1),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TimeX App-ын тухай'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Хувилбар: 1.0.0'),
            SizedBox(height: 8),
            Text('Цаг хугацаа болон хоолны менежментийн програм'),
            SizedBox(height: 8),
            Text('© 2025 TimeX App'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
