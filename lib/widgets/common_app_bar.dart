import 'package:flutter/material.dart';

enum AppBarVariant {
  standard,
  sliver,
  gradient,
  dynamic, // For time tracking with changing colors
}

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final AppBarVariant variant;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Gradient? gradient;
  final bool isWorking; // For dynamic variant
  final double expandedHeight; // For sliver variant

  const CommonAppBar({
    super.key,
    required this.title,
    this.variant = AppBarVariant.standard,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
    this.showBackButton = false,
    this.onBackPressed,
    this.gradient,
    this.isWorking = false,
    this.expandedHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (variant) {
      case AppBarVariant.sliver:
        return _buildSliverAppBar(context, theme, colorScheme);
      case AppBarVariant.gradient:
        return _buildGradientAppBar(context, theme, colorScheme);
      case AppBarVariant.dynamic:
        return _buildDynamicAppBar(context, theme, colorScheme);
      case AppBarVariant.standard:
        return _buildStandardAppBar(context, theme, colorScheme);
    }
  }

  Widget _buildStandardAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 20,
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
      automaticallyImplyLeading: showBackButton,
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final bgColor = backgroundColor ?? const Color(0xFF3B82F6);
    final fgColor = foregroundColor ?? Colors.white;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: elevation ?? 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: fgColor,
            letterSpacing: -0.3,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            color: bgColor,
            gradient: gradient,
          ),
        ),
      ),
      leading: _buildLeading(context, colorScheme, customColor: fgColor),
      actions: _buildActions(context, colorScheme, customColor: fgColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildGradientAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
    );

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: foregroundColor ?? Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation ?? 0,
      backgroundColor: Colors.transparent,
      foregroundColor: foregroundColor ?? Colors.white,
      leading: _buildLeading(context, colorScheme, customColor: foregroundColor ?? Colors.white),
      actions: _buildActions(context, colorScheme, customColor: foregroundColor ?? Colors.white),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: gradient ?? defaultGradient,
        ),
      ),
      automaticallyImplyLeading: showBackButton,
    );
  }

  Widget _buildDynamicAppBar(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final bgColor = isWorking ? const Color(0xFF059669) : const Color(0xFF3B82F6);
    final gradientColors = isWorking
        ? [const Color(0xFF059669), const Color(0xFF047857)]
        : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: bgColor,
      elevation: elevation ?? 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
        ),
      ),
      leading: _buildLeading(context, colorScheme, customColor: Colors.white),
      actions: _buildActions(context, colorScheme, customColor: Colors.white),
    );
  }

  Widget? _buildLeading(BuildContext context, ColorScheme colorScheme, {Color? customColor}) {
    if (leading != null) return leading;
    
    if (showBackButton || Navigator.of(context).canPop()) {
      return IconButton(
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back,
          color: customColor ?? colorScheme.onSurface,
        ),
      );
    }
    
    return null;
  }

  List<Widget>? _buildActions(BuildContext context, ColorScheme colorScheme, {Color? customColor}) {
    if (actions == null) return null;
    
    return actions!.map((action) {
      if (action is IconButton) {
        return IconButton(
          onPressed: action.onPressed,
          icon: Icon(
            (action.icon as Icon).icon,
            color: customColor ?? colorScheme.onSurface,
          ),
          tooltip: action.tooltip,
        );
      }
      return action;
    }).toList();
  }

  @override
  Size get preferredSize => Size.fromHeight(
    variant == AppBarVariant.sliver || variant == AppBarVariant.dynamic 
      ? expandedHeight 
      : kToolbarHeight
  );
}
