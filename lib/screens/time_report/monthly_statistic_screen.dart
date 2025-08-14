import 'package:flutter/material.dart';
import 'package:timex/screens/home/widgets/custom_sliver_appbar.dart';
import 'package:timex/screens/time_report/day_info/day_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/widgets/custom_drawer.dart';
import 'stat_widgets/index.dart';
import 'functions/index.dart';

class MonthlyStatisticsScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const MonthlyStatisticsScreen({super.key, this.onNavigateToTab});

  @override
  State<MonthlyStatisticsScreen> createState() =>
      _MonthlyStatisticsScreenState();
}

class _MonthlyStatisticsScreenState extends State<MonthlyStatisticsScreen> {
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedDay;

  List<Map<String, dynamic>> _monthData = [];
  Map<String, dynamic>? _selectedDayData;
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

  // Filter variables
  DateTimeRange? _filterRange;
  bool _filterActive = false;
  double _filteredTotalHours = 0.0;
  List<Map<String, dynamic>> _filteredDays = [];

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

  // Show calendar dialog
  Future<void> _showCalendarDialog() async {
    final selectedDate = await CalendarService.showCalendarDialog(
      context,
      _selectedMonth,
      _selectedYear,
      _selectedDay,
    );

    if (selectedDate != null) {
      setState(() {
        _selectedDay = selectedDate.day;
      });
      await _loadSelectedDayData();
    }
  }

  // Clear day selection
  void _clearDaySelection() {
    setState(() {
      _selectedDay = null;
      _selectedDayData = null;
    });
  }

  // Load single day data
  Future<void> _loadSelectedDayData() async {
    if (_selectedDay == null) {
      setState(() {
        _selectedDayData = null;
      });
      return;
    }

    final dayData = await DataService.loadSelectedDayData(
      _userId,
      _selectedDay!,
      _selectedMonth,
      _selectedYear,
    );

    setState(() {
      _selectedDayData = dayData;
    });
  }

  // Load monthly data
  Future<void> _loadMonthlyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await DataService.loadMonthlyData(
        _userId,
        _selectedMonth,
        _selectedYear,
      );

      final processedDays = result['days'] as List<Map<String, dynamic>>;
      final totalWorkedHours = result['totalHours'] as double;

      setState(() {
        _monthData = processedDays;
        _totalHours = totalWorkedHours;
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
      final eatenData = await DataService.loadEatenFoodData(
        _userId,
        _selectedMonth,
        _selectedYear,
      );

      setState(() {
        _eatenForDayData = eatenData;
      });
    } catch (e) {
      debugPrint('Error loading eaten food data: $e');
    }
  }

  Future<void> _confirmDay(String dateString) async {
    // Find the day data
    final dayData = _monthData.firstWhere((day) => day['date'] == dateString);
    final selectedImages = _selectedImages[dateString];

    // Add to confirming set to show loading
    setState(() {
      _confirmingDays.add(dateString);
    });

    try {
      await ImageService.confirmDay(
        _userId,
        dateString,
        dayData,
        selectedImages,
      );

      // Update local data immediately (only update _monthData, not both _monthData and _monthlyData['days'])
      setState(() {
        final dayIndex = _monthData.indexWhere(
          (day) => day['date'] == dateString,
        );
        if (dayIndex != -1) {
          _monthData[dayIndex]['confirmed'] = true;
          if ((selectedImages ?? []).isNotEmpty) {
            // Only set the images once, not in both lists
            List<String> existingImages = List<String>.from(
              _monthData[dayIndex]['attachmentImages'] ?? [],
            );
            // Avoid duplicate images
            for (final img in selectedImages!) {
              if (!existingImages.contains(img)) {
                existingImages.add(img);
              }
            }
            _monthData[dayIndex]['attachmentImages'] = existingImages;
          }
        }

        // Update total hours if this day is now confirmed
        if (!dayData['isHoliday'] &&
            dayData['workingHours'] > 0 &&
            !(dayData['confirmed'] ?? false)) {
          _totalHours += dayData['workingHours'];
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.contains('You have to upload image first')) {
        errorMessage = 'You have to upload image first';
      } else {
        errorMessage = 'Алдаа гарлаа: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      final images = await ImageService.pickMultipleImages();

      if (images != null && images.isNotEmpty) {
        setState(() {
          if (_selectedImages[dateString] == null) {
            _selectedImages[dateString] = [];
          }
          _selectedImages[dateString]!.addAll(images);
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

  // Show date range filter dialog
  Future<void> _showFilterDialog() async {
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filterRange,
      helpText: 'Хугацааны интервал сонгох',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(
                0xFF3B82F6,
              ), // Blue accent matching the monthly statistics
              onPrimary: Colors.white,
              secondary: Color(0xFF3B82F6),
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
              surfaceVariant: Color(0xFFF8FAFC), // Light background
              onSurfaceVariant: Color(0xFF64748B),
              outline: Color(0xFFE2E8F0),
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineMedium: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              bodyLarge: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF3B82F6).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              elevation: 8,
              shadowColor: Color(0x1A000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _filterRange = picked;
        _filterActive = true;
      });
      _applyDateRangeFilter();
    }
  }

  void _clearFilter() {
    setState(() {
      _filterRange = null;
      _filterActive = false;
      _filteredTotalHours = 0.0;
      _filteredDays = [];
    });
  }

  void _applyDateRangeFilter() {
    if (_filterRange == null || _monthData.isEmpty) return;
    final filtered = _monthData.where((day) {
      final date = DateTime.tryParse(day['date'] ?? '') ?? DateTime(2000);
      return !date.isBefore(_filterRange!.start) &&
          !date.isAfter(_filterRange!.end);
    }).toList();
    final total = filtered.fold<double>(
      0.0,
      (sum, day) => sum + (day['workingHours'] ?? 0.0),
    );
    setState(() {
      _filteredDays = filtered;
      _filteredTotalHours = total;
    });
  }

  String formatMongolianHours(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();
    if (h > 0 && m > 0) return '$h цаг, $m минут';
    if (h > 0) return '$h цаг';
    return '$h цаг, $m минут';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    // Helper: get data for cards based on filter
    final bool isFilterActive = _filterActive && _filterRange != null;
    final List<Map<String, dynamic>> daysForCards = isFilterActive
        ? _filteredDays
        : _monthData;
    final double totalHoursForCard = isFilterActive
        ? _filteredTotalHours
        : _totalHours;

    // For monthly statistics chart, use filtered days if filter is active
    final List<Map<String, dynamic>> chartDays = isFilterActive
        ? _filteredDays
        : _monthData;
    final chartData = ChartCalculator.calculateChartData(chartDays, null);
    // For chart labels: use filter's start month/year if filtering, else selected month/year
    final int chartMonth = isFilterActive
        ? _filterRange!.start.month
        : _selectedMonth;
    final int chartYear = isFilterActive
        ? _filterRange!.start.year
        : _selectedYear;

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
        drawer: CustomDrawer(
          currentScreen: DrawerScreenType.timeReport,
          onNavigateToTab: widget.onNavigateToTab,
        ),
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            CustomSliverAppBar(
              title: "Цагийн тайлан",
              gradientColors: [
                Colors.blueAccent,
                Colors.blueAccent,
              ], // Gradient
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3B82F6),
                                  ),
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
                        DateSelectionCard(
                          selectedMonth: _selectedMonth,
                          selectedDay: _selectedDay,
                          selectedYear: _selectedYear,
                          monthNames: _monthNames,
                          onShowCalendarDialog: _showCalendarDialog,
                          onClearDaySelection: _clearDaySelection,
                          onMonthChanged: (value) {
                            setState(() {
                              _selectedMonth = value;
                              _selectedDay = null;
                              _expandedDays.clear();
                              _selectedImages.clear();
                              _selectedDayData = null;
                              // Clear filter when month changes
                              _filterRange = null;
                              _filterActive = false;
                              _filteredTotalHours = 0.0;
                              _filteredDays = [];
                            });
                            _loadMonthlyData();
                          },
                          onYearChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                              _selectedDay = null;
                              _expandedDays.clear();
                              _selectedImages.clear();
                              _selectedDayData = null;
                              // Clear filter when year changes
                              _filterRange = null;
                              _filterActive = false;
                              _filteredTotalHours = 0.0;
                              _filteredDays = [];
                            });
                            _loadMonthlyData();
                          },
                          filterRange: _filterRange,
                          onDateRangeSelected: _showFilterDialog,
                          onClearFilter: _clearFilter,
                        ),
                        const SizedBox(height: 15),
                        // Show single day statistics if a day is selected
                        if (_selectedDay != null) ...[
                          if (_selectedDayData != null) ...[
                            DayStatisticsCard(
                              selectedDay: _selectedDay!,
                              selectedDayData: _selectedDayData!,
                            ),
                          ] else ...[
                            // Show message when no data is available for selected day
                            NoDataCard(
                              selectedDay: _selectedDay!,
                              selectedMonth: _selectedMonth,
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],

                        // Show monthly/weekly content only when no specific day is selected
                        if (_selectedDay == null) ...[
                          // Total Hours Display
                          TotalHoursCard(
                            totalHours: totalHoursForCard,
                            selectedMonth: _selectedMonth,
                            selectedYear: _selectedYear,
                            monthNames: _monthNames,
                            isTablet: isTablet,
                          ),

                          const SizedBox(height: 20),

                          // Monthly Statistics (show for current month or filter)
                          MonthlyStatisticsCard(
                            monthlyHours: chartDays.fold<double>(
                              0.0,
                              (sum, day) => sum + (day['workingHours'] ?? 0.0),
                            ),
                            monthNames: _monthNames,
                            selectedMonth: chartMonth,
                            selectedYear: chartYear,
                            chartData: chartData.monthlyChartData,
                          ),
                          const SizedBox(height: 20),
                          // Days List
                          DaysListCard(
                            weeklyData: daysForCards,
                            selectedMonth: _selectedMonth,
                            confirmingDays: _confirmingDays,
                            expandedDays: _expandedDays,
                            selectedImages: _selectedImages,
                            isTablet: isTablet,
                            eatenForDayData: _eatenForDayData,
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
                                if (_selectedImages[dateString]?.isEmpty ==
                                    true) {
                                  _selectedImages.remove(dateString);
                                }
                              });
                            },
                            onImageTap: (dateString, dayData) {
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
                        ],
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
