import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const QuickActionsGrid({
    super.key,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'icon': Icons.access_time,
        'title': 'Цаг бүртгэх',
        'color': const Color(0xFF059669),
        'onTap': () => onNavigateToTab?.call(1), // Navigate to time tracking
      },
      {
        'icon': Icons.restaurant_menu,
        'title': 'Хоолны хуваарь',
        'color': const Color(0xFF3B82F6),
        'onTap': () => onNavigateToTab?.call(3), // Navigate to meal plan
      },
      {
        'icon': Icons.analytics,
        'title': 'Тайлан харах',
        'color': const Color(0xFF8B5CF6),
        'onTap': () => onNavigateToTab?.call(2), // Navigate to statistics
      },
      {
        'icon': Icons.receipt_long,
        'title': 'Хоолны тайлан',
        'color': const Color(0xFFEF4444),
        'onTap': () => onNavigateToTab?.call(4), // Navigate to food report
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 5,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionCard(
          icon: action['icon'] as IconData,
          title: action['title'] as String,
          color: action['color'] as Color,
          onTap: action['onTap'] as VoidCallback,
        );
      },
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
