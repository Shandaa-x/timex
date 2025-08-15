import 'package:flutter/material.dart';
import 'package:timex/screens/meal_plan/meal_plan_calendar.dart';
import 'package:timex/screens/time_report/monthly_statistic_screen.dart';
import 'package:timex/screens/food_report/food_report_screen.dart';
import 'package:timex/screens/home/home_screen.dart';
import 'package:timex/index.dart';
import 'package:timex/screens/time_track/time_tracking_screen.dart';
import 'package:timex/screens/qpay/qr_code_screen.dart';
import 'package:timex/services/realtime_food_total_service.dart';
import 'package:timex/utils/export_user_data.dart';

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
    print('MainScreen initState called');
    _pageController = PageController(initialPage: _currentIndex);

    _screens = [
      HomeScreen(),
      TimeTrackScreen(),
      MonthlyStatisticsScreen(),
      MealPlanCalendar(),
      FoodReportScreen(),
      QRCodeScreen(),
    ];
    print('Screens initialized: ${_screens.length}');

    // Start listening to real-time food total updates
    RealtimeFoodTotalService.startListening();
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
    _screens[0] = HomeScreen();
    _screens[1] = TimeTrackScreen();
    _screens[2] = MonthlyStatisticsScreen();
    _screens[3] = MealPlanCalendar();
    _screens[4] = FoodReportScreen();
    _screens[5] = QRCodeScreen();
  }

  void _onTabTapped(int index) {
    print('Tab tapped: $index (QR screen at index 4)'); // Debug output
    print('Current screen count: ${_screens.length}');
    if (index < _screens.length) {
      print('Navigating to screen: ${_screens[index].runtimeType}');
      _pageController.jumpToPage(index);
      setState(() {
        _currentIndex = index;
      });
    } else {
      print(
        'ERROR: Index $index out of bounds for screens array of length ${_screens.length}',
      );
    }
  }

  Future<bool> _onWillPop() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Гарах'),
        content: Text('Та системээс гарахыг хүсч байна уу?'),
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
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.googleLogin, (route) => false);
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
        body: Stack(
          children: [
            PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageController,
              itemCount: _screens.length,
              itemBuilder: (context, index) {
                try {
                  return _screens[index];
                } catch (e) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text('Error loading screen at index $index'),
                          SizedBox(height: 8),
                          Text('$e'),
                        ],
                      ),
                    ),
                  );
                }
              },
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            // Debug button to test QR screen
            // if (_currentIndex == 0) // Only show on first tab
            //   Positioned(
            //     top: 100,
            //     right: 20,
            //     child: FloatingActionButton(
            //       mini: true,
            //       onPressed: () {
            //         _pageController.jumpToPage(5); // Jump to QR screen (index 5)
            //         setState(() {
            //           _currentIndex = 5;
            //         });
            //       },
            //       backgroundColor: Colors.red,
            //       child: Icon(Icons.qr_code),
            //     ),
            //   ),
            // Meal Payment Test Button
            // if (_currentIndex == 0) // Only show on first tab
            //   Positioned(
            //     top: 160,
            //     right: 20,
            //     child: FloatingActionButton(
            //       mini: true,
            //       onPressed: () async {
            //         try {
            //           // Import the function at the top of this file
            //           // import '../../utils/meal_payment_example.dart';
                      
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             const SnackBar(
            //               content: Text('🚀 Creating meal payment example...'),
            //               backgroundColor: Colors.blue,
            //             ),
            //           );
                      
            //           // Call the meal payment creation function
            //           // await createMealPaymentExample();
                      
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             const SnackBar(
            //               content: Text('✅ Meal payment example created! Check console.'),
            //               backgroundColor: Colors.green,
            //             ),
            //           );
            //         } catch (e) {
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(
            //               content: Text('❌ Error: $e'),
            //               backgroundColor: Colors.red,
            //             ),
            //           );
            //         }
            //       },
            //       backgroundColor: Colors.green,
            //       child: Icon(Icons.restaurant),
            //     ),
            //   ),
            // Debug Export User Data Button
            if (_currentIndex == 0) // Only show on first tab
              Positioned(
                top: 220,
                right: 20,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () async {
                    await exportUserData(context, 'IjLl3CSTwaTN4tM42yRNxakxDYx1');
                  },
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.download),
                ),
              ),
          ],
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
      {'icon': Icons.access_time, 'label': 'Цаг бүртгэл'},
      {'icon': Icons.note, 'label': 'Цагийн тайлан'},
      {'icon': Icons.food_bank, 'label': 'Хоолны хуваарь'},
      {'icon': Icons.analytics, 'label': 'Хоолны тайлан'},
      {'icon': Icons.qr_code, 'label': 'QR code'},
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
                child: InkWell(
                  onTap: () {
                    _onTabTapped(index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8, // Increased padding for better tap target
                      horizontal: 4,
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
                              ? Colors
                                    .white // White on green for better contrast
                              : Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        txt(
                          tabs[index]['label'] as String,
                          style: TxtStl.bodyText1(
                            color: isSelected
                                ? Colors
                                      .white // White text on green
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 9,
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
    RealtimeFoodTotalService.stopListening();
    super.dispose();
  }
}
