import 'package:flutter/material.dart';
import 'package:timex/screens/time_report/day_info/day_info_screen.dart';
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
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _selectedDay;
  int? _selectedWeekNumber;

  Map<String, dynamic> _monthlyData = {};
  List<Map<String, dynamic>> _weeklyData = [];
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
        _selectedMonth,
        _selectedYear,
      );

      final processedDays = result['days'] as List<Map<String, dynamic>>;
      final weekNumbers = result['weekNumbers'] as List<int>;
      final totalWorkedHours = result['totalHours'] as double;

      List<Map<String, dynamic>> filteredData = processedDays;
      if (_selectedWeekNumber != null) {
        filteredData = processedDays
            .where((day) => day['weekNumber'] == _selectedWeekNumber)
            .toList();
      }

      // Calculate chart data
      final chartData = ChartCalculator.calculateChartData(
        processedDays,
        _selectedWeekNumber,
      );
      _monthlyChartData = chartData.monthlyChartData;
      _weeklyChartData = chartData.weeklyChartData;
      _weeklyHours = chartData.weeklyHours;

      // Auto-select current week if we're viewing current month/year and haven't manually selected a week
      int? autoSelectedWeek = _selectedWeekNumber;
      if (_selectedMonth == DateTime.now().month &&
          _selectedYear == DateTime.now().year &&
          _selectedWeekNumber == null) {
        final currentWeek = DataService.getCurrentWeekNumber();

        if (weekNumbers.contains(currentWeek)) {
          autoSelectedWeek = currentWeek;
          filteredData = processedDays
              .where((day) => day['weekNumber'] == currentWeek)
              .toList();

          // Recalculate chart data for the auto-selected week
          final chartData = ChartCalculator.calculateChartData(
            processedDays,
            autoSelectedWeek,
          );
          _monthlyChartData = chartData.monthlyChartData;
          _weeklyChartData = chartData.weeklyChartData;
          _weeklyHours = chartData.weeklyHours;
        }
      }

      setState(() {
        _monthlyData = {
          'days': processedDays,
          'weekNumbers': weekNumbers,
        };
        _weeklyData = filteredData;
        _totalHours = totalWorkedHours;
        _monthlyHours = totalWorkedHours;
        _selectedWeekNumber = autoSelectedWeek;
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
    final dayData = _weeklyData.firstWhere((day) => day['date'] == dateString);
    final selectedImages = _selectedImages[dateString];

    // Add to confirming set to show loading
    setState(() {
      _confirmingDays.add(dateString);
    });

    try {
      await ImageService.confirmDay(dateString, dayData, selectedImages);

      // Update local data immediately
      setState(() {
        // Update the day data in weekly data
        final dayIndex = _weeklyData.indexWhere(
          (day) => day['date'] == dateString,
        );
        if (dayIndex != -1) {
          _weeklyData[dayIndex]['confirmed'] = true;
          // Move selected images to attachment images
          if ((selectedImages ?? []).isNotEmpty) {
            List<String> existingImages = List<String>.from(
              _weeklyData[dayIndex]['attachmentImages'] ?? [],
            );
            existingImages.addAll(selectedImages!);
            _weeklyData[dayIndex]['attachmentImages'] = existingImages;
          }
        }

        // Update monthly data
        final monthlyDays = _monthlyData['days'] as List<Map<String, dynamic>>?;
        if (monthlyDays != null) {
          for (var day in monthlyDays) {
            if (day['date'] == dateString) {
              day['confirmed'] = true;
              if ((selectedImages ?? []).isNotEmpty) {
                List<String> existingImages = List<String>.from(
                  day['attachmentImages'] ?? [],
                );
                existingImages.addAll(selectedImages!);
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
          final chartData = ChartCalculator.calculateChartData(
            monthlyDays,
            _selectedWeekNumber,
          );
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
        drawer: CustomDrawer(
          currentScreen: DrawerScreenType.timeReport,
          onNavigateToTab: widget.onNavigateToTab,
        ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(color: Colors.blueAccent),
                ),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
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
                              _selectedWeekNumber = null;
                              _expandedDays.clear();
                              _selectedImages.clear();
                              _selectedDayData = null;
                            });
                            _loadMonthlyData();
                          },
                          onYearChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                              _selectedDay = null;
                              _selectedWeekNumber = null;
                              _expandedDays.clear();
                              _selectedImages.clear();
                              _selectedDayData = null;
                            });
                            _loadMonthlyData();
                          },
                        ),

                        const SizedBox(height: 20),

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
                                      ? List<Map<String, dynamic>>.from(
                                          _monthlyData['days'] ?? [],
                                        )
                                      : List<Map<String, dynamic>>.from(
                                              _monthlyData['days'] ?? [],
                                            )
                                            .where(
                                              (day) =>
                                                  day['weekNumber'] == weekNum,
                                            )
                                            .toList();

                                  final chartData =
                                      ChartCalculator.calculateChartData(
                                        _monthlyData['days'] ?? [],
                                        _selectedWeekNumber,
                                      );
                                  _monthlyChartData =
                                      chartData.monthlyChartData;
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

                          if (_selectedWeekNumber != null)
                            const SizedBox(height: 20),

                          // Days List
                          DaysListCard(
                            weeklyData: _weeklyData,
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
