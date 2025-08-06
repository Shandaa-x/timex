import 'package:flutter/material.dart';

enum CustomAppBarVariant {
  standard,
  search,
  profile,
  recipe,
  mealPlan,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final CustomAppBarVariant variant;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onSearchTap;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.variant = CustomAppBarVariant.standard,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
    this.onSearchTap,
    this.searchController,
    this.onSearchChanged,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (variant) {
      case CustomAppBarVariant.search:
        return _buildSearchAppBar(context, theme, colorScheme);
      case CustomAppBarVariant.profile:
        return _buildProfileAppBar(context, theme, colorScheme);
      case CustomAppBarVariant.recipe:
        return _buildRecipeAppBar(context, theme, colorScheme);
      case CustomAppBarVariant.mealPlan:
        return _buildMealPlanAppBar(context, theme, colorScheme);
      case CustomAppBarVariant.standard:
      default:
        return _buildStandardAppBar(context, theme, colorScheme);
    }
  }

  Widget _buildStandardAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      leading: _buildLeading(context, colorScheme),
      actions: _buildActions(context, colorScheme),
      shadowColor: colorScheme.shadow,
    );
  }

  Widget _buildSearchAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Search recipes, ingredients...',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
      centerTitle: false,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      leading: _buildLeading(context, colorScheme),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/user-profile'),
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'Profile',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      leading: _buildLeading(context, colorScheme),
      actions: [
        IconButton(
          onPressed: () {
            // Show settings menu
            _showSettingsMenu(context);
          },
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRecipeAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      leading: _buildLeading(context, colorScheme),
      actions: [
        IconButton(
          onPressed: () {
            // Add to favorites functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to favorites')),
            );
          },
          icon: const Icon(Icons.favorite_border),
          tooltip: 'Add to favorites',
        ),
        IconButton(
          onPressed: () {
            // Share recipe functionality
            _shareRecipe(context);
          },
          icon: const Icon(Icons.share_outlined),
          tooltip: 'Share recipe',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMealPlanAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      foregroundColor: foregroundColor ?? colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      leading: _buildLeading(context, colorScheme),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/grocery-list'),
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Grocery List',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMealPlanAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download_outlined),
                  SizedBox(width: 12),
                  Text('Export Plan'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'template',
              child: Row(
                children: [
                  Icon(Icons.save_outlined),
                  SizedBox(width: 12),
                  Text('Save as Template'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all_outlined),
                  SizedBox(width: 12),
                  Text('Clear Plan'),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert),
          tooltip: 'More options',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget? _buildLeading(BuildContext context, ColorScheme colorScheme) {
    if (leading != null) return leading;

    if (showBackButton || Navigator.of(context).canPop()) {
      return IconButton(
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
      );
    }

    return null;
  }

  List<Widget>? _buildActions(BuildContext context, ColorScheme colorScheme) {
    if (actions != null) return actions;

    // Default actions based on current route
    final currentRoute = ModalRoute.of(context)?.settings.name;

    switch (currentRoute) {
      case '/home-dashboard':
        return [
          IconButton(
            onPressed: onSearchTap ??
                () => Navigator.pushNamed(context, '/recipe-browse'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/user-profile'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ];
      case '/recipe-browse':
        return [
          IconButton(
            onPressed: () {
              // Filter functionality
              _showFilterBottomSheet(context);
            },
            icon: const Icon(Icons.tune),
            tooltip: 'Filter',
          ),
          const SizedBox(width: 8),
        ];
      case '/pantry-inventory':
        return [
          IconButton(
            onPressed: () {
              // Add item functionality
              _showAddItemDialog(context);
            },
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
          ),
          const SizedBox(width: 8),
        ];
      default:
        return null;
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _shareRecipe(BuildContext context) {
    // Share functionality would be implemented here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe shared!')),
    );
  }

  void _handleMealPlanAction(BuildContext context, String action) {
    switch (action) {
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal plan exported')),
        );
        break;
      case 'template':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved as template')),
        );
        break;
      case 'clear':
        _showClearPlanDialog(context);
        break;
    }
  }

  void _showClearPlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Meal Plan'),
        content: const Text(
            'Are you sure you want to clear your entire meal plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal plan cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Recipes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.schedule),
              title: Text('Cooking Time'),
            ),
            const ListTile(
              leading: Icon(Icons.restaurant),
              title: Text('Cuisine Type'),
            ),
            const ListTile(
              leading: Icon(Icons.local_dining),
              title: Text('Dietary Restrictions'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Pantry Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g., Tomatoes',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g., 5 pieces',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added to pantry')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
