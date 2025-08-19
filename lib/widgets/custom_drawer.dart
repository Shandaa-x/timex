import 'package:flutter/material.dart';

import '../index.dart';

class CustomDrawer extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const CustomDrawer({
    super.key,
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
                    SizedBox(height: 10),
                    Text(
                      'TimeX App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text( 
                      'Цаг бүртгэл болон хоолны менежмент',
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
                  icon: Icons.article,
                  title: 'Миний чат',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, Routes.myChat);
                  },
                ),
                
                // Additional features
                _buildDrawerItem(
                  context,
                  icon: Icons.article,
                  title: 'Миний мэдээ',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, Routes.myNews);
                  },
                ),
                
                // const Divider(height: 20),
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
                  title: 'Аппын тухай',
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

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor ?? const Color(0xFF374151),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? const Color(0xFF374151),
            fontSize: 16,
            fontWeight: FontWeight.w500,
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
              Navigator.of(context).pushNamedAndRemoveUntil(Routes.googleLogin, (route) => false);
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
