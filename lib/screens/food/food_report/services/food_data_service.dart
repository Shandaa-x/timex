import 'package:cloud_firestore/cloud_firestore.dart';

class FoodDataService {
  // Helper function to safely parse food name
  static String getFoodName(Map<String, dynamic> food) {
    try {
      final nameField = food['name'];
      if (nameField is String) {
        return nameField;
      } else if (nameField is List && nameField.isNotEmpty) {
        return nameField.first.toString();
      } else if (nameField != null) {
        return nameField.toString();
      }
    } catch (e) {
      print('Error parsing food name: $e, food data: $food');
    }
    return 'Unknown';
  }

  // Helper function to safely parse food price
  static int getFoodPrice(Map<String, dynamic> food) {
    try {
      final priceField = food['price'];
      if (priceField is int) {
        return priceField;
      } else if (priceField is double) {
        return priceField.round();
      } else if (priceField is String) {
        return int.tryParse(priceField) ?? 0;
      } else if (priceField is num) {
        return priceField.round();
      }
    } catch (e) {
      print('Error parsing food price: $e, food data: $food');
    }
    return 0;
  }

  // Helper function to safely parse food comments
  static String getFoodComments(Map<String, dynamic> food) {
    try {
      final commentsField = food['comments'];
      if (commentsField is String) {
        return commentsField;
      } else if (commentsField is List && commentsField.isNotEmpty) {
        return commentsField.first.toString();
      } else if (commentsField != null) {
        return commentsField.toString();
      }
    } catch (e) {
      print('Error parsing food comments: $e, food data: $food');
    }
    return '';
  }

  // Helper function to safely parse food index
  static int getFoodIndex(Map<String, dynamic> food) {
    try {
      final indexField = food['_index'];
      if (indexField is int) {
        return indexField;
      } else if (indexField is double) {
        return indexField.round();
      } else if (indexField is String) {
        return int.tryParse(indexField) ?? 0;
      } else if (indexField is num) {
        return indexField.round();
      }
    } catch (e) {
      print('Error parsing food index: $e, food data: $food');
    }
    return 0;
  }

  // Load food data for a specific month using optimized queries
  static Future<Map<String, List<Map<String, dynamic>>>> loadFoodDataForMonth(
    DateTime selectedMonth,
  ) async {
    final foodData = <String, List<Map<String, dynamic>>>{};
    
    try {
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      // Use range query with better error handling
      final startDocId =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01-foods';
      final endDocId =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}-foods';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get(const GetOptions(source: Source.serverAndCache));

      // Process all documents
      for (final doc in querySnapshot.docs) {
        if (doc.exists) {
          final data = doc.data();
          final dateKey =
              '${data['year']}-${data['month'].toString().padLeft(2, '0')}-${data['day'].toString().padLeft(2, '0')}';

          if (data['foods'] != null && data['foods'] is List) {
            final foods = List<Map<String, dynamic>>.from(data['foods']);
            foodData[dateKey] = foods;
          }
        }
      }
    } catch (e) {
      print('Error loading food data: $e');
      // Return empty data rather than throwing
    }
    
    return foodData;
  }

  // Load eaten for day data using optimized queries
  static Future<Map<String, bool>> loadEatenForDayData(DateTime selectedMonth, String userId) async {
    final eatenData = <String, bool>{};
    
    try {
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      final startDocId =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01';
      final endDocId =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}';

      // Use range query to get all calendar days for the month from user's subcollection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get(const GetOptions(source: Source.serverAndCache));

      // Process the results
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        eatenData[dateKey] = data['eatenForDay'] as bool? ?? false;
      }

      // Fill in missing days with false (not eaten)
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey =
            '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        eatenData[dateKey] ??= false;
      }
    } catch (e) {
      print('Error loading eaten for day data: $e');
      // Fallback to individual queries if needed
      await _loadEatenForDayDataFallback(selectedMonth, eatenData, userId);
    }
    
    return eatenData;
  }

  // Fallback method for eaten for day data
  static Future<void> _loadEatenForDayDataFallback(
    DateTime selectedMonth,
    Map<String, bool> eatenData,
    String userId,
  ) async {
    try {
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      final futures = <Future<void>>[];

      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey =
            '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        futures.add(_loadSingleDayEatenStatus(dateKey, eatenData, userId));
      }

      await Future.wait(futures);
    } catch (e) {
      print('Error in fallback eaten data loading: $e');
    }
  }

  static Future<void> _loadSingleDayEatenStatus(
    String dateKey,
    Map<String, bool> eatenData,
    String userId,
  ) async {
    try {
      final calendarDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .doc(dateKey)
          .get();

      if (calendarDoc.exists) {
        final data = calendarDoc.data()!;
        eatenData[dateKey] = data['eatenForDay'] as bool? ?? false;
      } else {
        eatenData[dateKey] = false;
      }
    } catch (e) {
      print('Error loading eaten status for $dateKey: $e');
      eatenData[dateKey] = false;
    }
  }

  // Calculate food statistics
  static Map<String, int> calculateFoodStats(
    Map<String, List<Map<String, dynamic>>> foodData,
  ) {
    final stats = <String, int>{};
    
    for (final foods in foodData.values) {
      for (final food in foods) {
        final foodName = getFoodName(food);
        stats[foodName] = (stats[foodName] ?? 0) + 1;
      }
    }
    
    return stats;
  }

  // Get available food types for filtering
  static List<String> getAvailableFoodTypes(
    Map<String, List<Map<String, dynamic>>> foodData,
  ) {
    final allFoods = <String>{};

    for (final foods in foodData.values) {
      for (final food in foods) {
        final foodName = getFoodName(food);
        allFoods.add(foodName);
      }
    }

    return allFoods.toList()..sort();
  }
}
