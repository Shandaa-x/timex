import '../services/food_data_service.dart';

class FoodCalculationService {
  // Calculate total foods count (only from days where food was eaten)
  static int calculateTotalFoodsCount(
    Map<String, List<Map<String, dynamic>>> foodData,
    Map<String, bool> eatenForDayData,
  ) {
    int count = 0;
    for (final entry in foodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;
      final wasEaten = eatenForDayData[dateKey] ?? false;

      if (wasEaten) {
        count += foods.length;
      }
    }
    return count;
  }

  // Calculate total spent (only from days where food was eaten)
  static int calculateTotalSpent(
    Map<String, List<Map<String, dynamic>>> foodData,
    Map<String, bool> eatenForDayData,
  ) {
    int total = 0;
    for (final entry in foodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;
      final wasEaten = eatenForDayData[dateKey] ?? false;

      if (wasEaten) {
        for (final food in foods) {
          total += FoodDataService.getFoodPrice(food);
        }
      }
    }
    return total;
  }

  // Calculate average daily spending
  static double calculateAverageDailySpending(
    Map<String, List<Map<String, dynamic>>> foodData,
    Map<String, bool> eatenForDayData,
  ) {
    final daysWithEatenFood = foodData.entries
        .where((entry) => eatenForDayData[entry.key] == true && entry.value.isNotEmpty)
        .length;
    
    final totalSpent = calculateTotalSpent(foodData, eatenForDayData);
    return daysWithEatenFood > 0 ? totalSpent / daysWithEatenFood : 0;
  }

  // Get filtered food data (only from days where food was eaten)
  static Map<String, List<Map<String, dynamic>>> getFilteredFoodData(
    Map<String, List<Map<String, dynamic>>> foodData,
    Map<String, bool> eatenForDayData,
    String? selectedFoodFilter,
  ) {
    final filtered = <String, List<Map<String, dynamic>>>{};

    for (final entry in foodData.entries) {
      final dateKey = entry.key;
      final wasEaten = eatenForDayData[dateKey] ?? false;

      if (wasEaten) {
        List<Map<String, dynamic>> filteredFoods;

        if (selectedFoodFilter == null) {
          filteredFoods = entry.value;
        } else {
          filteredFoods = entry.value.where((food) {
            final foodName = FoodDataService.getFoodName(food);
            return foodName == selectedFoodFilter;
          }).toList();
        }

        if (filteredFoods.isNotEmpty) {
          filtered[dateKey] = filteredFoods;
        }
      }
    }
    return filtered;
  }

  // Get only unpaid meals data for display
  static Map<String, List<Map<String, dynamic>>> getUnpaidFoodData(
    Map<String, List<Map<String, dynamic>>> foodData,
    Map<String, bool> eatenForDayData,
    Map<String, bool> paidMeals,
    String? selectedFoodFilter,
  ) {
    final unpaid = <String, List<Map<String, dynamic>>>{};

    for (final entry in foodData.entries) {
      final dateKey = entry.key;
      final wasEaten = eatenForDayData[dateKey] ?? false;

      if (wasEaten) {
        final unpaidMealsForDay = <Map<String, dynamic>>[];

        for (int i = 0; i < entry.value.length; i++) {
          final food = entry.value[i];
          final mealKey = '${dateKey}_$i';
          final isPaid = paidMeals[mealKey] ?? false;

          final foodName = FoodDataService.getFoodName(food);
          final matchesFilter = selectedFoodFilter == null || foodName == selectedFoodFilter;

          if (!isPaid && matchesFilter) {
            final meal = Map<String, dynamic>.from(food);
            meal['_index'] = i; // Store the index for payment tracking
            unpaidMealsForDay.add(meal);
          }
        }

        if (unpaidMealsForDay.isNotEmpty) {
          unpaid[dateKey] = unpaidMealsForDay;
        }
      }
    }
    return unpaid;
  }

  // Get unpaid meals total amount
  static int calculateUnpaidTotalAmount(
    Map<String, List<Map<String, dynamic>>> unpaidFoodData,
  ) {
    int total = 0;
    for (final entry in unpaidFoodData.entries) {
      final foods = entry.value;
      for (final food in foods) {
        total += FoodDataService.getFoodPrice(food);
      }
    }
    return total;
  }

  // Get paid meals total amount
  static int calculatePaidTotalAmount(
    Map<String, List<Map<String, dynamic>>> filteredFoodData,
    Map<String, bool> paidMeals,
  ) {
    int total = 0;
    for (final entry in filteredFoodData.entries) {
      final dateKey = entry.key;
      final foods = entry.value;

      for (int i = 0; i < foods.length; i++) {
        final mealKey = '${dateKey}_$i';
        final isPaid = paidMeals[mealKey] ?? false;

        if (isPaid) {
          total += FoodDataService.getFoodPrice(foods[i]);
        }
      }
    }
    return total;
  }

  // Get today's spending
  static int calculateTodaySpending(
    Map<String, List<Map<String, dynamic>>> foodData,
  ) {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayFoods = foodData[todayKey] ?? [];
    return todayFoods.fold<int>(0, (total, food) => total + FoodDataService.getFoodPrice(food));
  }
}
