import 'package:flutter/material.dart';
import 'package:timex/screens/meal_plan/widgets/custom_icon_widget.dart';

class MealContextMenu extends StatelessWidget {
  final Map<String, dynamic> meal;
  final String dateKey;
  final String mealType;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onFindAlternative;

  const MealContextMenu({
    super.key,
    required this.meal,
    required this.dateKey,
    required this.mealType,
    required this.onEdit,
    required this.onRemove,
    required this.onDuplicate,
    required this.onFindAlternative,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Meal info header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    meal['image'] as String? ??
                        'https://images.unsplash.com/photo-1546554137-f86b9593a222?fm=jpg&q=60&w=3000',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['name'] as String? ?? 'Unknown Recipe',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getMealTypeLabel(mealType)} • ${_formatDate(dateKey)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colorScheme.outline.withOpacity(0.2),
          ),

          // Menu options
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  icon: 'edit',
                  title: 'Edit Meal',
                  subtitle: 'Modify recipe or serving size',
                  onTap: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: 'content_copy',
                  title: 'Duplicate to Other Days',
                  subtitle: 'Copy this meal to multiple days',
                  onTap: () {
                    Navigator.pop(context);
                    onDuplicate();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: 'swap_horiz',
                  title: 'Find Alternative',
                  subtitle: 'Suggest similar recipes',
                  onTap: () {
                    Navigator.pop(context);
                    onFindAlternative();
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: 'delete_outline',
                  title: 'Remove',
                  subtitle: 'Remove from meal plan',
                  onTap: () {
                    Navigator.pop(context);
                    onRemove();
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),

          // Cancel button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? colorScheme.error.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomIconWidget(
                iconName: icon,
                color: isDestructive ? colorScheme.error : colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: colorScheme.onSurface.withOpacity(0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getMealTypeLabel(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return 'Meal';
    }
  }

  String _formatDate(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${months[month - 1]} $day';
    }
    return dateKey;
  }
}
