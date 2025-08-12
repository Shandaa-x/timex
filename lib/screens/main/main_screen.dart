import 'package:flutter/material.dart';
import 'package:timex/screens/meal_plan/meal_plan_calendar.dart';
import 'package:timex/screens/time_report/monthly_statistic_screen.dart';
import 'package:timex/screens/food_report/food_report_screen.dart';
import 'package:timex/index.dart';
import 'package:timex/screens/time_track/time_tracking_screen.dart';
import 'package:timex/screens/qpay/qr_code_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  late final List<Widget> _screens;

  // Employee data variables
  String _employeeFullName = 'Employee';
  Map<String, dynamic>? _employeeData;
  String? _employeeId;
  String? _organizationId;
  bool _isFirstLogin = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    _screens = [
      TimeTrackScreen(),
      MonthlyStatisticsScreen(),
      MealPlanCalendar(),
      FoodReportScreen(),
      QRCodeScreen(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for arguments from ModalRoute
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (routeArgs != null) {
      _extractEmployeeDataFromRoute(routeArgs);
      // Rebuild screens with updated employee data
      _updateScreensWithEmployeeData();
      setState(() {});
    }
  }

  void _extractEmployeeDataFromRoute(Map<String, dynamic> args) {
    _employeeData = args['employeeData'] as Map<String, dynamic>?;
    _employeeId = args['employeeId'] as String?;
    _organizationId = args['organizationId'] as String?;
    _isFirstLogin = args['isFirstLogin'] as bool? ?? false;

    // Extract employee full name
    if (_employeeData != null) {
      final firstName = _employeeData!['firstName'] as String? ?? '';
      final lastName = _employeeData!['lastName'] as String? ?? '';
      final fullName = _employeeData!['fullName'] as String?;

      // Use fullName if available, otherwise construct from firstName and lastName
      if (fullName != null && fullName.isNotEmpty) {
        _employeeFullName = fullName;
      } else if (firstName.isNotEmpty || lastName.isNotEmpty) {
        _employeeFullName = '$lastName $firstName'.trim();
      } else {
        _employeeFullName =
            _employeeData!['employeeEmail'] as String? ?? 'Employee';
      }

      debugPrint('Employee logged in: $_employeeFullName');
      debugPrint('Employee ID: $_employeeId');
      debugPrint('Organization ID: $_organizationId');
      debugPrint('Is first login: $_isFirstLogin');

      // Show first login message if needed
      // if (_isFirstLogin) {
      //   WidgetsBinding.instance.addPostFrameCallback((_) {
      //     _showFirstLoginWelcome();
      //   });
      // }
    }
  }

  void _updateScreensWithEmployeeData() {
    _screens[0] = TimeTrackScreen();
    _screens[1] = MonthlyStatisticsScreen();
    _screens[2] = MealPlanCalendar();
    _screens[3] = FoodReportScreen();
    _screens[4] = QRCodeScreen();
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
          '$_employeeFullName, та системээс гарахыг хүсч байна уу?',
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
      {'icon': Icons.note, 'label': 'Тайлан'},
      {'icon': Icons.food_bank, 'label': 'Хоолны хуваарь'},
      {'icon': Icons.analytics, 'label': 'Хоолны тайлан'},
      {'icon': Icons.qr_code, 'label': 'QR Код'},
    ];

    return Container(
      color: const Color(0xFF3f3f3f),
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
                          ? const Color(0xFFC7BBE1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[index]['icon'] as IconData,
                          color: isSelected
                              ? Colors.black
                              : Colors.white.withOpacity(0.6),
                          size: 20,
                        ),
                        txt(
                          tabs[index]['label'] as String,
                          style: TxtStl.bodyText1(
                            color: isSelected
                                ? Colors.black
                                : Colors.white.withOpacity(0.6),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
