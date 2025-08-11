import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timex/screens/time_report/day_info/day_info_screen.dart';
import 'package:timex/screens/time_report/stat_widgets/chart_calculator.dart';
import 'package:timex/screens/time_report/stat_widgets/day_list_card.dart';
import 'package:timex/screens/time_report/stat_widgets/modern_card.dart';
import 'package:timex/screens/time_report/stat_widgets/modern_dropdown.dart';
import 'package:timex/screens/time_report/stat_widgets/monthly_statistics_card.dart';
import 'package:timex/screens/time_report/stat_widgets/total_hours_card.dart';
import 'package:timex/screens/time_report/stat_widgets/weekly_selector_card.dart';
import 'package:timex/screens/time_report/stat_widgets/weekly_statistics_card.dart';

class MonthlyStatisticsScreen extends StatefulWidget {
  const MonthlyStatisticsScreen({super.key});

  @override
  State<MonthlyStatisticsScreen> createState() => _MonthlyStatisticsScreenState();
}

class _MonthlyStatisticsScreenState extends State<MonthlyStatisticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedWeekNumber;

  Map<String, dynamic> _monthlyData = {};
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = true;
  double _totalHours = 0.0;

  // Track which days are being confirmed
  Set<String> _confirmingDays = {};

  // Track expanded day items
  Set<String> _expandedDays = {};

  // Track selected images for each day
  Map<String, List<String>> _selectedImages = {};

  // Track which days food was eaten
  Map<String, bool> _eatenForDayData = {};

  // Chart data
  double _monthlyHours = 0.0;
  double _weeklyHours = 0.0;
  List<Map<String, dynamic>> _monthlyChartData = [];
  List<Map<String, dynamic>> _weeklyChartData = [];

  final List<String> _monthNames = [
    '1-сар',
    '2-сар',
    '3-сар',
    '4-сар',
    '5-сар',
    '6-сар',
    '7-сар',
    '8-сар',
    '9-сар',
    '10-сар',
    '11-сар',
    '12-сар',
  ];

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  // Helper method to get current week number (ISO 8601 week numbering)
  // This matches the exact implementation used in calendar_uploader.dart
  int _getCurrentWeekNumber() {
    final date = DateTime.now();
    
    // ISO 8601 week numbering:
    // - Week starts on Monday (weekday 1)
    // - Week 1 is the first week with at least 4 days in the new year
    // - Week 1 contains January 4th

    // Find January 4th of the same year
    final DateTime jan4 = DateTime(date.year, 1, 4);

    // Find the Monday of the week containing January 4th
    final DateTime firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));

    // Calculate days since first Monday
    final int daysSinceFirstMonday = date.difference(firstMonday).inDays;

    // Calculate week number
    final int weekNumber = (daysSinceFirstMonday / 7).floor() + 1;

    // Handle edge cases for beginning and end of year
    if (weekNumber < 1) {
      // This date belongs to the last week of the previous year
      return _getCurrentWeekNumber(); // Should use previous year calc, but for now return 1
    } else if (weekNumber > 52) {
      // Check if this should be week 1 of next year
      final DateTime nextJan4 = DateTime(date.year + 1, 1, 4);
      final DateTime nextFirstMonday = nextJan4.subtract(Duration(days: nextJan4.weekday - 1));

      if (date.isAfter(nextFirstMonday) || date.isAtSameMomentAs(nextFirstMonday)) {
        return 1; // This is week 1 of next year
      } else {
        return weekNumber; // This is week 53 of current year (rare)
      }
    }

    return weekNumber;
  }

  Future<void> _loadMonthlyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('calendarDays')
          .where('month', isEqualTo: _selectedMonth)
          .where('year', isEqualTo: _selectedYear)
          .get();

      print('Found ${querySnapshot.docs.length} documents for month $_selectedMonth');

      final List<Map<String, dynamic>> processedDays = [];
      double totalWorkedHours = 0.0;
      Set<int> weekNumbers = {};

      for (final doc in querySnapshot.docs) {
        final calendarDay = doc.data();
        final dateString = doc.id;

        print('Processing day: $dateString, data: $calendarDay');

        // Check if there are time entries for this day to determine if work was actually done
        final timeEntriesSnapshot = await _firestore
            .collection('calendarDays')
            .doc(dateString)
            .collection('timeEntries')
            .get();

        // Check if there's at least one check-out entry (indicating work was completed)
        bool hasWorkEnded = false;
        if (timeEntriesSnapshot.docs.isNotEmpty) {
          final entries = timeEntriesSnapshot.docs.map((doc) => doc.data()).toList();
          entries.sort((a, b) {
            final timestampA = (a['timestamp'] as Timestamp).toDate();
            final timestampB = (b['timestamp'] as Timestamp).toDate();
            return timestampA.compareTo(timestampB);
          });
          
          // Check if the last entry is a check-out type
          if (entries.isNotEmpty) {
            final lastEntry = entries.last;
            hasWorkEnded = lastEntry['type'] == 'check_out' || lastEntry['type'] == 'auto_check_out';
          }
        }

        final Map<String, dynamic> dayData = {
          'date': dateString,
          'day': calendarDay['day'],
          'weekNumber': calendarDay['weekNumber'],
          'workingHours': calendarDay['workingHours']?.toDouble() ?? 0.0,
          'confirmed': calendarDay['confirmed'] ?? false,
          'isHoliday': calendarDay['isHoliday'] ?? false,
          'attachmentImages': calendarDay['attachmentImages'] ?? [],
          'hasWorkEnded': hasWorkEnded, // New field to indicate if work was completed
        };

        // Only count confirmed days that are not holidays and have working hours
        if (dayData['confirmed'] && !dayData['isHoliday'] && dayData['workingHours'] > 0) {
          totalWorkedHours += dayData['workingHours'];
        }

        if (calendarDay['weekNumber'] != null) {
          weekNumbers.add(calendarDay['weekNumber']);
        }
        processedDays.add(dayData);
      }

      processedDays.sort((a, b) => a['date'].compareTo(b['date']));

      List<Map<String, dynamic>> filteredData = processedDays;
      if (_selectedWeekNumber != null) {
        filteredData = processedDays
            .where((day) => day['weekNumber'] == _selectedWeekNumber)
            .toList();
      }

      // Calculate chart data
      final chartData = ChartCalculator.calculateChartData(processedDays, _selectedWeekNumber);
      _monthlyChartData = chartData.monthlyChartData;
      _weeklyChartData = chartData.weeklyChartData;
      _weeklyHours = chartData.weeklyHours;

      print('Processed ${processedDays.length} days, filtered to ${filteredData.length}');

      // Auto-select current week if we're viewing current month/year and haven't manually selected a week
      int? autoSelectedWeek = _selectedWeekNumber;
      if (_selectedMonth == DateTime.now().month && 
          _selectedYear == DateTime.now().year && 
          _selectedWeekNumber == null) {
        final currentWeek = _getCurrentWeekNumber();
        print('Current date: ${DateTime.now()}');
        print('Calculated current week: $currentWeek');
        print('Available weeks in month: ${weekNumbers.toList()..sort()}');
        
        if (weekNumbers.contains(currentWeek)) {
          print('Auto-selecting current week: $currentWeek');
          autoSelectedWeek = currentWeek;
          filteredData = processedDays
              .where((day) => day['weekNumber'] == currentWeek)
              .toList();
          
          // Recalculate chart data for the auto-selected week
          final chartData = ChartCalculator.calculateChartData(processedDays, autoSelectedWeek);
          _monthlyChartData = chartData.monthlyChartData;
          _weeklyChartData = chartData.weeklyChartData;
          _weeklyHours = chartData.weeklyHours;
        } else {
          print('Current week $currentWeek not found in available weeks');
        }
      }

      setState(() {
        _monthlyData = {'days': processedDays, 'weekNumbers': weekNumbers.toList()..sort()};
        _weeklyData = filteredData;
        _totalHours = totalWorkedHours;
        _monthlyHours = totalWorkedHours;
        _selectedWeekNumber = autoSelectedWeek; // Set the auto-selected week
        _isLoading = false;
      });

      // Load eaten food data for the month
      await _loadEatenFoodData();
    } catch (e) {
      debugPrint('Error loading monthly data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load eaten food data for the selected month
  Future<void> _loadEatenFoodData() async {
    try {
      _eatenForDayData.clear();
      
      final endOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
      final startDocId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
      final endDocId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}';

      // Use range query to get all calendar days for the month
      final querySnapshot = await FirebaseFirestore.instance
          .collection('calendarDays')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDocId)
          .get();

      // Process the results
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        _eatenForDayData[dateKey] = data['eatenForDay'] as bool? ?? false;
      }

      // Fill in missing days with false (not eaten)
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dateKey = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        _eatenForDayData[dateKey] ??= false;
      }
    } catch (e) {
      print('Error loading eaten food data: $e');
    }
  }

  Future<void> _confirmDay(String dateString) async {
    // Find the day data
    final dayData = _weeklyData.firstWhere((day) => day['date'] == dateString);
    final hasExistingImages = (dayData['attachmentImages'] as List).isNotEmpty;
    final hasSelectedImages = (_selectedImages[dateString] ?? []).isNotEmpty;

    // Check if day is not confirmed and has no images
    if (!dayData['confirmed'] && !hasExistingImages && !hasSelectedImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have to upload image first'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
      return;
    }

    // Add to confirming set to show loading
    setState(() {
      _confirmingDays.add(dateString);
    });

    try {
      Map<String, dynamic> updateData = {'confirmed': true};

      // If there are selected images, upload them
      if ((_selectedImages[dateString] ?? []).isNotEmpty) {
        // Get existing attachment images
        List<String> existingImages = List<String>.from(dayData['attachmentImages'] ?? []);
        // Add selected images to existing ones
        existingImages.addAll(_selectedImages[dateString]!);
        // Update with the complete list instead of using arrayUnion to avoid duplication
        updateData['attachmentImages'] = existingImages;
      }

      await _firestore.collection('calendarDays').doc(dateString).update(updateData);

      // Update local data immediately
      setState(() {
        // Update the day data in weekly data
        final dayIndex = _weeklyData.indexWhere((day) => day['date'] == dateString);
        if (dayIndex != -1) {
          _weeklyData[dayIndex]['confirmed'] = true;
          // Move selected images to attachment images
          if ((_selectedImages[dateString] ?? []).isNotEmpty) {
            List<String> existingImages = List<String>.from(
              _weeklyData[dayIndex]['attachmentImages'] ?? [],
            );
            existingImages.addAll(_selectedImages[dateString]!);
            _weeklyData[dayIndex]['attachmentImages'] = existingImages;
          }
        }

        // Update monthly data
        final monthlyDays = _monthlyData['days'] as List<Map<String, dynamic>>?;
        if (monthlyDays != null) {
          for (var day in monthlyDays) {
            if (day['date'] == dateString) {
              day['confirmed'] = true;
              if ((_selectedImages[dateString] ?? []).isNotEmpty) {
                List<String> existingImages = List<String>.from(day['attachmentImages'] ?? []);
                existingImages.addAll(_selectedImages[dateString]!);
                day['attachmentImages'] = existingImages;
              }

              // Update total hours if this day is now confirmed
              if (!dayData['isHoliday'] && dayData['workingHours'] > 0) {
                _totalHours += dayData['workingHours'];
                _monthlyHours += dayData['workingHours'];
              }
              break;
            }
          }
          // Recalculate chart data
          final chartData = ChartCalculator.calculateChartData(monthlyDays, _selectedWeekNumber);
          _monthlyChartData = chartData.monthlyChartData;
          _weeklyChartData = chartData.weeklyChartData;
          _weeklyHours = chartData.weeklyHours;
        }

        // Clear selected images for this day AFTER updating the data
        _selectedImages.remove(dateString);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$dateString-ны цагийг баталгаажууллаа'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      // Remove from confirming set
      if (mounted) {
        setState(() {
          _confirmingDays.remove(dateString);
        });
      }
    }
  }

  Future<void> _pickMultipleImages(String dateString) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick multiple images at once using pickMultiImage
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        List<String> base64Images = [];
        
        for (XFile image in images) {
          File imageFile = File(image.path);
          List<int> imageBytes = await imageFile.readAsBytes();
          String base64Image = base64Encode(imageBytes);
          base64Images.add(base64Image);
        }

        setState(() {
          if (_selectedImages[dateString] == null) {
            _selectedImages[dateString] = [];
          }
          _selectedImages[dateString]!.addAll(base64Images);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) selected'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting images: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          // Handle back navigation if needed
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 70,
              floating: false,
              pinned: true,
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Тайлан',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
                ),
                background: Container(decoration: const BoxDecoration(color: Colors.blueAccent)),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),

            // Content
            SliverPadding(
              padding: EdgeInsets.all(isTablet ? 24.0 : 12.0),
              sliver: _isLoading
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Мэдээлэл ачаалж байна...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        // Date Selection Section
                        ModernCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Хугацаа сонгох',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ModernDropdown<int>(
                                      value: _selectedMonth,
                                      label: 'Сар',
                                      icon: Icons.event,
                                      items: List.generate(12, (index) {
                                        return DropdownMenuItem(
                                          value: index + 1,
                                          child: Text(_monthNames[index]),
                                        );
                                      }),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMonth = value!;
                                          _selectedWeekNumber = null; // Reset week selection
                                          _expandedDays.clear();
                                          _selectedImages.clear();
                                        });
                                        _loadMonthlyData(); // This will auto-select current week if applicable
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 130,
                                    child: ModernDropdown<int>(
                                      value: _selectedYear,
                                      label: 'Жил',
                                      icon: Icons.date_range,
                                      items: [2024, 2025, 2026].map((year) {
                                        return DropdownMenuItem(
                                          value: year,
                                          child: Text(year.toString()),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedYear = value!;
                                          _selectedWeekNumber = null; // Reset week selection
                                          _expandedDays.clear();
                                          _selectedImages.clear();
                                        });
                                        _loadMonthlyData(); // This will auto-select current week if applicable
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Total Hours Display
                        TotalHoursCard(
                          totalHours: _totalHours,
                          selectedMonth: _selectedMonth,
                          selectedYear: _selectedYear,
                          monthNames: _monthNames,
                          isTablet: isTablet,
                        ),

                        const SizedBox(height: 20),

                        // Monthly Statistics
                        MonthlyStatisticsCard(
                          monthlyHours: _monthlyHours,
                          monthNames: _monthNames,
                          selectedMonth: _selectedMonth,
                          selectedYear: _selectedYear,
                          chartData: _monthlyChartData,
                        ),

                        const SizedBox(height: 20),

                        // Week Selector
                        if (_monthlyData['weekNumbers'] != null &&
                            _monthlyData['weekNumbers'].isNotEmpty)
                          WeekSelectorCard(
                            weekNumbers: _monthlyData['weekNumbers'],
                            selectedWeekNumber: _selectedWeekNumber,
                            onWeekSelected: (weekNum) {
                              setState(() {
                                _selectedWeekNumber = weekNum;
                                _weeklyData = weekNum == null
                                    ? List<Map<String, dynamic>>.from(_monthlyData['days'] ?? [])
                                    : List<Map<String, dynamic>>.from(
                                        _monthlyData['days'] ?? [],
                                      ).where((day) => day['weekNumber'] == weekNum).toList();

                                final chartData = ChartCalculator.calculateChartData(
                                  _monthlyData['days'] ?? [],
                                  _selectedWeekNumber,
                                );
                                _monthlyChartData = chartData.monthlyChartData;
                                _weeklyChartData = chartData.weeklyChartData;
                                _weeklyHours = chartData.weeklyHours;
                              });
                            },
                          ),

                        if (_monthlyData['weekNumbers'] != null &&
                            _monthlyData['weekNumbers'].isNotEmpty)
                          const SizedBox(height: 20),

                        // Weekly Statistics
                        if (_selectedWeekNumber != null)
                          WeeklyStatisticsCard(
                            weeklyHours: _weeklyHours,
                            selectedWeekNumber: _selectedWeekNumber!,
                            chartData: _weeklyChartData,
                            selectedMonth: _selectedMonth,
                            selectedYear: _selectedYear,
                          ),

                        if (_selectedWeekNumber != null) const SizedBox(height: 20),

                        // Days List
                        DaysListCard(
                          weeklyData: _weeklyData,
                          selectedMonth: _selectedMonth,
                          confirmingDays: _confirmingDays,
                          expandedDays: _expandedDays,
                          selectedImages: _selectedImages,
                          isTablet: isTablet,
                          eatenForDayData: _eatenForDayData, // Add the eaten food data
                          onConfirmDay: _confirmDay,
                          onToggleExpand: (dateString) {
                            setState(() {
                              if (_expandedDays.contains(dateString)) {
                                _expandedDays.remove(dateString);
                              } else {
                                _expandedDays.add(dateString);
                              }
                            });
                          },
                          onPickImage: _pickMultipleImages,
                          onRemoveSelectedImage: (dateString, index) {
                            setState(() {
                              _selectedImages[dateString]?.removeAt(index);
                              if (_selectedImages[dateString]?.isEmpty == true) {
                                _selectedImages.remove(dateString);
                              }
                            });
                          },
                          onImageTap: (dateString, dayData) {
                            // Navigate to day info screen
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DayInfoScreen(
                                  dateString: dateString,
                                  dayData: dayData,
                                  hasFoodEaten: _eatenForDayData[dateString],
                                ),
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
