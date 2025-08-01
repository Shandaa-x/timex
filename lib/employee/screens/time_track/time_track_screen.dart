import 'package:flutter/material.dart';
import 'package:timex/index.dart';

class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({Key? key}) : super(key: key);

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  String selectedTab = 'Week';

  final List<String> tabs = ['Day', 'Week', 'Month'];
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final List<double> hoursPerDay = [5, 2, 6, 5, 4]; // weekends removed

  double get totalHours => hoursPerDay.reduce((a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final maxHours = hoursPerDay.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Цагийн тайлан'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToggleTabs(),
            const SizedBox(height: 24),
            const Text('Total worked time this week', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('${totalHours.toInt()}h', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildBarChart(maxHours),
          ],
        ),
      ),
      floatingActionButton: ElevatedButton(
        child: txt('Цалин харах', style: TxtStl.bodyText1()),
        onPressed: () {},
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEAEFF5), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = tab == selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTab = tab;
                });
              },
              child: Container(
                decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? Colors.black : Colors.grey[700]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(double maxHours) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(days.length, (index) {
        final heightRatio = hoursPerDay[index] / maxHours;
        final barHeight = 120 * heightRatio;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Time label above the bar
              Text('${hoursPerDay[index]}h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),

              // Bar
              Container(
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: const Color(0xFFDAE0E6), borderRadius: BorderRadius.circular(6)),
              ),

              const SizedBox(height: 8),

              // Day label below the bar
              Text(days[index], style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        );
      }),
    );
  }
}
