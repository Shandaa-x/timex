import 'package:flutter/material.dart';

import '../index.dart';

enum DrawerScreenType {
  home,
  timeTracking,
  timeReport,
  mealPlan,
  foodReport,
}

class CustomDrawer extends StatelessWidget {
  final DrawerScreenType currentScreen;
  final Function(int)? onNavigateToTab;

  const CustomDrawer({
    super.key,
    required this.currentScreen,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
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
                        Icons.access_time,
                        size: 40,
                        color: Color(0xFF2D5A27),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'TimeX App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
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
                  context,
                  icon: Icons.access_time,
                  title: 'Цагийн бүртгэл',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToTab?.call(0);
                  },
                  isSelected: currentScreen == DrawerScreenType.timeTracking,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics,
                  title: 'Цагийн тайлан',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToTab?.call(1);
                  },
                  isSelected: currentScreen == DrawerScreenType.timeReport,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.restaurant_menu,
                  title: 'Хоолны хуваарь',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToTab?.call(2);
                  },
                  isSelected: currentScreen == DrawerScreenType.mealPlan,
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Хоолны тайлан',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToTab?.call(3);
                  },
                  isSelected: currentScreen == DrawerScreenType.foodReport,
                ),
                const Divider(height: 20),
                
                // Screen-specific actions
                ..._buildScreenSpecificItems(context),
                
                const Divider(height: 20),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Тохиргоо',
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsDialog(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Тусламж',
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpDialog(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'Програмын тухай',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
                const Divider(height: 20),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout,
                  title: 'Гарах',
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
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

  List<Widget> _buildScreenSpecificItems(BuildContext context) {
    switch (currentScreen) {
      case DrawerScreenType.home:
        return [
          _buildDrawerItem(
            context,
            icon: Icons.dashboard,
            title: 'Dashboard тохиргоо',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dashboard тохиргоо удахгүй нэмэгдэнэ...')),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.refresh,
            title: 'Мэдээлэл шинэчлэх',
            onTap: () {
              Navigator.pushNamed(context, Routes.myNews);
            },
          ),
        ];
      case DrawerScreenType.timeTracking:
        return [
          _buildDrawerItem(
            context,
            icon: Icons.today,
            title: 'Өнөөдрийн мэдээлэл',
            onTap: () {
              Navigator.pop(context);
              _showTodayInfoDialog(context, 'Өнөөдрийн ажлын цагийн мэдээлэл');
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.location_on,
            title: 'Байршил харах',
            onTap: () {
              Navigator.pop(context);
              _showLocationDialog(context);
            },
          ),
        ];
      case DrawerScreenType.timeReport:
        return [
          _buildDrawerItem(
            context,
            icon: Icons.calendar_today,
            title: 'Календар',
            onTap: () {
              Navigator.pop(context);
              _showCalendarDialog(context);
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.bar_chart,
            title: 'Статистик',
            onTap: () {
              Navigator.pop(context);
              _showStatisticsDialog(context);
            },
          ),
        ];
      case DrawerScreenType.mealPlan:
        return [
          _buildDrawerItem(
            context,
            icon: Icons.add_circle,
            title: 'Хоол нэмэх',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Хоол нэмэх цонх нээгдэж байна...')),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.filter_list,
            title: 'Шүүлтүүр',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Шүүлтүүр идэвхжиж байна...')),
              );
            },
          ),
        ];
      case DrawerScreenType.foodReport:
        return [
          _buildDrawerItem(
            context,
            icon: Icons.payment,
            title: 'Төлбөрийн түүх',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Төлбөрийн түүх хэсэг рүү шилжиж байна...')),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Төлбөрийн хураангуй',
            onTap: () {
              Navigator.pop(context);
              _showPaymentSummaryDialog(context);
            },
          ),
        ];
    }
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2D5A27).withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
              ? const Color(0xFF2D5A27)
              : textColor ?? const Color(0xFF374151),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
                ? const Color(0xFF2D5A27)
                : textColor ?? const Color(0xFF374151),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showTodayInfoDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.today, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Өнөөдрийн мэдээлэл'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Байршлын мэдээлэл'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Байршлын мэдээлэл авч байна...'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
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

  void _showCalendarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calendar_today, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Календар'),
          ],
        ),
        content: const Text('Календарын цонх удахгүй нээгдэнэ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Статистикийн хураангуй'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Энэ сарын нийт цаг'),
            SizedBox(height: 8),
            Text('• Өнгөрсөн сартай харьцуулах'),
            SizedBox(height: 8),
            Text('• Ажлын өдрүүдийн статистик'),
            SizedBox(height: 8),
            Text('• Хоолны зардлын хураангуй'),
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

  void _showPaymentSummaryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Төлбөрийн хураангуй'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Энэ сарын нийт зардал'),
            SizedBox(height: 8),
            Text('• Төлөгдсөн төлбөр'),
            SizedBox(height: 8),
            Text('• Үлдэгдэл төлбөр'),
            SizedBox(height: 8),
            Text('• Өдрийн дундаж зардал'),
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Тохиргоо'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Мэдэгдлийн тохиргоо'),
            SizedBox(height: 8),
            Text('• Хэл солих'),
            SizedBox(height: 8),
            Text('• Темийн тохиргоо'),
            SizedBox(height: 8),
            Text('• Өгөгдлийн синхрон'),
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF2D5A27)),
            SizedBox(width: 8),
            Text('Тусламж'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TimeX App хэрэглэх заавар:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Цагийн бүртгэл: Ажил эхлэх/дуусгах'),
            Text('• Тайлан: Сарын болон долоо хоногийн статистик'),
            Text('• Хоолны хуваарь: Өдөр тутмын хоол бүртгэх'),
            Text('• Хоолны тайлан: Зардал болон төлбөрийн мэдээлэл'),
            SizedBox(height: 12),
            Text(
              'Дэлгэрэнгүй тусламж хэрэгтэй бол холбоо барина уу.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ойлголоо'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
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
            SizedBox(height: 12),
            Text(
              'Энэхүү програм нь ажилчдын цаг хугацаа болон хоолны зардлыг бүртгэж, удирдахад зориулагдсан.',
              style: TextStyle(fontSize: 14),
            ),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Гарах'),
        content: const Text('Та системээс гарахыг хүсч байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Гарах'),
          ),
        ],
      ),
    );
  }
}
