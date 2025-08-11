import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FilterBottomSheetWidget extends StatelessWidget {
  final List<String> availableFoodTypes;
  final String? selectedFoodFilter;
  final Function(String?) onApplyFilter;

  const FilterBottomSheetWidget({
    super.key,
    required this.availableFoodTypes,
    this.selectedFoodFilter,
    required this.onApplyFilter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Хоолоор шүүх',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Харуулах хоолны төрлийг сонгоно уу',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Clear filter option
              _buildFilterOption(
                theme,
                colorScheme,
                'Бүгд',
                null,
                Icons.clear_all,
                () => _applyFilterAndClose(context, null),
              ),
              const SizedBox(height: 8),
              
              // Food type options
              ...(availableFoodTypes.take(10).map((foodType) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFilterOption(
                  theme,
                  colorScheme,
                  foodType,
                  foodType,
                  Icons.restaurant,
                  () => _applyFilterAndClose(context, foodType),
                ),
              ))),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String? filterValue,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isSelected = selectedFoodFilter == filterValue;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight.withOpacity(0.1) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryLight : colorScheme.outline.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : colorScheme.onSurface.withOpacity(0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryLight : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryLight,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _applyFilterAndClose(BuildContext context, String? filterValue) {
    onApplyFilter(filterValue);
    Navigator.of(context).pop(); // Close bottom sheet
  }
}
