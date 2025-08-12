import 'package:flutter/material.dart';

class ModernDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final IconData? icon;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const ModernDropdown({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    required this.items,
    required this.onChanged,
  });

    @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF64748B), size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
      ),
    );
  }
}