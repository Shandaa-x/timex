import 'package:flutter/material.dart';

class MealSelectionBottomSheet extends StatefulWidget {
  final String selectedDate;
  final String selectedMealType;
  final Function(Map<String, dynamic> recipe) onRecipeSelected;

  const MealSelectionBottomSheet({
    super.key,
    required this.selectedDate,
    required this.selectedMealType,
    required this.onRecipeSelected,
  });

  @override
  State<MealSelectionBottomSheet> createState() =>
      _MealSelectionBottomSheetState();
}

class _MealSelectionBottomSheetState extends State<MealSelectionBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _filteredRecipes = [];

  final List<Map<String, dynamic>> _recentRecipes = [
    {
      "id": 1,
      "name": "Avocado Toast with Poached Egg",
      "image":
          "https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?fm=jpg&q=60&w=3000",
      "cookingTime": 15,
      "calories": 320,
      "difficulty": "Easy",
      "cuisine": "American",
      "dietary": ["Vegetarian"],
      "mealType": "breakfast",
      "rating": 4.8,
      "description":
          "Creamy avocado on toasted sourdough topped with a perfectly poached egg"
    },
    {
      "id": 2,
      "name": "Mediterranean Quinoa Bowl",
      "image":
          "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?fm=jpg&q=60&w=3000",
      "cookingTime": 25,
      "calories": 450,
      "difficulty": "Medium",
      "cuisine": "Mediterranean",
      "dietary": ["Vegan", "Gluten-Free"],
      "mealType": "lunch",
      "rating": 4.6,
      "description":
          "Nutritious quinoa bowl with fresh vegetables, olives, and tahini dressing"
    },
    {
      "id": 3,
      "name": "Grilled Salmon with Asparagus",
      "image":
          "https://images.unsplash.com/photo-1467003909585-2f8a72700288?fm=jpg&q=60&w=3000",
      "cookingTime": 30,
      "calories": 380,
      "difficulty": "Medium",
      "cuisine": "American",
      "dietary": ["Keto", "Low-Carb"],
      "mealType": "dinner",
      "rating": 4.9,
      "description":
          "Perfectly grilled salmon fillet served with roasted asparagus and lemon"
    },
    {
      "id": 4,
      "name": "Greek Yogurt Parfait",
      "image":
          "https://images.unsplash.com/photo-1488477181946-6428a0291777?fm=jpg&q=60&w=3000",
      "cookingTime": 5,
      "calories": 280,
      "difficulty": "Easy",
      "cuisine": "Greek",
      "dietary": ["Vegetarian", "Gluten-Free"],
      "mealType": "breakfast",
      "rating": 4.7,
      "description":
          "Creamy Greek yogurt layered with fresh berries and granola"
    },
    {
      "id": 5,
      "name": "Chicken Caesar Salad",
      "image":
          "https://images.unsplash.com/photo-1546793665-c74683f339c1?fm=jpg&q=60&w=3000",
      "cookingTime": 20,
      "calories": 420,
      "difficulty": "Easy",
      "cuisine": "Italian",
      "dietary": ["Low-Carb"],
      "mealType": "lunch",
      "rating": 4.5,
      "description":
          "Classic Caesar salad with grilled chicken, parmesan, and homemade croutons"
    },
    {
      "id": 6,
      "name": "Beef Stir Fry",
      "image":
          "https://images.unsplash.com/photo-1603133872878-684f208fb84b?fm=jpg&q=60&w=3000",
      "cookingTime": 25,
      "calories": 520,
      "difficulty": "Medium",
      "cuisine": "Asian",
      "dietary": ["Low-Carb"],
      "mealType": "dinner",
      "rating": 4.4,
      "description":
          "Tender beef strips with colorful vegetables in savory stir-fry sauce"
    }
  ];

  final List<String> _dietaryFilters = [
    'All',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Keto',
    'Low-Carb'
  ];

  @override
  void initState() {
    super.initState();
    _filteredRecipes = _recentRecipes;
    _filterRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecipes() {
    setState(() {
      _filteredRecipes = _recentRecipes.where((recipe) {
        final matchesSearch = _searchController.text.isEmpty ||
            (recipe['name'] as String)
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            (recipe['cuisine'] as String)
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        final matchesFilter = _selectedFilter == 'All' ||
            (recipe['dietary'] as List).contains(_selectedFilter);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add ${_getMealTypeLabel(widget.selectedMealType)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.selectedDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.outline.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _filterRecipes(),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.search,
                          color: colorScheme.onSurface.withOpacity(0.6),
                          size: 20,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Dietary filter chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dietaryFilters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _dietaryFilters[index];
                      final isSelected = filter == _selectedFilter;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = filter;
                          });
                          _filterRecipes();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              filter,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Recipe list
          Expanded(
            child: _filteredRecipes.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRecipes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final recipe = _filteredRecipes[index];
                      return _buildRecipeCard(recipe);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () {
        widget.onRecipeSelected(recipe);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Recipe image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                recipe['image'] as String,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // Recipe details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe['name'] as String,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe['description'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe['cookingTime']} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe['calories']} cal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['rating']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            color: colorScheme.onSurface.withOpacity(0.4),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
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
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];

      return '${months[month - 1]} $day, $year';
    }
    return dateKey;
  }
}
