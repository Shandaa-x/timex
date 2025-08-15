import 'package:flutter/material.dart';
import '../widgets/paginated_payment_history_widget.dart';
import '../../../widgets/individual_food_payment_history.dart';
import '../../../widgets/food_payment_integration_widget.dart';

class HistoryTabScreen extends StatefulWidget {
  const HistoryTabScreen({super.key});

  @override
  State<HistoryTabScreen> createState() => _HistoryTabScreenState();
}

class _HistoryTabScreenState extends State<HistoryTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab bar for history types
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(2),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(text: 'Food History'),
              Tab(text: 'Pay Foods'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Individual food payment history
              const IndividualFoodPaymentHistory(),
              // Food payment integration (select and pay)
              FoodPaymentIntegrationWidget(
                selectedMonth: DateTime.now(),
              ),
              // Traditional payment history
              const PaginatedPaymentHistoryWidget(),
            ],
          ),
        ),
      ],
    );
  }
}
