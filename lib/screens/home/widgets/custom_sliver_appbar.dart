import 'package:flutter/material.dart';
import 'package:timex/index.dart';

class CustomSliverAppBar extends StatelessWidget {
  final IconData? leftIcon;
  final VoidCallback? onLeftTap;
  final IconData? rightIcon;
  final VoidCallback? onRightTap;
  final String? subtitle;
  final String? title;
  final List<Color>? gradientColors; // Gradient эсвэл null бол нэг өнгө
  final Color? solidColor;

  const CustomSliverAppBar({
    super.key,
    this.leftIcon,
    this.onLeftTap,
    this.rightIcon,
    this.onRightTap,
    this.subtitle,
    this.title,
    this.gradientColors,
    this.solidColor,
  });

  @override
  Widget build(BuildContext context) {
    // Get the primary color for collapsed state
    final Color collapsedColor = gradientColors != null 
        ? gradientColors!.first 
        : (solidColor ?? const Color(0xFF2D5A27));
    
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: collapsedColor,
      foregroundColor: Colors.white, // Ensure text/icons stay white
      // Only show title when collapsed (scrolled)
      title: title != null ? txt(
        title!,
        style: TxtStl.bodyText1(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      ) : null,
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        // Don't show title in FlexibleSpaceBar to avoid duplication
        title: null,
        background: Container(
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
                    colors: gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: gradientColors == null ? solidColor ?? const Color(0xFF2D5A27) : null,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left icon button
                  if (leftIcon != null)
                    _circleButton(icon: leftIcon!, onTap: onLeftTap)
                  else
                    const SizedBox(width: 50, height: 50),

                  // Text section
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (subtitle != null)
                          txt(
                            subtitle!,
                            style: TxtStl.bodyText1(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Right icon button
                  if (rightIcon != null)
                    _circleButton(icon: rightIcon!, onTap: onRightTap)
                  else
                    const SizedBox(width: 44, height: 44),
                ],
              ),
            ),
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
