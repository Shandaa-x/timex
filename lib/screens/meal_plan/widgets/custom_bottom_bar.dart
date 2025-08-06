import 'package:flutter/material.dart';

enum CustomBottomBarVariant {
  standard,
  floating,
  minimal,
}

class CustomBottomBar extends StatefulWidget {
  final CustomBottomBarVariant variant;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? elevation;

  const CustomBottomBar({
    super.key,
    this.variant = CustomBottomBarVariant.standard,
    this.currentIndex = 0,
    this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<_BottomNavItem> _navItems = [
    _BottomNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      route: '/home-dashboard',
    ),
    _BottomNavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Browse',
      route: '/recipe-browse',
    ),
    _BottomNavItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Meal Plan',
      route: '/meal-plan-calendar',
    ),
    _BottomNavItem(
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart,
      label: 'Grocery',
      route: '/grocery-list',
    ),
    _BottomNavItem(
      icon: Icons.kitchen_outlined,
      activeIcon: Icons.kitchen,
      label: 'Pantry',
      route: '/pantry-inventory',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (widget.variant) {
      case CustomBottomBarVariant.floating:
        return _buildFloatingBottomBar(context, theme, colorScheme);
      case CustomBottomBarVariant.minimal:
        return _buildMinimalBottomBar(context, theme, colorScheme);
      case CustomBottomBarVariant.standard:
      default:
        return _buildStandardBottomBar(context, theme, colorScheme);
    }
  }

  Widget _buildStandardBottomBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.currentIndex;

              return Expanded(
                child: _buildNavItem(
                  context,
                  colorScheme,
                  item,
                  isSelected,
                  index,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _navItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == widget.currentIndex;

                  return Expanded(
                    child: _buildNavItem(
                      context,
                      colorScheme,
                      item,
                      isSelected,
                      index,
                      isFloating: true,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalBottomBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.currentIndex;

              return _buildMinimalNavItem(
                context,
                colorScheme,
                item,
                isSelected,
                index,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    ColorScheme colorScheme,
    _BottomNavItem item,
    bool isSelected,
    int index, {
    bool isFloating = false,
  }) {
    final selectedColor = widget.selectedItemColor ?? colorScheme.primary;
    final unselectedColor = widget.unselectedItemColor ??
        colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _handleTap(context, index, item.route),
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? _scaleAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(isFloating ? 8 : 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? selectedColor : unselectedColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? selectedColor : unselectedColor,
                      letterSpacing: 0.5,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimalNavItem(
    BuildContext context,
    ColorScheme colorScheme,
    _BottomNavItem item,
    bool isSelected,
    int index,
  ) {
    final selectedColor = widget.selectedItemColor ?? colorScheme.primary;
    final unselectedColor = widget.unselectedItemColor ??
        colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _handleTap(context, index, item.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedColor,
                  letterSpacing: 0.5,
                ),
                child: Text(item.label),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, int index, String route) {
    // Trigger haptic feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Call the onTap callback if provided
    if (widget.onTap != null) {
      widget.onTap!(index);
    }

    // Navigate to the selected route if it's different from current
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != route) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
      );
    }
  }
}

class _BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
