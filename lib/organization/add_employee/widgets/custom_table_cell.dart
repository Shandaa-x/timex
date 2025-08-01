// lib/widgets/custom_table_cell.dart

import 'package:flutter/material.dart';

/// A reusable widget for displaying content within a table cell.
///
/// It supports displaying either a simple [text] or a custom [child] widget.
/// The [flex] property defines its proportion within a [Row].
class CustomTableCell extends StatelessWidget {
  final String? text;
  final Widget? child;
  final int flex;
  final TextStyle? textStyle;
  final Alignment alignment;

  const CustomTableCell({
    super.key,
    this.text,
    this.child,
    required this.flex,
    this.textStyle,
    this.alignment = Alignment.centerLeft,
  }) : assert(text != null || child != null); // Ensure either text or child is provided

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child ??
            Text(
              text ?? '', // Fallback for text if null
              style: textStyle ?? const TextStyle(color: Colors.white), // Default text style
              overflow: TextOverflow.ellipsis,
            ),
      ),
    );
  }
}